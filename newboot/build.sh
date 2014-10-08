#!/bin/sh
#
# Dependencies:
#  - nasm
#  - binutils (gold-ld, objcopy)

set -e -x

nasm -felf32 mbr.s -o mbr.o
gold -static -Tmbr.ld -nostdlib --nmagic -o mbr.elf -Map mbr.map mbr.o
objcopy -j.boot_record -Obinary mbr.elf mbr.bin

nasm -felf32 vbr.s -o vbr.o
gold -static -Tvbr.ld -nostdlib --nmagic -o vbr.elf -Map vbr.map vbr.o
objcopy -j.boot_record -Obinary vbr.elf vbr.bin

nasm -felf32 dummy_fat_vbr.s -o dummy_fat_vbr.o
gold -static -Tdummy_fat_vbr.ld -nostdlib --nmagic -o dummy_fat_vbr.elf -Map dummy_fat_vbr.map dummy_fat_vbr.o
objcopy -j.vbr -Obinary dummy_fat_vbr.elf dummy_fat_vbr.bin

nasm -felf32 stage1_entry.s -o stage1_entry.o
gold -static -Tstage1.ld -nostdlib --nmagic -o stage1.elf -Map stage1.map stage1_entry.o
objcopy -j.image -Obinary stage1.elf stage1.bin

echo SUCCESS
