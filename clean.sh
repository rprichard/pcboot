#!/bin/sh
fusermount -u bootvol-mnt 2>/dev/null || true
rm -fr bootvol-mnt
rm -f boot.bin boot.elf boot.map
rm -f bootvol
rm -f disk disk.setup
rm -f *.o
