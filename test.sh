#!/bin/sh
dd if=boot.bin of=disk conv=notrunc
qemu-system-x86_64 -hda boot.bin -boot c
