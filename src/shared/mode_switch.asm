extern _pcboot_main
extern _stack
extern _stack_end
extern _tls
extern _tls_size


        ;
        ; Define the GDT for protected mode.  There are four segments:
        ;  - Code and data segments exposing the entire 4GB address space.
        ;  - Code and data segments with a 16-bit limit, used to transition
        ;    back to real mode.
        ;

        section .data
        align 8
gdt:
        ; LGDT operand
        dw .end-gdt
        dd gdt
        dw 0
.code32:
        ; 32-bit code segment, Limit=0xfffff, Base=0, Type=Code+R, S=1, DPL=0, P=1, L=0, D=1, G=1
        dd 0x0000ffff
        dd 0x00cf9a00
.data32:
        ; 32-bit data segment, Limit=0xfffff, Base=0, Type=Data+RW, S=1, DPL=0, P=1, L=0, B=1, G=1
        dd 0x0000ffff
        dd 0x00cf9200
.gsreg:
        ; 32-bit data segment, Limit=0x7f, Base=<reloc>, Type=Data+RW, S=1, DPL=0, P=1, L=0, B=1, G=0
        dw _tls_size
        dw _tls
        dd 0x00409200
.code16:
        ; 16-bit code segment, Limit=0xffff, Base=0, Type=Code+R, S=1, DPL=0, P=1, L=0, D=0, G=0
        dd 0x0000ffff
        dd 0x00009a00
.data16:
        ; 16-bit data segment, Limit=0xffff, Base=0, Type=Data+RW, S=1, DPL=0, P=1, L=0, B=0, G=0
        dd 0x0000ffff
        dd 0x00009200
.end:


        section .text

        ; Intel documents the process for switching between modes.[1]  In
        ; particular:
        ;  - When switching to protected mode, the "mov cr0, eax" instruction
        ;    must be immediately followed by the far jump to the 32-bit
        ;    segment.
        ;  - The code to switch to real mode must all be contained inside one
        ;    page.[2]
        ;
        ; [1] "9.9.2 Switching Back to Real-Address Mode".  Volume 3A.
        ; Intel(R) 64 and IA-32 Architectures Software Developer's Manual.
        ; #325462.
        ;
        ; [2] "All the code that is executed in steps 1 through 9 must be in a
        ; single page and the linear addresses in that page must be identity
        ; mapped to physical addresses."
        ;
        ; The approach taken here is to provide two routines -- the first
        ; switches to protected mode, resets the stack pointer, and jumps to
        ; the C entry point.  The other is a 32-bit C-callable routine that
        ; calls a function pointer in real mode.  (State is passed through
        ; global variables.)


        ; Kludge: force the entire mode switching mode to live in a single 4KiB
        ; page by aligning the start of the code to 256 bytes.  It works
        ; because the code is smaller than 256 bytes.
        align 256

global init_protected_mode
init_protected_mode:
        bits 16
        cli
        lgdt [gdt]
        mov eax, cr0
        xor al, 1
        mov cr0, eax
        jmp (gdt.code32 - gdt):.step1
.step1:
        bits 32
        mov ax, (gdt.data32 - gdt)
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov ss, ax
        mov esp, _stack_end
        mov ax, (gdt.gsreg - gdt)
        mov gs, ax
        jmp _pcboot_main


        ;
        ; C prototype: void call_real_mode(void(*func)(void))
        ;
        ; Switch to real mode, call func, switch back to protected mode, and
        ; return.
        ;
        ; The .stack section must be located within the first 64 KiB of memory.
        ; The SS register is initialized to 0 in 16-bit mode.
        ;
        ; TODO: I think flags from the real-mode call are preserved.  This is
        ; an important detail, so it should be documented one way or another.
        ;

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

        ; Switch to real-mode.
        jmp (gdt.code16 - gdt):.step2
.step2:
        bits 16
        mov ax, (gdt.data16 - gdt)
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
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
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
        jmp (gdt.code32 - gdt):.step1
.step1:
        bits 32
        mov ax, (gdt.data32 - gdt)
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov ss, ax
        mov ax, (gdt.gsreg - gdt)
        mov gs, ax

        ; Restore saved registers.  (Avoid use of esp -- it isn't valid here.)
        mov ebx, [ebp-4]
        mov esi, [ebp-8]
        mov edi, [ebp-12]

        leave
        ret
