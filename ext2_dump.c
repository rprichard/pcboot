#include "ext2_dump.h"
#include "ext2.h"
#include "io.h"

void ext2_dump(uint8_t drive, uint64_t sector)
{
    static struct ext2fs sb;
    read_disk(drive, sector + 2, &sb, 2);

    print_uint32(sb.e2fs_log_bsize);
    print_string("\r\n");
    print_uint32(sb.e2fs_first_dblock);
    print_string("\r\n");
    print_uint32(sb.e2fs_bcount);
    print_string("\r\n");
}
