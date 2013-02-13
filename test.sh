#!/bin/sh
./install-boot disk boot.bin
qemu-system-x86_64 -hda boot.bin -boot c
