#!/bin/sh
#
# Dependencies:
#  - nasm
#  - binutils (gold-ld, objcopy)

set -e -x

boot_record() {
    nasm -felf32 $1.s -o $1.o
    gold -static -T$1.ld -nostdlib --nmagic -o $1.elf -Map $1.map $1.o
    objcopy -j.boot_record -Obinary $1.elf $1-tmp.bin
    dd if=$1-tmp.bin of=$1.bin bs=1 count=512
    rm $1-tmp.bin
}

boot_record mbr
boot_record vbr
boot_record dummy_fat_vbr

nasm -felf32 stage1_entry.s -o stage1_entry.o
gold -static -Tstage1.ld -nostdlib --nmagic -o stage1.elf -Map stage1.map stage1_entry.o
objcopy -j.image -Obinary stage1.elf stage1.bin

echo SUCCESS
