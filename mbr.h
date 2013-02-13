#ifndef MBR_H
#define MBR_H

#include <stdint.h>

/* Bits 0-5 of sect_cylinder_high are the sector.  Bits 6-7 of
 * sect_cylinder_high are bits 8-9 of the cylinder. */
struct chs {
    uint8_t head;
    uint8_t sect_cylinder_high;
    uint8_t cylinder_low;
};

struct mbr_entry {
    uint8_t active;
    struct chs start;
    uint8_t type;
    struct chs end;
    uint32_t lba_start;
    uint32_t lba_count;
};

struct __attribute__((packed)) mbr {
    char boot_code[446];
    struct mbr_entry entries[4];
    uint16_t signature;
};

#endif /* MBR_H */
