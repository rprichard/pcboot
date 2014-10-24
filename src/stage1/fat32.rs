use core;
use core::iter;
use core::prelude::*;

use io;

struct Fat32Volume<'a> {
    disk: &'a io::Disk,
    fsinfo_sec: u32,
    start_fat_sector: u32,
    start_data_sector: u32,
    fat_count: u8,
    sec_per_fat: u32,
    root_dir_clust: u32,
    sec_per_clust: u8,
    total_clusters: u32,
}

#[repr(C, packed)]
#[allow(dead_code)]
// The integer fields are little-endian on disk and in memory.
struct Fat32VBR {
    // These fields are the same for all of FAT12, FAT16, and FAT32.
    /*0*/   jmp: [u8, ..3],             // irrelevant
    /*3*/   oem_name: [u8, ..8],        // irrelevant
    /*11*/  bytes_per_sec: u16,         // XXX: Can this *really* be non-512?
    /*13*/  sec_per_clust: u8,          // useful
    /*14*/  reserved_sec_cnt: u16,      // useful
    /*16*/  fat_count: u8,              // useful
    /*17*/  num_of_dir_entries: u16,    // XXX: Is this used with FAT32?
    /*19*/  total_sectors_16: u16,      // useful (slightly redundant)
    /*21*/  media_descriptor_type: u8,  // nonsense
    /*22*/  sec_per_fat_16: u16,        // useful (FAT12/FAT16 only)
    /*24*/  sec_per_track: u16,         // nonsense
    /*26*/  num_heads: u16,             // nonsense
    /*28*/  hidden_sec_cnt: u32,        // dubious
    /*32*/  total_sectors_32: u32,      // useful (slightly redundant)
    // These fields are FAT32-specific.
    /*36*/  sec_per_fat_32: u32,        // useful
    /*40*/  flags: u16,                 // XXX: What flags are there?
    /*42*/  fat_version_number: u16,    // XXX: What version numbers are there?
    /*44*/  root_dir_clust: u32,        // useful - cluster # of root directory
    /*48*/  fsinfo_sec: u16,            // useful - sector # of fsinfo struct
    /*50*/  backup_vbr_sec: u16,        // useful - TODO: Is this backup in the reserved area?
    /*52*/  _reserved: [u8, ..12],
    /*64*/  drive_number: u8,           // nonsense (BIOS drive number, e.g. 0x80)
    /*65*/  winnt_flags: u8,            // ???
    /*66*/  signature: u8,              // backward-compat?  osdev says: must be 0x28 or 0x29
    /*67*/  serial_number: u32,         // useful
    /*71*/  volume_label: [u8, ..11],   // useful, padded with spaces
    /*82*/  fs_type: [u8, ..8],         // the string "FAT32   "
    /*90*/  boot_code: [u8, ..420],     // irrelevant
    /*510*/ boot_signature: u16,        // 0xaa55
}

#[repr(C, packed)]
#[allow(dead_code)]
struct DirEntry {
    /*0*/   name: [u8, ..11],           // 8.3 filename, padded with spaces
    /*11*/  attr: u8,                   // attributes
    /*12*/  winnt_reserved: u8,         // reserved for Windows NT
    // ctime == creation time, atime == last accessed, mtime == last modified
    /*13*/  ctime_sec10: u8,
    /*14*/  ctime_time: u16,
    /*16*/  ctime_date: u16,
    /*18*/  atime_date: u16,
    /*20*/  cluster_hi: u16,            // high 16 bits of cluster number
    /*22*/  mtime_time: u16,
    /*24*/  mtime_date: u16,
    /*26*/  cluster_lo: u16,
    /*28*/  size: u32,                  // size in bytes
}

#[allow(dead_code)] const ATTR_READ_ONLY: u8    = 0x01;
#[allow(dead_code)] const ATTR_HIDDEN: u8       = 0x02;
#[allow(dead_code)] const ATTR_SYSTEM: u8       = 0x04;
#[allow(dead_code)] const ATTR_VOLUME_ID: u8    = 0x08;
#[allow(dead_code)] const ATTR_DIRECTORY: u8    = 0x10;
#[allow(dead_code)] const ATTR_ARCHIVE: u8      = 0x20;

#[allow(dead_code)]
const ALL_FILE_ATTRIBUTES: u8 =
    ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_ARCHIVE;

