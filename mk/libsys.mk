build/libsys/%.o : src/libsys/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

build/libsys.rlib : src/libsys/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) $< --out-dir $(dir $@) --emit link,dep-info

OBJECT_FILES := \
	build/libsys/mode_switch.o \
	build/libsys/sys.o

build/libsys_native.a : $(OBJECT_FILES)
	mkdir -p $(dir $@)
	rm -f $@
	ar rcs $@ $^

-include $(OBJECT_FILES:=.d)
-include build/sys.d
