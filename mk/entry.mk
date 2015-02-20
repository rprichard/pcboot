build/entry/entry.o : src/entry/entry.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

-include build/entry/entry.d
