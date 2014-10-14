#ifndef EXT2_H
#define EXT2_H

#include <stdint.h>

struct ext2 {
    uint8_t drive;
    uint64_t start_sector;
    uint64_t start_byte;
    uint32_t group_count;
    uint32_t block_size_in_bytes;
    uint32_t block_size_in_bytes_log2;
    uint32_t block_size_in_sectors;
    uint32_t block_size_in_sectors_log2;
    uint32_t inodes_per_group;
    uint32_t first_data_block;
    uint32_t inode_size; /* in bytes */
};

void ext2_open(struct ext2 *fs, uint8_t drive, uint64_t sector);
void ext2_boot_test(struct ext2 *fs);

#endif /* EXT2_H */
