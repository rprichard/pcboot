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

/* Return a pointer to a buffer containing the given block's data.  The buffer
 * is valid until the next call to this routine. */
void *ext2_block(struct ext2 *fs, uint32_t block_number)
{
    static char block_data[4096];
    ext2_read_sectors(fs, block_data,
        block_number << fs->block_size_in_sectors_log2,
        fs->block_size_in_sectors);
    return block_data;
}

/* Maps a block of an inode's content to its block number in the volume. */
uint32_t ext2_inode_block(
    struct ext2 *fs,
    uint32_t inode_number,
    uint32_t block_number)
{
    /* TODO: Some amount of caching might be needed here (or at a lower
     * abstraction) to avoid seek latency. */
    static struct ext2fs_dinode inode;
    ext2_read_inode(fs, &inode, inode_number);

    for (int i = 0; i < EXT2_NDIR_BLOCKS; ++i) {
        if (block_number == 0)
            return inode.e2di_blocks[i];
        block_number--;
    }

    int height;
    const uint32_t block_children_count_log2 =
        fs->block_size_in_bytes_log2 - 2;
    const uint32_t block_children_count =
        1 << block_children_count_log2;

    /* Determine the height of the indirect tree containing the requested
     * block. */
    int tree_block_count = 1 << block_children_count_log2;
    if (block_number < tree_block_count) {
        height = 0;
    } else {
        block_number -= tree_block_count;
        tree_block_count <<= block_children_count_log2;
        if (block_number < tree_block_count) {
            height = 1;
        } else {
            block_number -= tree_block_count;
            height = 2;
        }
    }

    uint32_t lookup_block = inode.e2di_blocks[EXT2_NDIR_BLOCKS + height];
    for (int j = height; j >= 0; --j) {
        /* TODO: Some amount of caching might be needed here (or at a lower
         * abstraction) to avoid seek latency. */
        const uint32_t table_index =
            (block_number >> (block_children_count_log2 * height)) &
                (block_children_count - 1);
        const uint32_t *table = (uint32_t*)ext2_block(fs, lookup_block);
        lookup_block = table[table_index];
    }

    return lookup_block;
}

/* This routine is based on read_disk_bytes.  The two could possibly be merged
 * to reduce code size. */
void ext2_read_inode_bytes(
    struct ext2 *const fs,
    void *const buffer,
    const uint32_t inode_number,
    const uint64_t offset,
    const uint32_t count)
{
    char *iter_buffer = buffer;
    uint32_t iter_block = offset >> fs->block_size_in_bytes_log2;
    uint32_t iter_offset = offset & (fs->block_size_in_bytes - 1);
    uint32_t iter_count = count;

    while (iter_count > 0) {
        char *block_data =
            ext2_block(fs, ext2_inode_block(fs, inode_number, iter_block));
        const uint32_t read_amount =
            ext2_min_uint32(iter_count, fs->block_size_in_bytes - iter_offset);
        memory_copy(
            iter_buffer,
            block_data + iter_offset,
            read_amount);
        iter_buffer += read_amount;
        iter_block++;
        iter_offset = 0;
        iter_count -= read_amount;
    }
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

    static unsigned char buffer[1024];
    ext2_read_inode_bytes(fs, buffer, EXT2_ROOTINO, 0, 1024);
    uint32_t memtest_inode = 0;

    {
        char *pbuffer_end = (char*)buffer + 1024;
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
                memtest_inode = direct->e2d_ino;
            }
        }
        dassert(memtest_inode != 0);
    }

    {
        struct ext2fs_dinode inode;
        ext2_read_inode(fs, &inode, memtest_inode);
        const uint32_t memtest_size = inode.e2di_size;

        ext2_read_inode_bytes(fs, (char*)0x90000, memtest_inode, 0, 512 * 5);
        ext2_read_inode_bytes(fs, (char*)0x10000, memtest_inode, 512 * 5, memtest_size - 512 * 5);
        dprintf("memtest86+.bin loaded...\r\n");
        call_real_mode(&linux16_boot_test_16bit);
    }
}
