#ifndef IO_H
#define IO_H

#include <stdbool.h>
#include <stdint.h>

#define SECTOR_SIZE         512
#define SECTOR_SIZE_LOG2    9

void print_char(char ch);
void print_string(const char *str);
void print_uint32(uint32_t i);
bool is_key_ready(void);
uint16_t read_key(void);
uint32_t read_timer(void);
void pause(void);

void read_disk_sectors(
    uint8_t drive,
    void *buffer,
    uint64_t sector,
    uint32_t count);

void read_disk_bytes(
    uint8_t drive,
    void *buffer,
    uint64_t offset,
    uint32_t count);

#endif /* IO_H */
