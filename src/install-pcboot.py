#!/usr/bin/env python2
import argparse
import os
import re
import struct
import sys


RESERVED_AREA_SECTORS = 32
STAGE1_SECTORS = 28


def _file_content(path):
    with open(path) as f:
        return f.read()


root_path = os.path.dirname(__file__)
mbr_bin = _file_content(os.path.join(root_path, "mbr.bin"))
vbr_bin = _file_content(os.path.join(root_path, "vbr.bin"))
mbr_cfg = _file_content(os.path.join(root_path, "vbr.cfg"))
stage1_bin = _file_content(os.path.join(root_path, "stage1.bin"))


def _read_args():
    parser = argparse.ArgumentParser(
        description="Install pcboot to an MBR and/or FAT32 volume.")
    parser.add_argument("--mbr", metavar="FILE", help="e.g. /dev/sda")
    parser.add_argument("--volume", metavar="FILE", help="e.g. /dev/sda5")
    args = parser.parse_args()
    if args.mbr is None and args.volume is None:
        print "Error: You must pass at least one of --mbr or --volume."
        print ""
        parser.print_help()
        sys.exit(1)
    return args


def _install_mbr(target):
    # Do not truncate.  The file must already exist.
    with open(target, "r+") as f:
        mbr = bytearray(f.read(512))
        mbr[0:440] = mbr_bin[0:440]
        f.seek(0)
        f.write(mbr)


def _free_sectors(*reserved):
    for sector in reserved:
        assert sector >= 0 and sector <= RESERVED_AREA_SECTORS - 1
    sector = 0
    while True:
        assert sector <= RESERVED_AREA_SECTORS - 1
        if sector not in reserved:
            yield sector
        sector += 1


def _post_VBR_sector_offset():
    m = re.search(r"^post_VBR_sector=(\d+)$", mbr_cfg)
    assert m is not None
    return int(m.group(1))


def _initialize_volume_reserved_area(target):
    with open(target, "r+") as f:
        # Read the FAT32 parameters.
        # TODO: check whether this is a FAT32 volume
        vbr = bytearray(f.read(512))
        (fsinfo_sector,) = struct.unpack("<H", vbr[48:50])
        (backup_vbr_sector,) = struct.unpack("<H", vbr[50:52])
        assert (backup_vbr_sector >= 1 and
                backup_vbr_sector <= RESERVED_AREA_SECTORS - 1)
        free_sectors = _free_sectors(0, fsinfo_sector, backup_vbr_sector)

        # Install the VBR.
        post_VBR_sector = free_sectors.next()
        vbr[0:3] = vbr_bin[0:3]
        vbr[90:512] = vbr_bin[90:512]
        vbr[_post_VBR_sector_offset()] = post_VBR_sector
        f.seek(0)
        f.write(vbr)

        # Install the backup VBR.
        f.seek(backup_vbr_sector * 512)
        f.write(vbr)

        # Install the post-VBR sector.
        f.seek(post_VBR_sector * 512)
        f.write(vbr_bin[512:1024])

        # Install the stage1 binary.
        assert len(stage1_bin) == STAGE1_SECTORS * 512
        remaining = stage1_bin
        while len(remaining) > 0:
            sector = free_sectors.next()
            f.seek(sector * 512)
            f.write(remaining[:512])
            remaining = remaining[512:]


def _initialize_boot_volume(target):
    _initialize_volume_reserved_area(target)
    # TODO: install stage2 and assorted files into the volume itself.
    # This step will probably require the mtools utility.


def _main():
    args = _read_args()
    if args.mbr is not None:
        _install_mbr(args.mbr)
    if args.volume is not None:
        _initialize_boot_volume(args.volume)


if __name__ == "__main__":
    _main()
