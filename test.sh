#!/bin/sh
#
# Dependencies:
#  - The fuseext2 package (/usr/bin/fuseext2)
#  - /boot/memtest86+.bin
#  - sfdisk
#  - Python 3 (for install-boot)
#  - qemu-system-x86_64

set -e -x

# Create the pcboot volume.
fusermount -u bootvol-mnt 2>/dev/null || true
rm -fr bootvol-mnt
dd if=/dev/zero of=bootvol bs=1MiB count=63
mkfs.ext3 -Fq bootvol
mkdir bootvol-mnt
mount.fuse fuseext2#bootvol bootvol-mnt -o rw+
cp /boot/memtest86+.bin bootvol-mnt
sync
fusermount -u bootvol-mnt

# Create the disk image.
dd if=/dev/zero of=disk bs=1MiB count=64
cat > disk.setup <<EOF
# partition table of disk
unit: sectors

    disk1 : start=     2048, size=   129024, Id=83, bootable
    disk2 : start=        0, size=        0, Id= 0
    disk3 : start=        0, size=        0, Id= 0
    disk4 : start=        0, size=        0, Id= 0
EOF
sfdisk -q --no-reread --force -C64 -H64 -S32 disk < disk.setup

# Copy the volume into the disk image.
dd if=bootvol of=disk bs=1MiB seek=1 conv=notrunc
./install-boot disk boot.bin

# Launch qemu.
qemu-system-x86_64 -hda disk -boot c
