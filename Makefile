###############################################################################
# Configurable Rust path
###############################################################################

RUSTC := fixld /home/rprichard/work/rust/build/install/bin/rustc
RUST_LIBCORE_SRC := /home/rprichard/work/rust/src/libcore

###############################################################################

RUST_LIBCORE_DEP := build/libcore.rlib
RUST_LIBCORE_EXTERN := --extern core=$(RUST_LIBCORE_DEP)

RUSTC_TARGET_FLAGS := \
    -L build \
    --cfg strref \
    --target i686-unknown-linux-gnu \
    -C opt-level=1 \
    -C relocation-model=static \
    -C target-cpu=i386 \
    -C llvm-args=-rotation-max-header-size=0 \
    -Z no-landing-pads

default : all

include mk/boot_records.mk
include mk/entry.mk
include mk/installer.mk
include mk/libcore.mk
include mk/librlibc.mk
include mk/libsys.mk
include mk/stage1.mk
include mk/stage2.mk

all : $(FINAL_OUTPUTS)

clean :
	rm -fr build test

test : all
	mk/test.sh
