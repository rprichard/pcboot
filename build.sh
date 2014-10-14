#!/bin/sh
#
# Dependencies:
#  - nasm
#  - binutils (gold-ld, objcopy)

set -e -x

boot_record() {
    nasm -felf32 $1.asm -o $1.o
    gold -static -T$1.ld -nostdlib --nmagic -o $1.elf -Map $1.map $1.o
}

extract_sector() {
    objcopy -j.boot_record -Obinary $1.elf $1-tmp.bin
    dd if=$1-tmp.bin of=$1.bin bs=512 count=1 skip=$2 seek=$3
    rm $1-tmp.bin
}

boot_record mbr
extract_sector mbr 0 0

boot_record vbr
extract_sector vbr 0 0
extract_sector vbr 3 1

boot_record dummy_fat_vbr
extract_sector dummy_fat_vbr 0 0

nasm -felf32 stage1_entry.asm -o stage1_entry.o
gold -static -Tstage1.ld -nostdlib --nmagic -o stage1.elf -Map stage1.map stage1_entry.o
objcopy -j.image -Obinary stage1.elf stage1.bin

echo SUCCESS
