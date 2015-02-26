# Pass -C metadata=custom so that our libcore binary has a different
# Strict Version Hash than the built-in libcore.

build/libcore.rlib : $(RUST_LIBCORE_SRC)/lib.rs
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) $< --out-dir $(dir $@) --emit link,dep-info -C metadata=custom

-include build/core.d
