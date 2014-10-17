#![crate_name = "stage1"]
#![crate_type = "rlib"]
#![feature(globs)]
#![feature(lang_items)]
#![feature(macro_rules)]
#![feature(phase)]
#![no_std]

// The default phase is "link".  Specifying the "plugin" phase instructs rustc
// to import all the macros marked with #[macro_export].
#[phase(plugin,link)] extern crate core;
use core::prelude::*;

// Import macros in this single place.  The module is marked #![macro_escape],
// so all the macros are copied into this scope.  They will be inherited by all
// the successive modules.
#[path = "../shared/macros.rs"]
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

#[no_mangle]
pub extern "C" fn pcboot_main(disk_number: u8, volume_lba: u32) -> ! {
    println!("pcboot loading...");

    let mut buffer = [0u8, ..io::SECTOR_SIZE];
    let disk = io::open_disk(disk_number).unwrap();
    io::read_disk_sectors(&disk, volume_lba, &mut buffer).unwrap();

    for row in range(16, 32) {
        for col in range(0, 16) {
            print!("{:02x} ", buffer[row * 16 + col]);
        }
        println!("");
    }

    println!("done!");
    fail!();
}
