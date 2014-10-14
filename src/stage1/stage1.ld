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

    . = 0x800;

    .tls : {
        _tls = .;
        . += 128;
        _tls_end = .;
        _tls_size = _tls_end - _tls;
        _tls_stack_limit = _tls + 0x30;
    }

    . = 0x5000;

    .stack : {
        _stack = .;
        . += 0x4000;
        _stack_end = .;

        # Non-Rust functions use stack space but do not check the stack.  For
        # their sake, set Rust's checked stack limit somewhat above the true
        # limit.
        _stack_rust_limit = _stack + 0x1000;
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

    .got : {
        *(.got);
        *(.got.*);
    }

    .bss : {
        _bss = .;
        *(.bss);
        _bss_end = .;
        _bss_size = _bss_end - _bss;
    }
}
