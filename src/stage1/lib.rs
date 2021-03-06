#![crate_name = "stage1"]
#![crate_type = "staticlib"]
#![feature(lang_items)]
#![no_std]

#[macro_use] extern crate sys;
use core::cell::UnsafeCell;

// Define a dummy std module that contains libcore's fmt module.  The std::fmt
// module is needed to satisfy the std::fmt::Arguments reference created by the
// format_args! and format_args_method! built-in macros used in lowlevel.rs's
// failure handling.
mod std {
    pub use core::fmt;
}

#[macro_use] mod macros;

mod crc32c;
mod fat32;
mod panic;

const STAGE2_SIZE: usize = 0x73000;

#[allow(improper_ctypes)]
extern {
    static _stage2: UnsafeCell<[u8; STAGE2_SIZE]>;
    static _stage2_end: UnsafeCell<[u8; 0]>;
}

#[no_mangle]
pub extern "C" fn pcboot_main(disk_number: u8, volume_lba: u32) -> ! {
    sys::print_str(strlit!("pcboot loading...\r\n"));

    // Ideally, this check would be done at compile-time, but I do not know
    // whether that is possible.
    let linker_size = unsafe {
        _stage2_end.get() as usize - _stage2.get() as usize
    };
    assert!(linker_size == STAGE2_SIZE);

    let disk = sys::open_disk(disk_number).unwrap();
    let volume = fat32::open_volume(&disk, volume_lba as sys::SectorIndex);

    unsafe {
        let stage2 = &mut *_stage2.get();
        let file_size = fat32::read_file_reusing_buffer_in_find(&volume, strlit!("STAGE2  BIN"), stage2);
        let checksum_offset = (file_size - 4) as usize;
        let expected_checksum = sys::get32(stage2, checksum_offset);
        let actual_checksum = crc32c::compute(&crc32c::table(), &stage2[..checksum_offset]);

        sys::print_str(strlit!("read "));
        sys::print_u32(file_size);
        sys::print_str(strlit!(" bytes (crc32c:"));
        sys::print_u32(actual_checksum);
        sys::print_str(strlit!(")\r\n"));

        if expected_checksum != actual_checksum {
            sys::print_str(strlit!("pcboot error: bad checksum on stage2.bin!"));
            sys::halt();
        }
    }

    extern "C" {
        fn transfer_to_stage2();
    }

    unsafe { sys::call_real_mode(transfer_to_stage2, disk_number as u32, volume_lba); }
    sys::halt();
}
