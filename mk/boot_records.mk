# Dependencies:
#  - nasm
#  - binutils (gold-ld, objcopy)

build/mbr.bin : boot_records/mbr.ld
	mk/build_boot_record_elf.sh mbr
	mk/extract_boot_sector.sh mbr 0 0
	mv build/boot_records/mbr.bin build/mbr.bin

build/vbr.bin : boot_records/vbr.ld
	mk/build_boot_record_elf.sh vbr
	mk/extract_boot_sector.sh vbr 0 0
	mk/extract_boot_sector.sh vbr 3 1
	python2 -B mk/build_vbr_descriptor.py
	mv build/boot_records/vbr.bin build/vbr.bin

build/dummy_fat_vbr.bin : boot_records/dummy_fat_vbr.ld
	mk/build_boot_record_elf.sh dummy_fat_vbr
	mk/extract_boot_sector.sh dummy_fat_vbr 0 0
	mv build/boot_records/dummy_fat_vbr.bin build/dummy_fat_vbr.bin

FINAL_OUTPUTS := $(FINAL_OUTPUTS) \
	build/mbr.bin \
	build/vbr.bin \
	build/dummy_fat_vbr.bin

-include build/boot_records/mbr.d
-include build/boot_records/vbr.d
-include build/boot_records/dummy_fat_vbr.d
