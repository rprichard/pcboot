#include "debug.h"

#include <stdarg.h>

#include "io.h"

#ifdef BOOT_DEBUG

static void debug_abort(void)
{
    print_string("Aborted\r\n");
    __asm("hlt");
    while(1);
}

static void print_uint32_hex(uint32_t i)
{
    char buf[16];
    char *pch = buf + sizeof(buf);
    *(--pch) = '\0';
    do {
        *(--pch) = "0123456789abcdef"[i % 16];
        i /= 16;
    } while (i > 0);
    print_string(pch);
}

void dprintf(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vdprintf(format, ap);
    va_end(ap);
}

void vdprintf(const char *format, va_list ap)
{
    for (const char *pch = format; *pch != '\0'; ++pch) {
        const char ch = *pch;
        if (ch == '%') {
            const char ch2 = *(++pch);
            if (ch2 == 'u') {
                print_uint32(va_arg(ap, unsigned int));
            } else if (ch2 == 'x') {
                print_uint32_hex(va_arg(ap, unsigned int));
            } else if (ch2 == 'c') {
                print_char(va_arg(ap, int));
            } else if (ch2 == 's') {
                print_string(va_arg(ap, const char*));
            } else {
                dprintf("error: invalid vdprintf format char '%c'\r\n", ch2);
                debug_abort();
            }
        } else {
            print_char(ch);
        }
    }
}

#endif /* BOOT_DEBUG */
