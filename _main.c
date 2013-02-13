extern int main(void);
extern char _bss[];
extern char _bss_end[];

int _main(void)
{
    char *p = _bss;
    while (p < _bss_end)
        *p++ = '\0';
    return main();
}
