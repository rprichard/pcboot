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

    .tls : {
        _tls = .;
        . += 0x80;
        _tls_end = .;
        _tls_size = _tls_end - _tls;
        _tls_stack_limit = _tls + 0x30;
    }

    .bss : {
        _bss = .;
        *(.bss);
        _bss_end = .;
        _bss_size = _bss_end - _bss;
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

    . = 0xc800;

    .stage2 : {
        _stage2 = .;
        _stage2_segment = . >> 4;
        _stage2_reloc = 0x5000;                 # Address to copy stage2 to.
        _stage2_reloc_segment = _stage2_reloc >> 4;
        . += 0x73000;
        _stage2_end = .;
        _stage2_size = _stage2_end - _stage2;
        _stage2_para_size = _stage2_size >> 4;
    }

    . = 0x7ff80;

    #
    # This section reserves memory for the routine that transfers control to
    # stage2.  That routine will move stage2 into place and potentially
    # overwrite parts of stage1.
    #
    .transfer_code : {
        _transfer_code_segment = . >> 4;
        . += 0x80;
    }
}
