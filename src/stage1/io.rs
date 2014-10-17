extern crate core;
use core::prelude::*;
use core::mem;

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

pub const SECTOR_SIZE: uint = 512;
pub type SectorIndex = u32;
pub type SectorBuffer = [u8, ..SECTOR_SIZE];
pub const BLANK_SECTOR: SectorBuffer = [0u8, ..SECTOR_SIZE];

// When describing disk geometry, each field is a count.
// When describing a sector index, each field is 0-based, including sector.
#[repr(C)]
struct Chs {
    cylinder: u16,
    head: u16,
    sector: u8,
}

enum IoMethod {
    LbaMethod,
    ChsMethod(Chs),
}

struct Disk {
    bios_number: u8,
    io_method: IoMethod,
}

pub fn open_disk(bios_disk_number: u8) -> Result<Disk, &'static str> {
    let has_int13_extensions = unsafe {
        extern "C" {
            fn check_for_int13_extensions();
            fn call_real_mode(
                callee: unsafe extern "C" fn(),
                disk: u8) -> u32;
        }
        call_real_mode(check_for_int13_extensions, bios_disk_number) != 0
    };
    if (has_int13_extensions) {
        Ok(Disk {
            bios_number: bios_disk_number,
            io_method: LbaMethod
        })
    } else {
        extern "C" {
            fn get_disk_geometry();
            fn call_real_mode(
                callee: unsafe extern "C" fn(),
                disk: u8,
                geometry: &mut Chs) -> u32;
        }
        unsafe {
            let mut geometry = Chs { cylinder: 0, head: 0, sector: 0 };
            if (call_real_mode(
                    get_disk_geometry,
                    bios_disk_number,
                    &mut geometry) == 0) {
                return Err("cannot read disk geometry");
            }
            Ok(Disk {
                bios_number: bios_disk_number,
                io_method: ChsMethod(geometry)
            })
        }
    }
}

fn convert_lba_to_chs(lba: SectorIndex, geometry: &Chs) ->
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

pub fn read_disk_sector(
            disk: &Disk,
            sector: SectorIndex,
            buffer: &mut SectorBuffer) ->
            Result<(), &'static str> {

    // TODO: investigate alignment requirements on the buffer.

    // Ensure that the entire sector (including the byte just past the buffer's
    // end) is addressible using the 0 segment.
    let buffer_u32 = buffer.as_mut_ptr() as u32;
    assert!(buffer_u32 <= 0xfe00 - 1);

    match disk.io_method {
        LbaMethod => unsafe {
            // osdev claims that the buffer address must be 2-byte aligned.
            // http://wiki.osdev.org/ATA_in_x86_RealMode_(BIOS)
            assert!((buffer_u32 & 1) == 0);
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
            extern "C" {
                fn read_disk_lba();
                fn call_real_mode(
                    callee: unsafe extern "C" fn(),
                    disk: u8,
                    dap: &DiskAccessPacket) -> u32;
            }
            let dap = DiskAccessPacket {
                size: mem::size_of::<DiskAccessPacket>() as u8,
                reserved1: 0,
                count: 1,
                reserved2: 0,
                buffer: buffer_u32,
                lba: sector,
                lba_high: 0
            };
            if (call_real_mode(read_disk_lba, disk.bios_number, &dap) == 0) {
                Err("disk read error")
            } else {
                Ok(())
            }
        },

        ChsMethod(geometry) => unsafe {
            extern "C" {
                fn read_disk_chs();
                fn call_real_mode(
                    callee: unsafe extern "C" fn(),
                    disk: u8,
                    sector: &Chs,
                    buffer: &mut SectorBuffer) -> u32;
            }
            match convert_lba_to_chs(sector, &geometry) {
                Ok(chs) => {
                    if (call_real_mode(
                            read_disk_chs,
                            disk.bios_number,
                            &chs,
                            buffer) == 0) {
                        Err("disk read error")
                    } else {
                        Ok(())
                    }
                }
                Err(msg) => Err(msg)
            }
        }
    }
}
