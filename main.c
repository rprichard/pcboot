#include <stdbool.h>
#include <stdint.h>

#include "ext2.h"
#include "io.h"
#include "mbr.h"
#include "mbr_boot.h"

int main(void)
{
    print_string("Bootloader test\r\n");
    print_string("1.. 2.. 3.. \r\n");

    static struct mbr mbr;
    read_disk_sectors(boot_disknum, &mbr, 0, 1);
    for (int i = 0; i < 4; ++i) {
        if (mbr.entries[i].type == 0x83) {
            struct ext2 fs;
            ext2_open(&fs, boot_disknum, mbr.entries[i].lba_start);
            ext2_boot_test(&fs);
        }
    }

    return 0;
}
