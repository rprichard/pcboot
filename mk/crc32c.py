#!/usr/bin/env python2
import argparse
import struct
import sys


def _crc32c_table():
    # We need to use the bit-by-bit reversed polynomial.
    #  - CRC-32 (PKZIP) uses 0x04C11DB7, reversed to 0xEDB88320.
    #  - CRC-32C (Castagnoli) uses 0x1EDC6F41, reversed to 0x82F63B78.
    polynomial = 0x82F63B78
    table = [0] * 256
    for i in xrange(256):
        table[i] = i
        for j in xrange(8):
            lsb = table[i] & 1
            table[i] >>= 1
            if lsb:
                table[i] ^= polynomial
    return table


def crc32c(buffer):
    table = _crc32c_table()
    acc = 0xffffffff
    for b in buffer:
        acc = table[(acc & 0xff) ^ ord(b)] ^ (acc >> 8)
    acc ^= 0xffffffff
    return acc


def _main():
    parser = argparse.ArgumentParser(
        description="Compute a CRC-32C checksum of a file")
    parser.add_argument("filename")
    parser.add_argument("--raw-output", default=False, action="store_true",
        help="Print 4 bytes of output to stdout")
    args = parser.parse_args()
    with open(args.filename, "r") as f:
        data = f.read()
    result = crc32c(data)
    if args.raw_output:
        sys.stdout.write(struct.pack("<I", result))
    else:
        print "%x" % result


if __name__ == "__main__":
    _main()
