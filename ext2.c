#include "ext2.h"
#include "ext2_disk_format.h"
#include "io.h"
#include "mem.h"

#include "debug.h"

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

    dprintf("group %u: inode table at block %u\r\n", table_group, group.ext2bgd_i_tables);

    ext2_read_bytes(fs, inode,
        ((uint64_t)group.ext2bgd_i_tables << fs->block_size_in_bytes_log2) +
        table_index * fs->inode_size,
        ext2_min_uint32(sizeof(*inode), fs->inode_size));
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

    dprintf("bsize: %u\r\n", fs->block_size_in_bytes);
}

void ext2_dump(struct ext2 *fs)
{
    struct ext2fs_dinode inode;
    ext2_read_inode(fs, &inode, EXT2_ROOTINO);

    dprintf("atime: %u\r\n", inode.e2di_atime);
    dprintf("ctime: %u\r\n", inode.e2di_ctime);
    dprintf("mtime: %u\r\n", inode.e2di_mtime);
    dprintf("size: %u, nblock: %u\r\n", inode.e2di_size, inode.e2di_nblock);
    for (int i = 0; i < 4; ++i) {
        const uint32_t block = inode.e2di_blocks[i];
        dprintf("block[%u]: %u\r\n", i, block);
        if (block != 0) {
            static char buffer[4096];
            ext2_read_sectors(fs,
                buffer,
                block << fs->block_size_in_sectors_log2,
                fs->block_size_in_sectors);
            char *pbuffer = buffer;
            while (pbuffer < buffer + fs->block_size_in_bytes) {
                const struct ext2fs_direct_2 *const direct =
                        (const struct ext2fs_direct_2*)pbuffer;
                pbuffer += direct->e2d_reclen;
                dprintf("direct.ino = %u\r\n", direct->e2d_ino);
                dprintf("direct.namlen = %u\r\n", direct->e2d_namlen);
                dprintf("direct.name = [%s]\r\n", direct->e2d_name);
            }
        }
    }

    ext2_read_inode(fs, &inode, 12);
    dprintf("inode12: size=%u nblock=%u\r\n", inode.e2di_size, inode.e2di_nblock);
}
