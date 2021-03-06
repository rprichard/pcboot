#!/bin/sh
#
# Dependencies:
#  - The mtools package (/usr/bin/mcopy)
#  - The dosfstools package (mkfs.msdos)
#  - sfdisk
#  - qemu-system-x86_64

set -e -x

mkdir -p test

# Create the pcboot volume.
dd if=/dev/zero of=test/bootvol bs=1MiB count=63
mkfs.msdos -F32 -h2048 test/bootvol
mcopy -itest/bootvol build/stage2.bin ::/STAGE2.BIN

# Create the disk image.
dd if=/dev/zero of=test/disk bs=1MiB count=64
cat > test/disk.setup.1 <<EOF
# partition table of disk
unit: sectors

    disk1 : start=     2048, size=   129024, Id=1c, bootable
    disk2 : start=        0, size=        0, Id= 0
    disk3 : start=        0, size=        0, Id= 0
    disk4 : start=        0, size=        0, Id= 0
EOF
cat > test/disk.setup.2 <<EOF
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
sfdisk -q --no-reread --force test/disk < test/disk.setup.1
echo SUCCESS

# Install the MBR and volume.
build/install-pcboot.py --mbr test/disk --volume test/bootvol

# Copy the boot volume into the disk partition.
dd if=test/bootvol of=test/disk bs=1MiB seek=1 conv=notrunc

# Prepare a VMDK file for VirtualBox.
do_virtualbox_disk() {
    qemu-img convert -O vmdk test/disk test/disk.vmdk
    VBoxManage internalcommands sethduuid test/disk.vmdk 885d9adc-5f17-4bef-a28e-76d4ebefcc88
}

# Launch qemu.
do_qemu() {
    qemu-system-x86_64 -hda test/disk
}

# Launch bochs.  (Install bochs and bochs-sdl Ubuntu packages.)
do_bochs() {
cat > test/bochsrc.txt << EOF
boot:disk
ata0-master: type=disk, path=disk, cylinders=64, heads=64, spt=32
display_library: sdl
EOF
    cd test && bochs
}

do_qemu
