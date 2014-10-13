ENTRY(main);

SECTIONS
{
    . = 0x9000;

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
