#ifndef MEM_H
#define MEM_H

#include <stdint.h>

void *memory_copy(void *dest, const void *src, uint32_t n);
void *memory_set(void *s, int c, uint32_t n);

#endif /* MEM_H */
