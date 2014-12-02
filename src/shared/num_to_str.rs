extern crate core;
use core::prelude::*;

type u32_storage = [u8, ..10];

pub const u32_zero: u32_storage = [0u8, ..10];

pub fn u32<'a>(mut val: u32, storage: &'a mut u32_storage) -> &'a str {
    let mut first = storage.len() - 1;
    for i in range(0, storage.len()).rev() {
        let digit = val % 10;
        val /= 10;
        unsafe {
            *storage.unsafe_mut(i) = b'0' + digit as u8;
        }
        if digit != 0 {
            first = i;
        }
    }
    unsafe {
        let buf_slice = core::mem::transmute(
            core::raw::Slice {
                data: storage.as_ptr().offset(first as int),
                len: storage.len() - first,
            }
        );
        core::str::from_utf8_unchecked(buf_slice)
    }
}
