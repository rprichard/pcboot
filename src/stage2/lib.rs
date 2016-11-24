#![crate_name = "stage2"]
#![crate_type = "staticlib"]
#![feature(lang_items)]
#![no_std]

#[macro_use] extern crate sys;

// Define a dummy std module that contains libcore's fmt module.  The std::fmt
// module is needed to satisfy the std::fmt::Arguments reference created by the
// format_args! and format_args_method! built-in macros used in lowlevel.rs's
// failure handling.
mod std {
    pub use core::fmt;
}

#[lang = "panic_fmt"] #[cold] #[inline(never)]
extern fn rust_panic_fmt(_msg: std::fmt::Arguments, file: &'static str, line: u32) -> ! {
    // TODO: Replace this with a full argument-printing panic function.
    sys::simple_panic(strref!(file), line, strlit!("rust_panic_fmt"), strlit!(""))
}

#[no_mangle]
pub extern "C" fn pcboot_main(_disk_number: u8, _volume_lba: u32) -> ! {
    sys::print_str(strlit!("pcboot stage2 loading...\r\n"));
    sys::halt();
}
