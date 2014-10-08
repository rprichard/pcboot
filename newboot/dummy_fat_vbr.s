        bits 16




        section .vbr

        global main
main:
        jmp .start

        ; Reserved space for boot record
        times 90-($-main) db 0

.start:
        cli
        xor ax, ax
        mov ss, ax                      ; Clear SS
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
        mov sp, 0x7c00                  ; Set SP to 0x7c00
        jmp 0:.init_cs

.init_cs
        sti
        mov si, hello_msg
        call print_string
        cli
        hlt




        ; Print a NUL-terminated string.
        ; Inputs: si: the address of the string to print.
        ; Trashes: none
print_string:
        pusha
.loop:
        mov al, [si]
        test al, al
        jz .done
        mov ah, 0x0e
        mov bx, 7
        int 0x10
        inc si
        jmp .loop
.done:
        popa
        ret




hello_msg:
        db "Hello, world! (from dummy_fat_vbr)",13,10,0




        times 504-($-main) db 0
        db "PCBOOT"
        dw 0xaa55
