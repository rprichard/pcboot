extern crate core;
use core::prelude::*;

// Disable stack checking, because this function might be used during stack
// overflow handling.
#[no_stack_check] #[inline(never)]
pub fn print_char(ch: u8) {
    extern "C" {
        fn print_char_16bit();
        fn call_real_mode(callee: *mut (), ch: u32);
    }
    unsafe {
        call_real_mode(print_char_16bit as *mut (), ch as u32);
    }
}

// Disable stack checking, because this function might be used during stack
// overflow handling.
#[no_stack_check] #[inline(never)]
pub fn print_byte_str(text: &[u8]) {
    for ch in text.iter() {
        print_char(*ch);
    }
}

// Disable stack checking, because this function might be used during stack
// overflow handling.
#[no_stack_check] #[inline(never)]
pub fn print_str(text: &str) {
    for ch in text.as_bytes().iter() {
        print_char(*ch);
    }
}

struct PrintWriter;

impl core::fmt::FormatWriter for PrintWriter {
    fn write(&mut self, buf: &[u8]) -> core::fmt::Result {
        ::io::print_byte_str(buf);
        Ok(())
    }
}

pub fn print_args(args: &::std::fmt::Arguments) {
    let _ = core::fmt::write(&mut PrintWriter, args);
}
