#![crate_name = "sys"]
#![crate_type = "rlib"]
#![feature(core, lang_items, no_std)]
#![no_std]

extern crate core;
use core::prelude::*;
use core::mem;
use core::cmp;

pub mod num_to_str;

extern "C" {
    pub fn call_real_mode(callee: unsafe extern "C" fn(), ...) -> u64;
    fn print_char_16bit();
    fn check_for_int13_extensions();
    fn get_disk_geometry();
    fn read_disk_lba();
    fn read_disk_chs();
    fn halt_16bit();
}

// Define a limited version of the assert! macro here for libsys' use only.
// libsys must be usable from stage1, which lacks argument printing.
macro_rules! assert {
    ($cond:expr) => (
        if !$cond {
            simple_panic(file!(), line!(), "assert fail: ", stringify!($cond))
        }
    );
}

// Disable stack checking, because this function might be used during stack
// overflow handling.
#[no_stack_check] #[inline(never)]
pub fn print_char(ch: u8) {
    unsafe {
        call_real_mode(print_char_16bit, ch as u32);
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

pub fn print_u32(val: u32) {
    let mut storage = num_to_str::U32_ZERO;
    print_str(num_to_str::u32(val as u32, &mut storage));
}

pub const SECTOR_SIZE: usize = 512;
pub type SectorIndex = u32;

// When describing disk geometry, each field is a count.
// When describing a sector index, each field is 0-based, including sector.
#[repr(C)]
pub struct Chs {
    cylinder: u16,
    head: u16,
    sector: u8,
}

pub enum IoMethod {
    Lba,
    Chs(Chs),
}

pub struct Disk {
    bios_number: u8,
    io_method: IoMethod,
}

pub fn open_disk(bios_disk_number: u8) -> Result<Disk, &'static str> {
    let has_int13_extensions = unsafe {
        call_real_mode(
            check_for_int13_extensions,
            bios_disk_number as u32) as u8 != 0
    };
    if has_int13_extensions {
        Ok(Disk {
            bios_number: bios_disk_number,
            io_method: IoMethod::Lba
        })
    } else {
        let mut geometry = Chs { cylinder: 0, head: 0, sector: 0 };
        let geometry_ptr =
            addr_linear_to_segmented(&mut geometry as *mut Chs as u32);
        unsafe {
            if call_real_mode(
                    get_disk_geometry,
                    bios_disk_number as u32,
                    geometry_ptr) as u8 == 0 {
                return Err("cannot read disk geometry");
            }
        }
        Ok(Disk {
            bios_number: bios_disk_number,
            io_method: IoMethod::Chs(geometry)
        })
    }
}

pub fn convert_lba_to_chs(lba: SectorIndex, geometry: &Chs) ->
        Result<Chs, &'static str> {
    let lba_head = lba / geometry.sector as u32;
    let sector = lba % geometry.sector as u32;
    let cylinder = lba_head / geometry.head as u32;
    let head = lba_head % geometry.head as u32;
    if cylinder > 1023 {
        return Err("sector's cylinder exceeds 1023")
    }
    Ok(Chs {
        cylinder: cylinder as u16,
        head: head as u16,
        sector: sector as u8
    })
}

pub fn addr_linear_to_segmented(linear: u32) -> u32 {
    // Ensure that the address if convertable to a 16-bit segment:offset far
    // pointer.  Memory past 0x80000 is reserved[1] anyway, so use that as the
    // limit for simplicity.
    // [1] http://wiki.osdev.org/Memory_Map_(x86)#Overview
    assert!(linear as u32 <= 0x80000);
    let offset = linear % 16;
    let segment = linear / 16;
    (segment << 16) | offset
}

