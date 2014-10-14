ENTRY(main);

SECTIONS
{
    . = 0x7c00;

    .boot_record : {
        *(.boot_record);
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
