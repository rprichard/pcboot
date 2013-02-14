#include "mem.h"

#include <stdint.h>

/* Equivalent to memcpy. */
void *memory_copy(void *dest, const void *src, uint32_t n)
{
    char *pdest = (char*)dest;
    const char *psrc = (const char*)src;
    for (; n > 0; --n)
        *pdest++ = *psrc++;
    return dest;
}

/* Equivalent to memset. */
void *memory_set(void *s, int c, uint32_t n)
{
    char *ps = (char*)s;
    for (; n > 0; --n)
        *ps++ = c;
    return s;
}
