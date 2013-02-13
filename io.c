#include "io.h"

#include <stdbool.h>
#include <stdint.h>

#include "mode_switch.h"

void print_char_16bit(void);
void is_key_ready_16bit(void);
void read_key_16bit(void);
void read_timer_16bit(void);
void pause_16bit(void);
void read_disk_16bit(void);

char print_char_ch;
bool is_key_ready_out;
uint16_t read_key_out;
uint32_t read_timer_out;
uint16_t read_disk_drive;

struct {
    uint8_t dap_size;
    uint8_t reserved;
    uint16_t count; /* Some Phoenix BIOSes are limited to 127 sectors. [1] */
    uint16_t buffer_offset;
    uint16_t buffer_segment;
    uint64_t sector;
    /* [1] http://en.wikipedia.org/wiki/INT_13H#INT_13h_AH.3D42h:_Extended_Read_Sectors_From_Drive */
} read_disk_dap;

void print_char(char ch)
{
    print_char_ch = ch;
    call_real_mode(&print_char_16bit);
}

void print_string(const char *str)
{
    for (const char *pch = str; *pch != '\0'; ++pch)
        print_char(*pch);
}

bool is_key_ready(void)
{
    call_real_mode(&is_key_ready_16bit);
    return is_key_ready_out;
}

uint16_t read_key(void)
{
    call_real_mode(&read_key_16bit);
    return read_key_out;
}

/* Read the BIOS timer, which increments at approximately 18.206 times per
 * second.  BIOS' counter is a count of ticks since midnight, and it resets to
 * 0 at midnight.  This function instead is also a count of ticks since
 * midnight (roughly), but it instead wraps around at UINT32_MAX, which happens
 * every 2730 days. */
uint32_t read_timer(void)
{
    static uint32_t counter = 0;

    uint32_t t1 = read_timer_out;
    call_real_mode(&read_timer_16bit);
    uint32_t t2 = read_timer_out;

    if (t2 >= t1) {
        counter += (t2 - t1);
    } else {
        /* This is technically not incrementing the counter by enough, but
         * I think this code is less likely to fail. */
        counter += t2;
    }

    return counter;
}

/* Execute "hlt" with interrupts enabled.  This function avoids wasting CPU
 * cycles.  It will return once an interrupt fires, such as the timer
 * interrupt. */
void pause(void)
{
    call_real_mode(&pause_16bit);
}

/* Read sectors from the BIOS disk.  The address of the buffer must be
 * representable in segment:offset form.  (i.e. it must be within the first
 * 1 MiB of RAM.) */
void read_disk(uint8_t drive, uint64_t sector, void *buffer, uint32_t count)
{
    char *pbuffer = buffer;
    read_disk_drive = drive;
    read_disk_dap.dap_size = sizeof(read_disk_dap);
    read_disk_dap.count = 1;
    read_disk_dap.sector = sector;
    for (uint32_t i = 0; i < count;
            ++i, ++read_disk_dap.sector, pbuffer += 512) {
        read_disk_dap.buffer_segment = (uint32_t)pbuffer >> 4;
        read_disk_dap.buffer_offset = (uint32_t)pbuffer & 0xf;
        call_real_mode(&read_disk_16bit);
    }
}
