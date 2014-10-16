extern call_real_mode

        section .text


        global print_char_16bit
print_char_16bit:
        bits 16
        mov ah, 0x0e
        mov al, [bp]
        mov bx, 7
        int 0x10
        ret


        section .bss
print_char_data:
        resb 1
