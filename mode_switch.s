extern main
extern _stack
extern _stack_segment
extern _stack_end


        ;
        ; Define the GDT for protected mode.  There are four segments:
        ;  - Code and data segments exposing the entire 4GB address space.
        ;  - Code and data segments with a 16-bit limit, used to transition
        ;    back to real mode.
        ;

        section .data
        align 16
gdt:
        ; LGDT operand
        dw .end-gdt
        dd gdt
        dw 0
        ; 32-bit code segment, Limit=0xfffff, Base=0, Type=Code+R, S=1, DPL=0, P=1, L=0, D=1, G=1
        dd 0x0000ffff
        dd 0x00cf9a00
        ; 32-bit data segment, Limit=0xfffff, Base=0, Type=Data+RW, S=1, DPL=0, P=1, L=0, B=1, G=1
        dd 0x0000ffff
        dd 0x00cf9200
        ; 16-bit code segment, Limit=0xffff, Base=0, Type=Code+R, S=1, DPL=0, P=1, L=0, D=1, G=0
        dd 0x0000ffff
        dd 0x00409a00
        ; 16-bit data segment, Limit=0xffff, Base=0, Type=Data+RW, S=1, DPL=0, P=1, L=0, B=1, G=0
        dd 0x0000ffff
        dd 0x00409200
.end:


        section .text

        ; Intel documents the process for switching between modes.[1]  In
        ; particular:
        ;  - When switching to protected mode, the "mov cr0, eax" instruction
        ;    must be immediately followed by the far jump to the 32-bit
        ;    segment.
        ;  - The code to switch to real mode must all be contained inside one
        ;    page.
        ;
        ; [1] "9.9.2 Switching Back to Real-Address Mode".  Volume 3A.
        ; Intel(R) 64 and IA-32 Architectures Software Developer's Manual.
        ; #325462.
        ;
        ; The approach taken here is to provide two routines -- the first
        ; switches to protected mode, resets the stack pointer, and jumps to
        ; the C entry point.  The other is a 32-bit C-callable routine that
        ; calls a function pointer in real mode.  (State is passed through
        ; global variables.)


global init_protected_mode
init_protected_mode:
        bits 16
        cli
        lgdt [gdt]
        mov eax, cr0
        xor al, 1
        mov cr0, eax
        jmp 8:.step1
.step1:
        bits 32
        mov ax, 16
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
        mov esp, _stack_end
        call main
        cli
        hlt
.loop:
        jmp .loop


        ;
        ; C prototype: void call_real_mode(void(*func)(void))
        ;
        ; Switch to real mode, call func, switch back to protected mode, and
        ; return.
        ;
        align 256
global call_real_mode
call_real_mode:
        bits 32
        push ebp
        mov ebp, esp
        sub esp, 12

        ; Save non-volatile registers; func typically will call a BIOS routine,
        ; which might(?) modify them.
        mov [ebp-4], ebx
        mov [ebp-8], esi
        mov [ebp-12], edi

        mov ecx, [ebp+8]        ; func argument

        ; Adjust the stack pointer to be valid in real mode.
        sub esp, _stack

        ; Switch to real-mode.
        jmp 24:.step2
.step2:
        mov ax, 32
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax
        mov eax, cr0
        xor al, 1
        mov cr0, eax
        jmp 0:.step3
.step3:
        bits 16
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ax, _stack_segment
        mov ss, ax
        sti

        ; Call the real-mode function.
        push ebp
        call cx
        pop ebp

        ; Switch to protected mode.
        cli
        lgdt [gdt]
        mov eax, cr0
        xor al, 1
        mov cr0, eax
        jmp 8:.step1
.step1:
        bits 32
        mov ax, 16
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov ss, ax

        ; Restore saved registers.  (Avoid use of esp -- it isn't valid here.)
        mov ebx, [ebp-4]
        mov esi, [ebp-8]
        mov edi, [ebp-12]

        leave
        ret


global m16_putc
m16_putc:
        ; Print a message.
        mov ah, 0x0e
        mov al, 'X'
        int 0x10
        ret
