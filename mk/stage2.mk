build/stage2/%.o : src/stage2/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

build/stage2/libstage2.a : src/stage2/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) -C lto $< \
		--out-dir build/stage2 \
		--emit link,dep-info \
		--extern sys=build/libsys.rlib

STAGE2_OBJECTS :=

STAGE2_INPUTS := \
	build/entry/entry.o \
	$(STAGE2_OBJECTS) \
	build/stage2/libstage2.a \
	build/libsys_native.a \
	build/librlibc.rlib

build/stage2.bin : $(STAGE2_INPUTS) src/stage2/stage2.ld
	gold -static -nostdlib --nmagic --gc-sections \
		-T src/stage2/stage2.ld \
		-o build/stage2/stage2.elf \
		-Map build/stage2/stage2.map \
		$(STAGE2_INPUTS)
	objcopy -j.image16 -j.image -Obinary build/stage2/stage2.elf build/stage2/stage2.bin
	mk/crc32c.py --raw-output build/stage2/stage2.bin > build/stage2/stage2.bin.crc32c
	cat build/stage2/stage2.bin build/stage2/stage2.bin.crc32c > build/stage2.bin

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage2.bin

-include $(STAGE2_OBJECTS:=.d)
-include build/stage2/stage2.d
