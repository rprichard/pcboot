        bits 16
        section .text

extern print_char_ch
extern is_key_ready_out
extern read_key_out
extern read_timer_out

global print_char_16bit
print_char_16bit:
        mov ah, 0x0e
        mov al, [print_char_ch]
        int 0x10
        ret

global is_key_ready_16bit
is_key_ready_16bit:
        mov ah, 0x01
        int 0x16
        jz .empty
        mov byte [is_key_ready_out], 1
        ret
.empty:
        mov byte [is_key_ready_out], 0
        ret

global read_key_16bit
read_key_16bit:
        mov ah, 0x00
        int 0x16
        mov [read_key_out], ax
        ret

global read_timer_16bit
read_timer_16bit:
        mov ah, 0x00
        int 0x1a
        mov [read_timer_out], dx
        mov [read_timer_out+2], cx
        ret

global pause_16bit
pause_16bit:
        hlt
        ret
