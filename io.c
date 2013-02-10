#include "io.h"

#include "mode_switch.h"

void print_char_16bit(void);

char print_char_ch;

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
