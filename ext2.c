#include "ext2.h"

#include <stdbool.h>
#include <stdint.h>

#include "debug.h"
#include "ext2_disk_format.h"
#include "io.h"
#include "mem.h"

static inline uint32_t ext2_how_many(uint32_t x, uint32_t y)
{
    return (x + y - 1) / y;
}

static inline uint32_t ext2_max_uint32(uint32_t x, uint32_t y)
{
    return x > y ? x : y;
}

static inline uint32_t ext2_min_uint32(uint32_t x, uint32_t y)
{
    return x < y ? x : y;
}

static inline uint64_t ext2_min_uint64(uint64_t x, uint64_t y)
{
    return x < y ? x : y;
}

static inline uint32_t ext2_group_descriptor_size(struct ext2 *fs)
{
    /* TODO: is this dynamic? */
    return sizeof(struct ext2fs_gd);
}

static inline void ext2_read_sectors(
    struct ext2 *fs,
    void *buffer,
    uint64_t sector,
    uint32_t count)
{
    read_disk_sectors(fs->drive, buffer, fs->start_sector + sector, count);
}

static inline void ext2_read_bytes(
    struct ext2 *fs,
    void *buffer,
    uint64_t offset,
    uint32_t count)
{
    read_disk_bytes(fs->drive, buffer, fs->start_byte + offset, count);
}

static void ext2_read_group_descriptor(
    struct ext2 *fs,
    struct ext2fs_gd *group,
    uint32_t group_index)
{
    ext2_read_bytes(fs, group,
        ((fs->first_data_block + 1) << fs->block_size_in_bytes_log2) +
        group_index * ext2_group_descriptor_size(fs),
        sizeof(struct ext2fs_gd));
}

static void ext2_read_inode(
    struct ext2 *fs,
    struct ext2fs_dinode *inode,
    uint32_t inode_index)
{
    memory_set(inode, 0, sizeof(*inode));

    --inode_index;

    const uint32_t table_group = inode_index / fs->inodes_per_group;
    const uint32_t table_index = inode_index % fs->inodes_per_group;

    /* First locate the inode table. */
    struct ext2fs_gd group;
    ext2_read_group_descriptor(fs, &group, table_group);
    ext2_read_bytes(fs, inode,
        ((uint64_t)group.ext2bgd_i_tables << fs->block_size_in_bytes_log2) +
        table_index * fs->inode_size,
        ext2_min_uint32(sizeof(*inode), fs->inode_size));
}

static void ext2_read_inode_data_map(
    struct ext2 *fs,
    uint64_t *amount,
    uint32_t *block_table,
    int block_count,
    int tree_depth,
    bool (*callback)(void *baton, void *buffer, uint32_t amount),
    void *baton)
{
    for (int i = 0; i < block_count; ++i) {
        if (*amount == 0)
            return;
        static uint32_t sub_block[4][EXT2_MAX_BLOCK_SIZE / sizeof(uint32_t)];
        ext2_read_sectors(
            fs,
            sub_block[tree_depth],
            block_table[i] << fs->block_size_in_sectors_log2,
            fs->block_size_in_sectors);
        if (tree_depth == 0) {
            const uint32_t chunk_amount =
                    ext2_min_uint64(*amount, fs->block_size_in_bytes);
            if (callback(baton, sub_block[tree_depth], chunk_amount))
                *amount -= chunk_amount;
            else
                *amount = 0; /* abort reading */
        } else {
            ext2_read_inode_data_map(
                fs, amount,
                sub_block[tree_depth],
                fs->block_size_in_bytes / sizeof(uint32_t),
                tree_depth - 1,
                callback, baton);
        }
    }
}

/* Read all of the inode's data and pass it to the callback one block at a
 * time.  The callback's amount parameter may be less than a block on the last
 * call.  The callback returns true to continue reading and false to abort.
 *
 * This function is not reentrant.  Do not call it from its callback.
 *
 * TODO: For ext4, this function needs to read the extent tree instead. */
void ext2_read_inode_data(
    struct ext2 *fs,
    struct ext2fs_dinode *inode,
    bool (*callback)(void *baton, void *buffer, uint32_t amount),
    void *baton)
{
#ifdef BOOT_DEBUG
    static bool in_call = false;
    dassert(!in_call && "Reentrant call to ext2_read_inode_data not allowed.");
    in_call = true;
#endif

    /* TODO: Is the inode->e2di_size_hi field always valid? */
    uint64_t amount = inode->e2di_size | ((uint64_t)inode->e2di_size_hi << 32);

    ext2_read_inode_data_map(
        fs, &amount,
        inode->e2di_blocks,
        EXT2_NDIR_BLOCKS,
        0, callback, baton);
    for (int i = 0; i < 3; ++i) {
        ext2_read_inode_data_map(
            fs, &amount,
            &inode->e2di_blocks[EXT2_IND_BLOCK + i],
            1, 1 + i, callback, baton);
    }

#ifdef BOOT_DEBUG
    dassert(in_call);
    in_call = false;
#endif
}

