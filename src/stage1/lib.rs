#![crate_name = "stage1"]
#![crate_type = "rlib"]
#![no_std]
#![feature(globs)]
#![feature(lang_items)]
#![feature(macro_rules)]

extern crate core;
use core::prelude::*;

mod macros;

// Define a dummy std module that contains libcore's fmt module.  The std::fmt
// module is needed to satisfy the std::fmt::Arguments reference created by the
// format_args! and format_args_method! built-in macros used in lowlevel.rs's
// failure handling.
mod std {
    pub use core::fmt;
}

mod io;
mod lowlevel;

#[no_mangle]
pub extern "C" fn pcboot_main() -> ! {
    println!("pcboot loading...");
    fail!();
}
