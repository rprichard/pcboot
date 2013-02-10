#!/bin/sh

set -e -x

nasm -felf32 mbr.s -o mbr.o
nasm -felf32 lowlevel.s -o lowlevel.o

#clang -m32 -c globals.c

ld -static -Tboot.ld -nostdlib --nmagic -o boot.elf -Map boot.map \
    mbr.o lowlevel.o

objcopy -R.boot_disknum -R.stack -Obinary boot.elf boot.bin

echo SUCCESS
