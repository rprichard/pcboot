ENTRY(main);

SECTIONS
{
    . = 0x7c00;
    .vbr : {
        _vbr = .;
        *(.vbr);
        _vbr_end = .;
    }

    . = 0x3c00;
    .stack : {
        /* 16-KiB stack. */
        _stack = .;
        . += 0x4000;
        _stack_end = .;
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
