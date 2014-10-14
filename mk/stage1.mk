build/stage1/entry.o : stage1/entry.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD build/stage1/entry.d

build/stage1.bin : build/stage1/entry.o
	gold -static -nostdlib --nmagic \
		-T stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		build/stage1/entry.o
	objcopy -j.image -Obinary build/stage1/stage1.elf build/stage1.bin

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include build/stage1/entry.d
