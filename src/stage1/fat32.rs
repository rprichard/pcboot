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
    assert!(vbr.sec_per_clust != 0);

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

const FAT_TABLE_CACHE_SIZE: uint = 1024;

struct FatTable<'a> {
    volume: &'a Fat32Volume<'a>,
    cache_lba: Option<u32>,
    cache_buffer: [u8, ..FAT_TABLE_CACHE_SIZE],
}

impl<'a> FatTable<'a> {
    fn entry(&mut self, cluster: u32) -> u32 {
        let fat_offset = cluster * 4;
        let cache_size = FAT_TABLE_CACHE_SIZE as u32;
        let sector = fat_offset / cache_size * (cache_size / 512);
        let offset = fat_offset % cache_size;

        let cache_hit = match self.cache_lba {
            None => false,
            Some(cache_lba) => cache_lba == sector
        };

        if !cache_hit {
            self.cache_lba = Some(sector);
            io::read_disk_sectors(
                self.volume.disk,
                self.volume.start_fat_sector + sector,
                &mut self.cache_buffer).unwrap();
        }
        get32(&self.cache_buffer, offset as uint)
    }
}

fn fat_table<'a>(volume: &'a Fat32Volume<'a>) -> FatTable<'a> {
    FatTable {
        volume: volume,
        cache_lba: None,
        cache_buffer: [0u8, ..FAT_TABLE_CACHE_SIZE]
    }
}

struct ClusterIterator<'a, 'b:'a> {
    fat_table: &'a mut FatTable<'b>,
    next : Option<u32>,
}

impl<'a, 'b> ClusterIterator<'a, 'b> {
    fn next(&mut self) -> Option<u32> {
        match self.next {
            None => None,
            Some(cluster) => {
                // TODO: Do we need to do this masking in more places?
                let next = self.fat_table.entry(cluster) & 0x0fff_ffff;
                self.next = {
                    if next >= 2 && (next - 2) <
                            self.fat_table.volume.total_clusters {
                        Some(next)
                    } else if next >= 0x0fff_fff8 {
                        None
                    } else {
                        fail!("FAT entry for cluster 0x{:x} is bad (0x{:x})",
                            cluster, next);
                    }
                };
                Some(cluster)
            }
        }
    }
}

fn iterate_cluster_chain<'a, 'b>(
        fat_table: &'a mut FatTable<'b>,
        cluster: u32) -> ClusterIterator<'a, 'b> {
    ClusterIterator {
        fat_table: fat_table,
        next: Some(cluster),
    }
}

struct SectorIterator<'a, 'b:'a> {
    volume: &'b Fat32Volume<'b>,
    cluster_iterator: ClusterIterator<'a, 'b>,
    next_count: u8,
    next_ret: u32,
}

impl<'a, 'b> SectorIterator<'a, 'b> {
    fn next(&mut self) -> Option<u32> {
        if self.next_count == 0 {
            match self.cluster_iterator.next() {
                None => { return None; },
                Some(cluster) => {
                    self.next_ret =
                        self.volume.start_data_sector +
                            (cluster - 2) * (self.volume.sec_per_clust as u32);
                    self.next_count = self.volume.sec_per_clust;
                }
            }
        }
        let ret = self.next_ret;
        self.next_count -= 1;
        Some(ret)
    }
}

fn iterate_node_sectors<'a, 'b>(
        fat_table: &'a mut FatTable<'b>,
        cluster: u32) -> SectorIterator<'a, 'b> {
    SectorIterator {
        volume: fat_table.volume,
        cluster_iterator: iterate_cluster_chain(fat_table, cluster),
        next_count: 0,
        next_ret: 0,
    }
}

struct FragmentIterator<'a, 'b:'a> {
    sector_iterator: SectorIterator<'a, 'b>,
    max_sectors: u32,
    queued: Option<u32>,
}

struct Fragment {
    start_sector: u32,
    sector_count: u32,
}

