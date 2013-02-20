#!/bin/sh
fusermount -u bootvol-mnt 2>/dev/null || true
rm -fr bootvol-mnt
rm -f boot.bin boot.elf boot bootvol disk.setup disk
rm -f *.o
