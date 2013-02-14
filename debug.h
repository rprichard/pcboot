#ifndef DEBUG_H
#define DEBUG_H

#include <stdarg.h>
#include <stdint.h>

#ifdef BOOT_DEBUG

#define dassert(COND)                                   \
    do {                                                \
        if (!(COND))                                    \
            assert_failure(__FILE__, __LINE__, #COND);  \
    } while(0)

void dassert_failure(const char *file, uint32_t line, const char *condition);
void dprintf(const char *format, ...);
void vdprintf(const char *format, va_list ap);

#else

#define dassert(COND)
#define dprintf(...)
#define vdprintf(...)

#endif /* BOOT_DEBUG */

#endif /* DEBUG_H */
