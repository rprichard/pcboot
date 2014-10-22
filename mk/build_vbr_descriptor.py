#!/usr/bin/env python2
# Invoked from boot_records.mk.
import subprocess
import sys

POST_VBR_SECTOR_SYMBOL = "main.post_VBR_sector"
BASE_ADDRESS = 0x7c00

match = None
vbr_symbol_lines = subprocess.check_output("nm build/boot_records/vbr.elf", shell=True).splitlines()
for symbol_line in vbr_symbol_lines:
    if POST_VBR_SECTOR_SYMBOL not in symbol_line:
        continue
    assert match is None
    match = symbol_line
if match is None:
    sys.exit("Missing %s symbol in VBR" % POST_VBR_SECTOR_SYMBOL)

address = int(match.split()[0], 16)
assert address >= BASE_ADDRESS and address <= BASE_ADDRESS + 512
address -= BASE_ADDRESS

with open("build/vbr.cfg", "w") as f:
    f.write("post_VBR_sector=%d\n" % address)
