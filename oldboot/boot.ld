ENTRY(main);

SECTIONS
{
    /*
     * MBR
     */

    . = 0x600;
    .mbrtext : {
        _mbrtext = .;
        mbr_boot.o(.text);
        _mbrtext_end = .;
    }

    . = 0x7FE;
    .sig : {
        SHORT(0xaa55);
    }

    /*
     * "Stage 1.5" code immediately after the MBR.
     */

     _stage15 = .;

    . = 0x800;
    .text : {
        _text = .;
        *(.text);
        *(.text.startup);
        _text_end = .;
    }

    .data : {
        _data = .;
        *(.data);
        *(.rodata*);
        _data_end = .;
    }

    /* Pad out the end of the disk sector. */
    .fill : {
        . = ALIGN(0x200);
    }

    _stage15_end = .;
    _stage15_sectors = (_stage15_end - _stage15) / 512;

    /*
     * Uninitialized stack/bss memory.
     */

    /* 4 KB stack. */
    . = ALIGN(0x10);
    .stack : {
        _stack_segment = . >> 4;
        _stack_initial = 0x1000;
        _stack = .;
        . += 0x1000;
        _stack_end = .;
    }

    .bss : {
        _bss = .;
        *(.bss);
        *(.bss*);
        *(COMMON)
        _bss_end = .;
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
