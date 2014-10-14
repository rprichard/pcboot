build/stage1.bin : stage1/stage1.ld stage1/entry.asm

	mkdir -p build/stage1

	nasm -felf32 stage1/entry.asm \
		-o build/stage1/entry.elf \
		-MD build/stage1/entry.d \
		-MT build/stage1.bin

	gold -static -nostdlib --nmagic \
		-T stage1/stage1.ld \
		-o build/stage1/stage1.elf \
		-Map build/stage1/stage1.map \
		build/stage1/entry.elf

	objcopy -j.image -Obinary build/stage1/stage1.elf build/stage1.bin

FINAL_OUTPUTS := $(FINAL_OUTPUTS) build/stage1.bin

-include build/stage1/entry.d
