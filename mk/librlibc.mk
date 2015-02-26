# Turn off stack checking for these simple byte-string functions.  It is
# unnecessary, because they use much less stack then the amount reserved for
# non-Rust code, and it is conceivable that the stack overflow code could call
# into here.
build/librlibc.rlib : src/librlibc/lib.rs $(RUST_LIBCORE_DEP)
	mkdir -p $(dir $@)
	$(RUSTC) $(RUSTC_TARGET_FLAGS) $(RUST_LIBCORE_EXTERN) $< --out-dir $(dir $@) --emit link,dep-info --crate-type rlib --crate-name rlibc -C no-stack-check

-include build/rlibc.d
