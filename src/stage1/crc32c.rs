use core::prelude::*;

// A 1KiB-sized table used to compute the checksum.
struct Table {
    data: [u32; 256]
}

pub fn table() -> Table {
    // We need to use the bit-by-bit reversed polynomial.
    //  - CRC-32 (PKZIP) uses 0x04C11DB7, reversed to 0xEDB88320.
    //  - CRC-32C (Castagnoli) uses 0x1EDC6F41, reversed to 0x82F63B78.
    let polynomial = 0x82F63B78_u32;
    let mut table = Table { data: [0u32; 256] };
    for (i, cell) in table.data.iter_mut().enumerate() {
        let mut result = i as u32;
        for _ in range(0, 8) {
            let lsb = result & 1;
            result >>= 1;
            if lsb == 1 {
                result ^= polynomial;
            }
        }
        *cell = result;
    }
    table
}

pub fn compute(table: &Table, buffer: &[u8]) -> u32 {
    let mut acc = 0xffffffff_u32;
    for b in buffer.iter() {
        let lookup_value = unsafe {
            let index: u8 = *b ^ (acc as u8);
            *table.data.get_unchecked(index as usize)
        };
        acc = lookup_value ^ (acc >> 8);
    }
    acc ^ 0xffffffff
}
