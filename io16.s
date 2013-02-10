        bits 16
        section .text

extern print_char_ch

global print_char_16bit
print_char_16bit:
        mov ah, 0x0e
        mov al, [print_char_ch]
        int 0x10
        ret
