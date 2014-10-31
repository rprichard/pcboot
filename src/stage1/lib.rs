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

mod crc32c;
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

    unsafe {
        let file_size = fat32::read_file_reusing_buffer_in_find(&volume, "STAGE2  BIN", _stage2);
        let checksum_offset = (file_size - 4) as uint;
        let expected_checksum = io::get32(_stage2, checksum_offset);
        let actual_checksum = crc32c::compute(&crc32c::table(), _stage2.slice_to(checksum_offset));
        println!("read {} bytes (crc32c:0x{:08x})", file_size, actual_checksum);
        if expected_checksum != actual_checksum {
            io::print_str("pcboot error: bad checksum on stage2.bin!");
            lowlevel::halt();
        }
    }

    println!("");
    println!("done!");
    fail!();
}
