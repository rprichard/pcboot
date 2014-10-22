#!/bin/sh
# Invoked from boot_records.mk.
set -e

NAME=$1
SRC_SECTOR=$2
DEST_SECTOR=$3

ELF_BIN=build/boot_records/$NAME.elf
TMP_BIN=build/boot_records/$NAME-tmp.bin
FINAL_BIN=build/boot_records/$NAME.bin

objcopy -j.boot_record -Obinary $ELF_BIN $TMP_BIN

dd if=$TMP_BIN of=$FINAL_BIN bs=512 count=1 skip=$SRC_SECTOR seek=$DEST_SECTOR 2>/dev/null

rm $TMP_BIN
