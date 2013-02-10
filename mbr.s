        bits 16

extern _mbrtext
extern _stack_segment
extern _stack_initial

extern mode_switch_test


        section .boot_disknum
global boot_disknum
boot_disknum:
        db 0x00

        section .text

; The symbol must be named main to make ld happy.
global main
main:
        ; Setup initial 16-bit environment.
        sti
        cld
        mov ax, _stack_segment
        mov ss, ax
        mov ax, _stack_initial
        mov sp, ax
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax

        ; Relocate the MBR.
        mov si, 0x7c00
        mov di, _mbrtext
        mov cx, 512
        rep movsb
        jmp 0:.step1
.step1:

        ; Save the boot disk number.
        mov [boot_disknum], dl

        ; Load the rest of the boot loader (31 sectors, 16.5 KiB)
        ; (INT 13h AH=02h)
        mov ax, 0x0200 | 0x1f
        mov cx, 2
        xor dh, dh
        mov dl, [boot_disknum]
        mov bx, _mbrtext + 0x200
        int 0x13

        ; Print a message!
        mov ah, 0x0e
        mov al, '!'
        int 0x10

        jmp mode_switch_test

        hlt
