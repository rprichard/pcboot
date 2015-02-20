#![crate_name = "stage2"]
#![crate_type = "rlib"]
#![feature(lang_items)]
#![feature(no_std)]
#![feature(core)]
#![no_std]

extern crate core;
use core::prelude::*;

#[path = "../shared/macros.rs"] #[macro_use]
mod macros;

// Define a dummy std module that contains libcore's fmt module.  The std::fmt
// module is needed to satisfy the std::fmt::Arguments reference created by the
// format_args! and format_args_method! built-in macros used in lowlevel.rs's
// failure handling.
mod std {
    pub use core::fmt;
}

#[path = "../shared/io.rs"]             mod io;
#[path = "../shared/lowlevel.rs"]       mod lowlevel;
#[path = "../shared/num_to_str.rs"]     mod num_to_str;

#[no_mangle]
pub extern "C" fn pcboot_main(disk_number: u8, volume_lba: u32) -> ! {
    io::print_str("pcboot stage2 loading...\r\n");
    lowlevel::halt();
}
