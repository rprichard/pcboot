#include <stdbool.h>
#include <stdint.h>

#include "ext2_dump.h"
#include "io.h"
#include "mbr.h"
#include "mbr_boot.h"

int main(void)
{
    print_string("Bootloader test\r\n");
    print_string("1.. 2.. 3.. \r\n");

    static struct mbr mbr;
    read_disk(boot_disknum, 0, &mbr, 1);
    for (int i = 0; i < 4; ++i) {
        if (mbr.entries[i].type == 0x83) {
            ext2_dump(boot_disknum, mbr.entries[i].lba_start);
        }
    }

    return 0;
}
