build/shared/%.o : src/shared/%.asm
	mkdir -p $(dir $@)
	nasm -felf32 $< -o $@ -MD $@.d

# Turn off stack checking for these simple byte-string functions.  It is
# unnecessary, because they use much less stack then the amount reserved for
# non-Rust code, and it is conceivable that the stack overflow code could call
# into here.
build/shared/librlibc.rlib : src/shared/librlibc/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) $< \
		--out-dir build/shared \
		--emit link,dep-info \
		--crate-type rlib \
		--crate-name rlibc \
		-C no-stack-check

-include build/shared/rlibc.d

SHARED_OBJECTS := \
	build/shared/entry.o \
	build/shared/mode_switch.o \
	build/shared/lowlevel.o \
	build/shared/io.o

-include $(SHARED_OBJECTS:=.d)
