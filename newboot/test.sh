#!/bin/sh
#
# Dependencies:
#  - The mtools package (/usr/bin/mcopy)
#  - The dosfstools package (mkfs.msdos)
#  - /boot/memtest86+.bin
#  - sfdisk
#  - Python 3
#  - qemu-system-x86_64

set -e -x

# Create the pcboot volume.
dd if=/dev/zero of=bootvol bs=1MiB count=63
mkfs.msdos -F32 -h2048 bootvol
mcopy -ibootvol /boot/memtest86+.bin ::/MEMTEST.BIN
dd if=vbr.bin of=bootvol bs=1 conv=notrunc count=3
dd if=vbr.bin of=bootvol bs=1 conv=notrunc count=422 seek=90 skip=90
dd if=stage1.bin of=bootvol bs=1 conv=notrunc seek=512

# Create the disk image.
dd if=/dev/zero of=disk bs=1MiB count=64
cat > disk.setup.1 <<EOF
# partition table of disk
unit: sectors

    disk1 : start=     2048, size=   129024, Id=1c, bootable
    disk2 : start=        0, size=        0, Id= 0
    disk3 : start=        0, size=        0, Id= 0
    disk4 : start=        0, size=        0, Id= 0
EOF
cat > disk.setup.2 <<EOF
# partition table of disk
unit: sectors

    disk1 : start=     1024, size=   130048, Id= 5
    disk2 : start=        0, size=        0, Id= 0
    disk3 : start=        0, size=        0, Id= 0
    disk4 : start=        0, size=        0, Id= 0
    disk5 : start=     1100, size=       90, Id=83
    disk6 : start=     1200, size=       90, Id=83
    disk7 : start=     2048, size=   129024, Id=1c
EOF
sfdisk -q --no-reread --force -C64 -H64 -S32 disk < disk.setup.1
echo SUCCESS

# Install the MBR and volume into the disk.
dd if=mbr.bin of=disk bs=1 count=440 conv=notrunc
dd if=mbr.bin of=disk bs=1 count=2 conv=notrunc seek=510 skip=510
dd if=bootvol of=disk bs=1MiB seek=1 conv=notrunc

# Launch qemu.
qemu-system-x86_64 -hda disk
