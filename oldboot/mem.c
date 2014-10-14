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

/* Equivalent to memcmp. */
int memory_compare(const void *s1, const void *s2, uint32_t n)
{
    const char *pch1 = (const char*)s1;
    const char *pch2 = (const char*)s2;
    while (n > 0 && *pch1 == *pch2) {
        pch1++;
        pch2++;
        n--;
    }
    return (unsigned char)*pch1 - (unsigned char)*pch2;
}

#if 0 /* UNUSED */

/* Equivalent to strcmp. */
int string_compare(const char *s1, const char *s2)
{
    while (*s1 == *s2 && *s1 != '\0') {
        s1++;
        s2++;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

/* Equivalent to strncmp. */
int string_n_compare(const char *s1, const char *s2, uint32_t n)
{
    while (n > 0 && *s1 == *s2 && *s1 != '\0') {
        s1++;
        s2++;
        n--;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

#endif