pub fn read_disk_sectors(
        disk: &Disk,
        start_sector: SectorIndex,
        buffer: &mut [u8]) ->
        Result<(), &'static str> {

    // Only allow reads of integral count of sectors.
    assert!(buffer.len() % SECTOR_SIZE == 0);

    // osdev claims that the buffer address must be 2-byte aligned.
    // http://wiki.osdev.org/ATA_in_x86_RealMode_(BIOS)
    assert!(buffer.as_mut_ptr() as u32 % 2 == 0);

    let sector_count = (buffer.len() / SECTOR_SIZE) as SectorIndex;

    let mut loop_count: SectorIndex = sector_count;
    let mut loop_sector: SectorIndex = start_sector;
    let mut loop_buffer: u32 = buffer.as_mut_ptr() as u32;

    // Ensure that even the byte past the end of the buffer is addressable
    // using a 16-bit segment:offset far pointer.  (The function asserts that
    // the linear address is convertible.)
    let _ = addr_linear_to_segmented(loop_buffer + buffer.len() as u32);

    while loop_count > 0 {
        let mut iter_count: i8;

        match disk.io_method {
            IoMethod::Lba => {
                iter_count = cmp::min(loop_count, 127) as i8;
                #[repr(C)]
                struct DiskAccessPacket {
                    size: u8,
                    reserved1: u8,
                    count: i8,
                    reserved2: u8,
                    buffer: u32,
                    lba: u32,
                    lba_high: u32,
                }
                let dap = DiskAccessPacket {
                    size: mem::size_of::<DiskAccessPacket>() as u8,
                    reserved1: 0,
                    count: iter_count,
                    reserved2: 0,
                    buffer: addr_linear_to_segmented(loop_buffer),
                    lba: loop_sector,
                    lba_high: 0
                };
                unsafe {
                    if call_real_mode(
                            read_disk_lba,
                            disk.bios_number as u32,
                            dap) as u8 == 0 {
                        return Err("disk read error");
                    }
                }
            },

            IoMethod::Chs(ref geometry) => {
                match convert_lba_to_chs(loop_sector, &geometry) {
                    Ok(chs) => {
                        // For maximum compatibility, avoid doing a read that
                        // crosses a track boundary.
                        iter_count =
                            cmp::min(loop_count,
                                (geometry.sector - chs.sector) as SectorIndex)
                                    as i8;
                        unsafe {
                            if call_real_mode(
                                    read_disk_chs,
                                    disk.bios_number as u32,
                                    chs,
                                    iter_count as u32,
                                    addr_linear_to_segmented(loop_buffer))
                                    as u8 == 0 {
                                return Err("disk read error");
                            }
                        }
                    },
                    Err(msg) => { return Err(msg) }
                }
            }
        }

        loop_sector += iter_count as SectorIndex;
        loop_count -= iter_count as SectorIndex;
        loop_buffer += iter_count as u32 * SECTOR_SIZE as u32;
    }

    Ok(())
}

pub fn get32(buffer: &[u8], offset: usize) -> u32 {
    ((buffer[offset + 0] as u32) << 0) +
    ((buffer[offset + 1] as u32) << 8) +
    ((buffer[offset + 2] as u32) << 16) +
    ((buffer[offset + 3] as u32) << 24)
}

// Add no_split_stack to disable stack checking.  This function is used during
// stack overflow handling.
#[no_stack_check]
pub fn halt() -> ! {
    unsafe {
        call_real_mode(halt_16bit);

        // Make the rustc compiler happy.  It thinks call_real_mode can return.
        // Changing the declaration of call_real_mode is hard -- rust issue
        // #12707.
        loop {}
    }
}

#[lang = "eh_personality"]
extern fn eh_personality() {}

#[lang = "stack_exhausted"]
extern fn stack_exhausted() {
    print_str("internal error: stack exhausted!");
    halt();
}

pub fn simple_panic(file: &'static str, line: u32, err1: &'static str, err2: &'static str) -> ! {
    print_str("internal error: ");
    print_str(file);
    print_char(b':');
    print_u32(line);
    print_str(": ");
    print_str(err1);
    print_str(err2);
    halt();
}
