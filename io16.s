        bits 16
        section .text

extern print_char_ch
extern is_key_ready_out
extern read_key_out
extern read_timer_out
extern read_disk_drive
extern read_disk_dap

global print_char_16bit
print_char_16bit:
        mov ah, 0x0e
        mov al, [print_char_ch]
        mov bx, 7
        int 0x10
        ret

global is_key_ready_16bit
is_key_ready_16bit:
        mov ax, 0x100
        int 0x16
        jz .empty
        mov byte [is_key_ready_out], 1
        ret
.empty:
        mov byte [is_key_ready_out], 0
        ret

global read_key_16bit
read_key_16bit:
        xor ax, ax
        int 0x16
        mov [read_key_out], ax
        ret

global read_timer_16bit
read_timer_16bit:
        xor ax, ax
        int 0x1a
        mov [read_timer_out], dx
        mov [read_timer_out+2], cx
        ret

global pause_16bit
pause_16bit:
        hlt
        ret

global read_disk_16bit
read_disk_16bit:
        mov ax, 0x4200
        mov dx, [read_disk_drive]
        mov si, read_disk_dap
        int 0x13
        ret
