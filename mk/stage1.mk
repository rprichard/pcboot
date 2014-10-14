# TODO: Use i386 instead of i686?
RUST_PATH := /home/rprichard/work/rust-i686-unknown-linux-gnu
RUST_LIB_PATH := $(RUST_PATH)/lib/rustlib/i686-unknown-linux-gnu/lib
RUST_CMD := LD_LIBRARY_PATH=$(RUST_PATH)/lib $(RUST_PATH)/bin/rustc --target i686-unknown-linux-gnu
RUST_HASH := 4e7c5e5c

RUST_OPTIONS := \
	-O \
	-C save-temps \
	-C no-vectorize-loops \
	-C no-vectorize-slp \

build/stage1/%.o : src/stage1/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

build/stage1/main.o : src/stage1/main.rs
	mkdir -p $(dir $@)
	$(RUST_CMD) $(RUST_OPTIONS) --emit obj $< -o $@

STAGE1_OBJECTS := \
	build/shared/entry.o \
	build/shared/mode_switch.o \
	build/shared/printchar.o \
	build/stage1/main.o

build/stage1.bin : $(STAGE1_OBJECTS)
	gold -static -nostdlib --nmagic --gc-sections \
		-T src/stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		$(STAGE1_OBJECTS) \
		$(RUST_LIB_PATH)/libcore-$(RUST_HASH).rlib \
		$(RUST_LIB_PATH)/libmorestack.a \
		$(RUST_LIB_PATH)/libcompiler-rt.a
	objcopy -j.image -Obinary build/stage1/stage1.elf build/stage1.bin

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include $(STAGE1_OBJECTS:=.d)
