# TODO: Use i386 instead of i686?

###############################################################################
# Configurable Rust paths
###############################################################################

# Path to Rust distribution (for the Rust compiler).
#RUST_PROG_PATH := /home/rprichard/work/rust/x86_64-unknown-linux-gnu/stage1
RUST_PROG_PATH := /home/rprichard/work/rust-i686-unknown-linux-gnu

# Path to Rust distribution (for Rust libraries).
RUST_LIB_PATH := /home/rprichard/work/rust-i686-unknown-linux-gnu

# Path to Rust src directory (for compiling libcore and librlibc libraries).
RUST_SRC_PATH := /home/rprichard/work/rust/src

###############################################################################

RUST_PROG := LD_LIBRARY_PATH=$(RUST_PROG_PATH)/lib $(RUST_PROG_PATH)/bin/rustc
RUST_TARGET_LIB_PATH := $(RUST_LIB_PATH)/lib/rustlib/i686-unknown-linux-gnu/lib

RUST_FLAGS := \
	--target i686-unknown-linux-gnu \
	-O --opt-size \
	-C no-vectorize-loops \
	-C no-vectorize-slp \
	-C relocation-model=static \
	-C llvm-args=-rotation-max-header-size=0

build/stage1/%.o : src/stage1/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

build/stage1/libcore.rlib : $(RUST_SRC_PATH)/libcore/lib.rs
	mkdir -p $(dir $@)
	$(RUST_PROG) $(RUST_FLAGS) $< -o $@ --dep-info $@.d

# Turn off stack checking for these simple byte-string functions.  It is
# unnecessary, because they use much less stack then the amount reserved for
# non-Rust code, and it is conceivable that the stack overflow code could call
# into here.
build/stage1/librlibc.rlib : $(RUST_SRC_PATH)/librlibc/lib.rs build/stage1/libcore.rlib
	mkdir -p $(dir $@)
	$(RUST_PROG) $(RUST_FLAGS) $< -o $@ --dep-info $@.d \
		-C no-stack-check \
		--extern core=build/stage1/libcore.rlib

build/stage1/libstage1.rlib : src/stage1/lib.rs build/stage1/libcore.rlib build/stage1/librlibc.rlib
	mkdir -p $(dir $@)
	$(RUST_PROG) $(RUST_FLAGS) $< -o $@ --dep-info $@.d \
		--extern core=build/stage1/libcore.rlib \
		--extern rlibc=build/stage1/librlibc.rlib

STAGE1_OBJECTS := \
	build/shared/entry.o \
	build/shared/mode_switch.o \
	build/shared/lowlevel.o \
	build/shared/io.o \
	build/stage1/libstage1.rlib \
	build/stage1/libcore.rlib \
	build/stage1/librlibc.rlib

build/stage1.bin : $(STAGE1_OBJECTS) src/stage1/stage1.ld
	gold -static -nostdlib --nmagic --gc-sections \
		-T src/stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		$(STAGE1_OBJECTS) \
		$(RUST_TARGET_LIB_PATH)/libmorestack.a \
		$(RUST_TARGET_LIB_PATH)/libcompiler-rt.a
	objcopy -j.image16 -j.image -Obinary build/stage1/stage1.elf build/stage1/stage1.bin
	mk/finalize_stage1.py

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include $(STAGE1_OBJECTS:=.d)
