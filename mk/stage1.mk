###############################################################################
# Configurable Rust paths
###############################################################################

#RUST_PROG_DIR := /home/rprichard/work/rust/x86_64-unknown-linux-gnu/stage1
RUST_PROG_DIR := /home/rprichard/work/rust/out/rust-i686-unknown-linux-gnu
RUSTC := LD_LIBRARY_PATH=$(RUST_PROG_DIR)/lib $(RUST_PROG_DIR)/bin/rustc

###############################################################################

RUST_FLAGS := \
	--target i686-unknown-linux-gnu \
	-C opt-level=s \
	-C relocation-model=static \
	-C target-cpu=i386 \
	-C llvm-args=-rotation-max-header-size=0

build/stage1/%.o : src/stage1/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

# Turn off stack checking for these simple byte-string functions.  It is
# unnecessary, because they use much less stack then the amount reserved for
# non-Rust code, and it is conceivable that the stack overflow code could call
# into here.
build/stage1/librlibc.rlib : src/shared/librlibc/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUST_FLAGS) $< \
		--out-dir build/stage1 \
		--emit link,dep-info \
		--crate-type rlib \
		--crate-name rlibc \
		-C no-stack-check

build/stage1/libstage1.a : src/stage1/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUST_FLAGS) --crate-type staticlib -C lto $< --out-dir build/stage1 --emit link,dep-info

STAGE1_OBJECTS := \
	build/shared/entry.o \
	build/shared/mode_switch.o \
	build/shared/lowlevel.o \
	build/shared/io.o \
	build/stage1/transfer.o \
	build/stage1/libstage1.a \
	build/stage1/librlibc.rlib

build/stage1.bin : $(STAGE1_OBJECTS) src/stage1/stage1.ld
	gold -static -nostdlib --nmagic --gc-sections \
		-T src/stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		$(STAGE1_OBJECTS)
	objcopy -j.image16 -j.image -Obinary build/stage1/stage1.elf build/stage1/stage1.bin
	python2 -B mk/finalize_stage1.py

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include $(STAGE1_OBJECTS:=.d)
-include build/stage1/rlibc.d
-include build/stage1/stage1.d
