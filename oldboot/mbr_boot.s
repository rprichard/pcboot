        bits 16

extern _mbrtext
extern _stack_segment
extern _stack_initial
extern _stage15_sectors
extern enable_a20
extern init_protected_mode


        section .text

startup:
        ; Setup initial 16-bit environment.
        cli
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
        sti

        ; Relocate the MBR.
        mov si, 0x7c00
        mov di, _mbrtext
        mov cx, 512
        rep movsb
        jmp 0:step1
step1:

        ; Storage area for the disk number.  This is not in .bss because it is
        ; initialized before .bss is zeroed.
        jmp step2
global boot_disknum
boot_disknum:   db 0
step2:

        ; Save the boot disk number.
        mov [boot_disknum], dl

        ; Load stage 1.5 just after the relocated MBR.
        ; (INT 13h AH=02h)
        mov ah, 0x02
        mov al, _stage15_sectors
        mov cx, 2
        xor dh, dh
        mov dl, [boot_disknum]
        mov bx, _mbrtext + 0x200
        int 0x13

        call enable_a20

        jmp init_protected_mode
