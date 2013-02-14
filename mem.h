#ifndef MEM_H
#define MEM_H

#include <stdint.h>

void *memory_copy(void *dest, const void *src, uint32_t n);
void *memory_set(void *s, int c, uint32_t n);
int memory_compare(const void *s1, const void *s2, uint32_t n);
#if 0 /* UNUSED */
int string_compare(const char *s1, const char *s2);
int string_n_compare(const char *s1, const char *s2, uint32_t n);
#endif

#endif /* MEM_H */
