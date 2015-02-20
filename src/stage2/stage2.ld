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

    . = 0x600;

    .stack : {
        _stack = .;
        . += 0x4000;
        _stack_end = .;

        # Non-Rust functions use stack space but do not check the stack.  For
        # their sake, set Rust's checked stack limit somewhat above the true
        # limit.
        _stack_rust_limit = _stack + 0x1000;
    }

    .tls : {
        _tls = .;
        . += 0x80;
        _tls_end = .;
        _tls_size = _tls_end - _tls;
        _tls_stack_limit = _tls + 0x30;
    }

    . = 0x5000;

    .image16 : {
        *(.text16);
        *(.data16);
    }

    .image : {
        *(.text);
        *(.text.*);
        *(.rodata);
        *(.rodata.*);
        *(.data);
        *(.data.*);
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
