#include <stdbool.h>
#include <stdint.h>

#include "io.h"

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

    uint32_t t = read_timer() / 18;

    while (true) {
        pause();

        uint32_t t2 = read_timer() / 18;
        if (t2 > t) {
            t = t2;
            print_string(".");
            print_string("\r\n");
        }

        while (is_key_ready()) {
            print_string("scan == ");
            print_int(read_key());
            print_string("\r\n");
        }
    }

    return 0;
}
