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
// handling.
#[no_stack_check] #[inline(never)]
pub fn printstr(text: &str) {
    for ch in text.as_bytes().iter() {
        printchar(*ch);
    }
}

struct PrintWriter;

impl core::fmt::FormatWriter for PrintWriter {
    fn write(&mut self, buf: &[u8]) -> core::fmt::Result {
        for ch in buf.iter() {
            ::io::printchar(*ch);
        }
        Ok(())
    }
}

pub fn print_args(args: &::std::fmt::Arguments) {
    let _ = core::fmt::write(&mut PrintWriter, args);
}
