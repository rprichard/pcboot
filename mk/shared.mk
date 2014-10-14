build/shared/%.o : src/shared/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d
