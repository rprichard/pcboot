#!/bin/sh
# Invoked from boot_records.mk.
set -e

NAME=$1

mkdir -p build/boot_records

SRC_BASE=boot_records/$NAME
DEST_BASE=build/boot_records/$NAME

nasm -felf32 \
    -I boot_records/ \
    $SRC_BASE.asm \
    -o $DEST_BASE.o \
    -MD $DEST_BASE.d \
    -MT build/$NAME.bin

gold -static -nostdlib --nmagic \
    -T $SRC_BASE.ld \
    -o $DEST_BASE.elf \
    -Map $DEST_BASE.map \
    $DEST_BASE.o

objdump -Maddr16,data16 -D $DEST_BASE.elf >$DEST_BASE.dis
