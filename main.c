#include <stdbool.h>
#include <stdint.h>

#include "io.h"
#include "mbr.h"
#include "mbr_boot.h"

static void print_int(uint32_t i)
{
    char buf[16];
    char *pch = buf + sizeof(buf);
    *(--pch) = '\0';
    do {
        *(--pch) = '0' + (i % 10);
        i /= 10;
    } while (i > 0);
    print_string(pch);
}

int main(void)
{
    print_string("Bootloader test\r\n");
    print_string("1.. 2.. 3.. \r\n");

    static struct mbr mbr;
    read_disk(boot_disknum, 0, &mbr, 1);
    for (int i = 0; i < 4; ++i) {
        print_int(mbr.entries[i].lba_count);
        print_string("\r\n");
    }

    return 0;
}