void ext2_open(struct ext2 *fs, uint8_t drive, uint64_t sector)
{
    fs->drive = drive;
    fs->start_sector = sector;
    fs->start_byte = sector << SECTOR_SIZE_LOG2;
    static struct ext2fs_super_block sb;
    ext2_read_sectors(fs, &sb, 2, sizeof(sb) / SECTOR_SIZE);
    fs->group_count =
            ext2_how_many(sb.e2fs_bcount - sb.e2fs_first_dblock, sb.e2fs_bpg);
    fs->block_size_in_sectors_log2 = 10 - SECTOR_SIZE_LOG2 + sb.e2fs_log_bsize;
    fs->block_size_in_sectors = 1 << fs->block_size_in_sectors_log2;
    fs->block_size_in_bytes_log2 =
            SECTOR_SIZE_LOG2 + fs->block_size_in_sectors_log2;
    fs->block_size_in_bytes = 1 << fs->block_size_in_bytes_log2;
    fs->inodes_per_group = sb.e2fs_ipg;
    fs->first_data_block = sb.e2fs_first_dblock;
    if (sb.e2fs_rev == E2FS_REV0) {
        fs->inode_size = E2FS_REV0_INODE_SIZE;
    } else {
        fs->inode_size = sb.e2fs_inode_size;
    }
}


bool ext2_dump_direct(void *baton, void *buffer, uint32_t amount)
{
    char *pbuffer_end = (char*)buffer + amount;
    char *pbuffer = buffer;
    while (pbuffer < pbuffer_end) {
        const struct ext2fs_direct_2 *const direct =
                (const struct ext2fs_direct_2*)pbuffer;
        pbuffer += direct->e2d_reclen;
        dprintf("direct.ino = %u\r\n", direct->e2d_ino);
        dprintf("direct.namlen = %u\r\n", direct->e2d_namlen);
        dprintf("direct.name = [%s]\r\n", direct->e2d_name);
        const uint32_t len = sizeof("memtest86+.bin") - 1;
        if (direct->e2d_namlen == len &&
                !memory_compare(direct->e2d_name, "memtest86+.bin", len)) {
            *(uint32_t*)baton = direct->e2d_ino;
        }
    }
    return true;
}

bool ext2_dump_data(void *baton, void *buffer, uint32_t amount)
{
    /* dprintf("amount=%u\r\n", amount); */
#if 0
    for (int i = 0; i < amount; ++i) {
        dprintf("%x ", ((unsigned char*)buffer)[i]);
    }
    dprintf("\r\n");
#endif
    return true;
}

struct linux16_boot {
    char *address;
};

bool ext2_linux16_boot(void *baton, void *buffer, uint32_t amount)
{
    struct linux16_boot *boot = (struct linux16_boot*)baton;

    if (boot->address >= (char*)0x90000) {
        dassert(amount == 1024);
        if (boot->address == (char*)0x90800) {
            /* Special case: put the first sector at 0x90800, but put the
             * next sector at 0x10000. */

            //dprintf("Copied 0x%x from 0x%x to 0x%x\r\n", 512, buffer, (char*)0x90800);
            //dprintf("Copied 0x%x from 0x%x to 0x%x\r\n", 512, (char*)buffer + 512, (char*)0x10000);

            memory_copy((char*)0x90400, buffer, 512);
            memory_copy((char*)0x10000, (char*)buffer + 512, 512);
            boot->address = (char*)0x10200;
            return true;
        }
    }

    //dprintf("Copied 0x%x from 0x%x to 0x%x\r\n", amount, buffer, boot->address);
    //pause(); pause(); pause(); pause(); pause(); pause(); pause(); pause(); pause(); pause(); pause(); pause();

    memory_copy(boot->address, buffer, amount);
    boot->address += amount;
    return true;
}

void linux16_boot_test_16bit(void);
#include "mode_switch.h"

void ext2_boot_test(struct ext2 *fs)
{
    struct ext2fs_dinode inode;
    ext2_read_inode(fs, &inode, EXT2_ROOTINO);

    dprintf("atime: %u\r\n", inode.e2di_atime);
    dprintf("ctime: %u\r\n", inode.e2di_ctime);
    dprintf("mtime: %u\r\n", inode.e2di_mtime);
    dprintf("size: %u, nblock: %u\r\n", inode.e2di_size, inode.e2di_nblock);

    uint32_t boot_inode = 0;
    ext2_read_inode_data(fs, &inode, ext2_dump_direct, &boot_inode);

    dassert(boot_inode != 0 && "Cannot find memtest86+.bin for booting.");
    struct linux16_boot boot = { (char*)0x90000 };
    ext2_read_inode(fs, &inode, boot_inode);
    ext2_read_inode_data(fs, &inode, ext2_linux16_boot, &boot);
    dprintf("memtest86+.bin loaded...\r\n");

    call_real_mode(&linux16_boot_test_16bit);
}
