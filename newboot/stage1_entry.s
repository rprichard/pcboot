; pcboot stage1
;
; stage1 is the 15.5KiB program embedded in the FAT32 reserved area.
;  - It is loaded at 0x8400.
;  - (ebx - 31) gives the boot partition's LBA.
;


        bits 16

        section .text

        global main
main:
        mov sp, main
        mov si, loading_msg
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




        section .data

loading_msg:
        db "pcboot loading...",13,10,0
