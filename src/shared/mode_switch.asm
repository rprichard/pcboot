extern _pcboot_main
extern _stack
extern _stack_end
extern _tls
extern _tls_size


        ;
        ; Define the GDT for protected mode.  There are five segments:
        ;  - Code and data segments exposing the entire 4GB address space.
        ;  - A small "TLS" segment loaded into the gs register and used to
        ;    implement stack overflow checking.
        ;  - Code and data segments with a 16-bit limit, used to transition
        ;    back to real mode.
        ;

        section .data16
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


        section .text16

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
label_aligned_to_256:

        ;
        ; This function must pass through the EDX and ESI registers to the next
        ; startup function.
        ;
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
        ; Switch to real mode, call "callee", switch back to protected mode,
        ; and return.
        ;
        ; C prototype:
        ;
        ;     [[u32 or u64]]
        ;     call_real_mode(void (*callee)(), ...);
        ;
        ; The callee is invoked with BP pointing to the first callee argument
        ; (i.e. the second argument to call_real_mode).  EAX/EDX are zero on
        ; entry, and their value is returned to call_real_mode's caller.  The
        ; callee is not required to preserve any of the eight GPRs except ESP.
        ; The callee may also trash any segment register.
        ;
        ; The "callee" function and the .stack section must be located within
        ; the first 64 KiB of memory.  The SS register is initialized to 0 in
        ; 16-bit mode.
        ;

global call_real_mode
call_real_mode:
        bits 32
        sub esp, 16

        ; The callee function does not have to preserve these registers.
        mov [esp], ebx
        mov [esp+4], esi
        mov [esp+8], edi
        mov [esp+12], ebp

        ; Clear the return value registers.  It is easier for the 16-bit callee
        ; to not worry about the high 16-bits of these registers.
        xor eax, eax
        xor edx, edx

        ; Switch to real-mode.
        jmp (gdt.code16 - gdt):.step1
.step1:
        bits 16
        mov si, (gdt.data16 - gdt)
        mov ss, si
        mov ds, si
        mov es, si
        mov fs, si
        mov gs, si
        mov esi, cr0
        xor si, 1
        mov cr0, esi
        jmp 0:.step2
.step2:
        xor si, si
        mov ss, si
        mov ds, si
        mov es, si
        mov fs, si
        mov gs, si
        sti

        ; Call the real-mode function.
        mov bp, sp
        add bp, 24
        call [bp - 4]

        ; Switch to protected mode.
        cli
        xor si, si
        mov ds, si
        lgdt [gdt]
        mov esi, cr0
        xor si, 1
        mov cr0, esi
        jmp (gdt.code32 - gdt):.step3
.step3:
        bits 32
        mov si, (gdt.data32 - gdt)
        mov ss, si
        mov ds, si
        mov es, si
        mov fs, si
        mov si, (gdt.gsreg - gdt)
        mov gs, si

        ; Restore saved registers.
        mov ebx, [esp]
        mov esi, [esp+4]
        mov edi, [esp+8]
        mov ebp, [esp+12]

        ; The real-mode function is not required to leave the direction flag
        ; cleared, and I do not know whether Rust/LLVM assume anything about
        ; this flag.
        cld

        add sp, 16
        ret

        ; Statically guarantee that all of the code in this file fits in a
        ; single page, by padding the 256-byte aligned label to an amount no
        ; greater than 256.
        times (200 - ($ - label_aligned_to_256)) db 0
