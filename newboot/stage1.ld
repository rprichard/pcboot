ENTRY(main);

SECTIONS
{
    . = 0x8400;

    .image : {
        *(.text);
        *(.data);
    }

    .bss : {
        *(.bss);
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
