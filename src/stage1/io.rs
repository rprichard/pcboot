extern crate core;
use core::prelude::*;

extern "C" {
    pub fn printchar_32bit(x: u8);
}

// Disable stack checking, because this function is used during stack overflow
// handling.
#[no_stack_check] #[inline]
pub fn printchar(ch: u8) {
    unsafe { printchar_32bit(ch); }
}

// Disable stack checking, because this function is used during stack overflow
// handling.  Disable inlining to discourage loop unrolling.
#[no_stack_check] #[inline(never)]
pub fn printstr(text: &str) {
    for ch in text.as_bytes().iter() {
        printchar(*ch);
    }
}
