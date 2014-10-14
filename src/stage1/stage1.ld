ENTRY(main);

SECTIONS
{
    ENTRY(_entry)

    /DISCARD/ : {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
        *(.eh_frame);
    }

    . = 0x5000;

    .stack : {
        _stack = .;
        . += 0x4000;
        _stack_end = .;
    }

    . = 0x9000;

    .image : {
        *(.text);
        *(.text.*);
        *(.rodata);
        *(.rodata.*);
        *(.data);
        *(.data.*);
    }

    .bss : {
        _bss = .;
        *(.bss);
        _bss_end = .;
        _bss_size = _bss_end - _bss;
    }
}
