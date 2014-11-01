extern _transfer_code_segment
extern _stage2_segment
extern _stage2_reloc
extern _stage2_reloc_segment
extern _stage2_para_size

        section .text16
        bits 16


        global transfer_to_stage2
transfer_to_stage2:
        cld

        ;
        ; Turn off interrupts -- the stack gets destroyed during this routine.
        ; stage2 must set up its own stack.
        ;
        cli

        ; Store arguments in the relocated code where they'll be preserved.
        mov al, [bp + 0]
        mov [relocated_code.disk], al
        mov eax, [bp + 4]
        mov [relocated_code.lba], eax

        ; Relocate the rest of transfer routine into a reserved region.
        mov si, relocated_code
        mov ax, _transfer_code_segment
        mov es, ax
        xor di, di
        mov cx, relocated_code_size
        rep movsb
        jmp _transfer_code_segment:0


        ;
        ; Once the code is relocated into the reserved area, move stage2 from
        ; its read buffer into place at the beginning of memory.
        ;
relocated_code:
        mov ax, _stage2_segment             ; source segment
        mov bx, _stage2_reloc_segment       ; dest segment
        mov cx, _stage2_para_size
.loop:
        ; XXX: Will changing the segment registers this many times have
        ; acceptable performance?
        mov ds, ax
        mov es, bx
        xor si, si
        xor di, di
        movsd
        movsd
        movsd
        movsd
        inc ax
        inc bx
        dec cx
        jnz .loop

        ;
        ; Setup the environment for stage2, then jump into it.
        ;

        xor ax, ax
        mov ds, ax
        mov es, ax

        ; "mov dl, 0xNN"
        db 0xb2
.disk:  db 0

        ; "mov esi, 0xNNNNNNNN"
        db 0x66, 0xbe
.lba:   dd 0

        jmp 0:_stage2_reloc

relocated_code_size: equ $ - relocated_code
