extern call_real_mode

        section .text

        global printchar
printchar:
        bits 32
        mov al, byte [esp + 4]
        mov byte [printchar_char], al
        push printchar_16bit
        call call_real_mode
        pop eax
        ret

printchar_16bit:
        bits 16
        mov ah, 0x0e
        mov al, [printchar_char]
        mov bx, 7
        int 0x10
        ret

        section .bss
printchar_char:
        resb 1
