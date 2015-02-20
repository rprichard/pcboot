build/stage1/%.o : src/stage1/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

build/stage1/libstage1.a : src/stage1/lib.rs build/libsys.rlib
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) -C lto $< \
		--out-dir build/stage1 \
		--emit link,dep-info \
		--extern sys=build/libsys.rlib

STAGE1_OBJECTS := \
	build/stage1/transfer.o

STAGE1_INPUTS := \
	build/entry/entry.o \
	$(STAGE1_OBJECTS) \
	build/stage1/libstage1.a \
	build/libsys_native.a \
	build/librlibc.rlib

build/stage1.bin : $(STAGE1_INPUTS) src/stage1/stage1.ld
	gold -static -nostdlib --nmagic --gc-sections \
		-T src/stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		$(STAGE1_INPUTS)
	objcopy -j.image16 -j.image -Obinary build/stage1/stage1.elf build/stage1/stage1.bin
	python2 -B mk/finalize_stage1.py

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include $(STAGE1_OBJECTS:=.d)
-include build/stage1/stage1.d