impl<'a, 'b> FragmentIterator<'a, 'b> {
    fn next(&mut self) -> Option<Fragment> {
        let start_sector = {
            if self.queued.is_none() {
                match self.sector_iterator.next() {
                    None => { return None; },
                    Some(sector) => sector
                }
            } else {
                self.queued.unwrap()
            }
        };
        let mut last_sector = start_sector;
        while (last_sector - start_sector + 1) < self.max_sectors {
            match self.sector_iterator.next() {
                None => {
                    break;
                },
                Some(sector) => {
                    if (sector == last_sector + 1) {
                        last_sector = sector;
                    } else {
                        self.queued = Some(sector);
                        break;
                    }
                },
            }
        }
        Some(Fragment {
            start_sector: start_sector,
            sector_count: last_sector - start_sector + 1
        })
    }
}

fn iterate_fragments<'a, 'b>(
        fat_table: &'a mut FatTable<'b>,
        cluster: u32,
        max_sectors: u32) -> FragmentIterator<'a, 'b> {
    FragmentIterator {
        sector_iterator: iterate_node_sectors(fat_table, cluster),
        max_sectors: max_sectors,
        queued: None,
    }
}

struct FileLocation {
    cluster: u32,
    size: u32,
}

fn find_file(
    volume: &Fat32Volume,
    name: &str,
    fat_table: &mut FatTable,
    tmp_buf: &mut [u8]) -> Option<FileLocation>
{
    let mut it = iterate_fragments(
        fat_table, volume.root_dir_clust, tmp_buf.len() as u32 / 512);
    let mut fragment: Option<Fragment>;
    while { fragment = it.next(); fragment.is_some() } {
        let read_buffer = tmp_buf.slice_to_mut(
            (fragment.unwrap().sector_count * 512) as uint);
        io::read_disk_sectors(
            volume.disk,
            fragment.unwrap().start_sector,
            read_buffer).unwrap();

        // Is there a safe/better way to do this?
        let table: &[DirEntry] =
            unsafe {
                core::mem::transmute(
                    core::raw::Slice {
                        data: read_buffer.as_ptr(),
                        len: read_buffer.len() /
                            core::mem::size_of::<DirEntry>(),
                    })
            };

        for entry in table.iter() {
            if (entry.attr & !ALL_FILE_ATTRIBUTES) == 0 &&
                    entry.name == name.as_bytes() {
                return Some(FileLocation {
                    cluster: ((entry.cluster_hi as u32) << 16) +
                             (entry.cluster_lo as u32),
                    size: entry.size
                });
            }
        }
    }
    None
}

// TODO: How is this made generic?
fn round_up(base: u32, multiplier: u32) -> u32 {
    (base + multiplier - 1) / multiplier * multiplier
}

fn read_node_data(
        volume: &Fat32Volume,
        location: FileLocation,
        buffer: &mut [u8],
        fat_table: &mut FatTable) {
    let mut it = iterate_fragments(
        fat_table, location.cluster, 0xffff_ffff);
    let mut fragment: Option<Fragment>;
    let mut offset = 0u32;
    let cluster_bytes = volume.sec_per_clust as u32 * 512;
    let full_size = round_up(location.size, cluster_bytes);
    while { fragment = it.next(); fragment.is_some() } {
        let fragment_bytes = fragment.unwrap().sector_count * 512;
        assert!(offset + fragment_bytes <= full_size);
        io::read_disk_sectors(
            volume.disk,
            fragment.unwrap().start_sector,
            buffer.slice_mut(offset as uint, fragment_bytes as uint)).unwrap();
        offset += fragment_bytes;
    }
    assert!(offset == full_size);
}

// Returns the size of the file returned.
pub fn read_file_reusing_buffer_in_find(
        volume: &Fat32Volume,
        name: &str,
        buffer: &mut [u8]) -> u32 {
    let mut table = fat_table(volume);
    match find_file(volume, name, &mut table, buffer) {
        None => {
            fail!("File '{}' missing from pcboot volume!", name);
        }
        Some(location) => {
            read_node_data(volume, location, buffer, &mut table);
            location.size
        }
    }
}
