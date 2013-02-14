#include "mem.h"

extern int main(void);
extern char _bss[];
extern char _bss_end[];

int _main(void)
{
    memory_set(_bss, 0, _bss_end - _bss);
    return main();
}