pub fn open_volume<'a>(disk: &'a io::Disk, sector: io::SectorIndex) ->
        Fat32Volume<'a> {
    let vbr: Fat32VBR = unsafe {
        let mut vbr_data = [0u8, ..512];
        io::read_disk_sectors(disk, sector, &mut vbr_data).unwrap();
        core::mem::transmute(vbr_data)
    };

    assert!(vbr.sec_per_fat_16 == 0);
    assert!(vbr.total_sectors_16 == 0);
    assert!(vbr.boot_signature == 0xaa55);
    assert!(vbr.bytes_per_sec == 512);

    let sector_lba = sector as u32;
    let fat_area_sectors = vbr.fat_count as u32 * vbr.sec_per_fat_32;
    let reserved_sec_cnt = vbr.reserved_sec_cnt as u32;
    let total_clusters =
        (vbr.total_sectors_32 - reserved_sec_cnt - fat_area_sectors) /
            (vbr.sec_per_clust as u32);

    assert!(vbr.root_dir_clust - 2 < total_clusters);

    Fat32Volume {
        disk: disk,
        fsinfo_sec: sector_lba + (vbr.fsinfo_sec as u32),
        start_fat_sector: sector_lba + reserved_sec_cnt,
        start_data_sector: sector_lba + reserved_sec_cnt + fat_area_sectors,
        fat_count: vbr.fat_count,
        sec_per_fat: vbr.sec_per_fat_32,
        root_dir_clust: vbr.root_dir_clust,
        sec_per_clust: vbr.sec_per_clust,
        total_clusters: total_clusters,
    }
}

fn get32(buffer: &[u8], offset: uint) -> u32 {
    ((buffer[offset + 0] as u32) << 0) +
    ((buffer[offset + 1] as u32) << 8) +
    ((buffer[offset + 2] as u32) << 16) +
    ((buffer[offset + 3] as u32) << 24)
}

pub enum ReadStatus {
    Success,
    Abort,
}

fn read_fat_entry(volume: &Fat32Volume, cluster: u32) -> u32 {
    let fat_offset = cluster * 4;
    let sector = fat_offset / 512;
    let sector_offset = fat_offset % 512;
    let mut buffer = [0u8, ..512];
    io::read_disk_sectors(
        volume.disk,
        volume.start_fat_sector + sector,
        &mut buffer).unwrap();
    get32(&buffer, sector_offset as uint)
}

// TODO: I think I'd like to parameterize this function's return type, but
// I'm concerned that it would bloat code size.
fn read_cluster_chain(
        volume: &Fat32Volume,
        cluster: u32,
        readfn: |buffer: &[u8, ..512]| -> ReadStatus) -> ReadStatus {
    let mut curr_cluster = cluster;
    loop {
        // The first and last data clusters are 2 and
        // volume.total_clusters + 1.
        assert!(curr_cluster - 2 < volume.total_clusters);
        for i in iter::range(0, volume.sec_per_clust) {
            // TODO: Read more than one sector at a time.  We need to figure
            // out how/where to allocate the buffer.
            // TODO: I think we also need to read more than one cluster at a
            // time.  A small FAT32 volume has 1-sector-per-cluster, but the
            // files are nevertheless contiguous on disk.
            let mut buffer = [0u8, ..512];
            io::read_disk_sectors(
                volume.disk,
                volume.start_data_sector + (i as u32) +
                    (curr_cluster - 2) * (volume.sec_per_clust as u32),
                &mut buffer).unwrap();
            match readfn(&buffer) {
                Success => {},
                Abort => { return Abort; },
            }
        }
        let next_entry = read_fat_entry(volume, curr_cluster);
        // TODO: Do we need to do this masking in more places?
        let masked_entry = next_entry & 0x0fff_ffff;
        if (masked_entry - 2) < volume.total_clusters {
            curr_cluster = masked_entry;
        } else if masked_entry >= 0x0fff_fff8 {
            return Success;
        } else {
            fail!("FAT entry for cluster 0x{:x} is bad (0x{:x})",
                curr_cluster, next_entry);
        }
    }
}

// TODO: We need to propagate failure and verify that the cluster chain matches
// the expected file size, and stop sending excess bytes to the callback.
pub fn read_file(
        volume: &Fat32Volume,
        name: &str,
        readfn: |buffer: &[u8, ..512]| -> ReadStatus) -> ReadStatus {

    // TODO: Try to combine or eliminate these variables somehow.
    let mut found = false;
    let mut cluster = 0u32;

    read_cluster_chain(
        volume,
        volume.root_dir_clust,
        |buffer: &[u8, ..512]| -> ReadStatus {
            let table: &[DirEntry, ..16] =
                unsafe { core::mem::transmute(buffer) };
            for entry in table.iter() {
                if (entry.attr & !ALL_FILE_ATTRIBUTES) == 0 &&
                        entry.name == name.as_bytes() {
                    found = true;
                    cluster = ((entry.cluster_hi as u32) << 16) +
                              (entry.cluster_lo as u32);
                    break;
                }
            }
            Abort
        });
    if !found {
        return Abort;
    }
    // TODO: Pass a lambda by value or by reference?
    read_cluster_chain(volume, cluster, readfn)
}
