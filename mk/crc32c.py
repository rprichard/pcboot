#!/usr/bin/env python2
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
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "-help", "--help"):
        print("Usage: %s filename" % sys.argv[0])
        sys.exit(1)
    with open(sys.argv[1], "r") as f:
        data = f.read()
    print "%x" % crc32c(data)


if __name__ == "__main__":
    _main()
