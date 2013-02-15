        bits 16

extern print_char_16bit
extern print_char_ch


        section .text

global a20_method
a20_method: db 0



global enable_a20
enable_a20:
        cli
        call is_a20_enabled
        cmp ax, 0
        je .step1
        mov dword [a20_method], 0
        jmp .done
.step1
        call enable_a20_bios
        call is_a20_enabled
        cmp ax, 0
        je .step2
        mov dword [a20_method], 1
        jmp .done
.step2:
        ; TODO: Try the keyboard controller and the "fast A20" port.
        mov byte [print_char_ch], 'A'
        call print_char_16bit
        mov byte [print_char_ch], '2'
        call print_char_16bit
        mov byte [print_char_ch], '0'
        call print_char_16bit
        hlt
.done
        sti
        ret



        ; Attempts to enable the A20 line using the BIOS function.
enable_a20_bios:
        mov ax, 0x2401
        int 0x15
        ret



        ; Tests whether the A20 line is enabled or not by writing to 0:0x200
        ; and reading 0xffff:0x210.  If the values are different, we know that
        ; A20 is enabled.  If they're equal, we try again with a different
        ; value.
        ;
        ; The function tries about 100 times, writing to port 0x80 in the loop.
        ; I do not really understand the need to write to port 0x80, but I've
        ; seen both Linux and GRUB do it, so maybe it's important?  The
        ; comments say that it "serializes" things.  I also wonder whether this
        ; code is correct if/when a cache interacts with the A20 line.  It
        ; would be incorrect if caching occurred on the pre-masked addresses.
        ; However, this basic A20 testing approach is used in Linux and GRUB,
        ; and it's documented (in a more defective manner) on the osdev.org
        ; website, so I guess it's safe?
        ;
        ; Entry: interrupts must be disabled
        ; Exit: AX=1 if enabled, AX=0 if not enabled.
is_a20_enabled:
        push fs
        push gs
        push cx
        push word [0x200]
        xor ax, ax
        mov fs, ax
        mov ax, 0xffff
        mov gs, ax
        mov cx, 1
.loop:
        mov [fs:0x200], cx
        out 0x80, al
        out 0x80, al
        mov ax, [gs:0x210]
        cmp ax, cx
        jne .enabled
        cmp cx, 100
        inc cx
        jne .loop
.not_enabled:
        xor ax, ax
        jmp .done
.enabled:
        mov ax, 1
.done:
        pop word [0x200]
        pop cx
        pop gs
        pop fs
        ret
