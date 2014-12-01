#!/usr/bin/env python2
import crc32c
import struct

STAGE1_SECTORS = 28

with open("build/stage1/stage1.bin", "r") as f:
    data = f.read()
padded_size = STAGE1_SECTORS * 512 - 4
assert len(data) <= padded_size
data += chr(0) * (padded_size - len(data))
data += struct.pack("<I", crc32c.crc32c(data))
with open("build/stage1.bin", "w") as f:
    f.write(data)
