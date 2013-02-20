ENTRY(main);

SECTIONS
{
    _mbr_unrelocated = 0x7c00;

    . = 0x600;
    .mbr : {
        _mbr = .;
        *(.mbr);
        _mbr_end = .;
    }

    .bss : {
        _bss = .;
        *(.bss);
        _bss_end = .;
        _bss_size = _bss_end - _bss;
    }

    . = 0x3c00;
    .stack : {
        /* 16-KiB stack. */
        _stack = .;
        . += 0x4000;
        _stack_end = .;
    }

    . = 0x7c00;
    .vbr : {
        _vbr = .;
        . += 512;
        _vbr_end = .;
    }

    /DISCARD/ : {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
        *(.eh_frame);
    }
}
