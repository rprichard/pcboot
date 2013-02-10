ENTRY(main);

SECTIONS
{
    /*
     * MBR
     */

    . = 0x600;
    .mbrtext : {
        _mbrtext = .;
        mbr.o(.text);
        _mbrtext_end = .;
    }

    . = 0x7FE;
    .sig : {
        SHORT(0xaa55);
    }

    /*
     * "Stage 1.5" code immediately after the MBR.
     */

    . = 0x800;
    .text : {
        _text = .;
        *(.text);
        _text_end = .;
    }

    .data : {
        _data = .;
        *(.bss);
        *(.bss*);
        *(.data);
        *(.rodata*);
        *(COMMON)
        _data_end = .;
    }

    /* Pad out the end of the disk sector. */
    .fill : {
        . = ALIGN(0x200);
    }

    /*
     * Volatile non-initialized memory.
     */

    .boot_disknum : {
        mbr.o(.boot_disknum);
    }

    /* 4 KB stack. */
    . = 0x7F000;
    .stack : {
        _stack_segment = . >> 4;
        _stack_initial = 0x1000;
        _stack = .;
        . += 0x1000;
        _stack_end = .;
    }

    /DISCARD/ : {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
    }
}
