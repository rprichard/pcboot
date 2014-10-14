default : all

include mk/boot_records.mk
include mk/shared.mk
include mk/stage1.mk

all : $(FINAL_OUTPUTS)

clean :
	rm -fr build test

test : all
	mk/test.sh
