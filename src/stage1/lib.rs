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

mod fat32;

const STAGE2_SIZE: uint = 0x73000;

extern {
    static mut _stage2: [u8, ..STAGE2_SIZE];
    static mut _stage2_end: [u8, ..0];
}

#[no_mangle]
pub extern "C" fn pcboot_main(disk_number: u8, volume_lba: u32) -> ! {
    println!("pcboot loading...");

    unsafe {
        // Ideally, this check would be done at compile-time, but I do not know
        // whether that is possible.
        let linker_size =
            _stage2_end.as_ptr().to_uint() - _stage2.as_ptr().to_uint();
        assert!(linker_size == STAGE2_SIZE);
    }

    let disk = io::open_disk(disk_number).unwrap();
    let volume = fat32::open_volume(&disk, volume_lba as io::SectorIndex);
    let mut offset = 0u;

    fat32::read_file(
        &volume, "STAGE2  BIN",
        |chunk: &[u8, ..512]| -> fat32::ReadStatus {
            unsafe {
                print!(".");
                core::slice::bytes::copy_memory(
                    _stage2.slice_from_mut(offset),
                    chunk);
            }
            offset += chunk.len();
            fat32::Success
        });

    println!("");
    println!("done!");
    fail!();
}
