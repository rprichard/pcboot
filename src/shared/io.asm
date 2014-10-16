extern call_real_mode

        section .text


        global print_char_32bit
print_char_32bit:
        bits 32
        mov al, byte [esp + 4]
        mov byte [print_char_data], al
        push print_char_16bit
        call call_real_mode
        pop eax
        ret


print_char_16bit:
        bits 16
        mov ah, 0x0e
        mov al, [print_char_data]
        mov bx, 7
        int 0x10
        ret


        section .bss
print_char_data:
        resb 1
