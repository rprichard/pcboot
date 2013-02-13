#ifndef IO_H
#define IO_H

#include <stdbool.h>
#include <stdint.h>

void print_char(char ch);
void print_string(const char *str);
bool is_key_ready(void);
uint16_t read_key(void);
uint32_t read_timer(void);
void pause(void);
void read_disk(uint8_t drive, uint64_t sector, void *buffer, uint32_t count);

#endif /* IO_H */
