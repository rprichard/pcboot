#![crate_type = "lib"]
#![no_std]
#![feature(globs)]
#![feature(lang_items)]

extern crate core;
use core::prelude::*;

#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "stack_exhausted"] extern fn stack_exhausted() { loop{} }
#[lang = "fail_fmt"] fn fail_fmt() -> ! { loop {} }

extern "C" {
    pub fn printchar(x: u8);
}

#[inline(never)]
fn printstr(text: &str) {
    for ch in text.as_bytes().iter() {
        unsafe { printchar(*ch); }
    }
}

#[no_mangle]
pub extern "C" fn pcboot_main() {
    printstr("pcboot loading...\r\n");
}
