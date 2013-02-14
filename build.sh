#!/bin/sh

set -e -x

asm_files="mbr_boot mode_switch io16"
c_files="_main main io ext2 mem debug"
objects=

for file in $asm_files; do
    nasm -felf32 $file.s -o $file.o
    objects="$objects $file.o"
done

for file in $c_files; do
    gcc -std=c99 -Os -m32 -fomit-frame-pointer -ffreestanding -c $file.c -o $file.o -DBOOT_DEBUG
    objects="$objects $file.o"
done

gold -static -Tboot.ld -nostdlib --nmagic -o boot.elf -Map boot.map \
    $objects

objcopy -R.bss -R.stack -Obinary boot.elf boot.bin

echo SUCCESS
