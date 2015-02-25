###############################################################################
# Configurable Rust path
###############################################################################

RUSTC := \
    LD_LIBRARY_PATH=/home/rprichard/work/rust-nightly-i686-unknown-linux-gnu/rustc/lib \
                    /home/rprichard/work/rust-nightly-i686-unknown-linux-gnu/rustc/bin/rustc

###############################################################################

RUSTC_TARGET_FLAGS := \
    --cfg strref \
    --target i686-unknown-linux-gnu \
    -C opt-level=2 \
    -C relocation-model=static \
    -C target-cpu=i386 \
    -C llvm-args=-rotation-max-header-size=0

default : all

include mk/boot_records.mk
include mk/entry.mk
include mk/installer.mk
include mk/librlibc.mk
include mk/libsys.mk
include mk/stage1.mk
include mk/stage2.mk

all : $(FINAL_OUTPUTS)

clean :
	rm -fr build test

test : all
	mk/test.sh
