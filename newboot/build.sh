#!/bin/sh
#
# Dependencies:
#  - nasm
#  - binutils (gold-ld, objcopy)

set -e -x

nasm -felf32 mbr.s -o mbr.o
gold -static -Tmbr.ld -nostdlib --nmagic -o mbr.elf -Map mbr.map mbr.o
objcopy -j.mbr -Obinary mbr.elf mbr.bin

echo SUCCESS
