        bits 16

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

        ; According to the Intel documentation[1], all of the instructions for
        ; switching from protected to real mode must be in a single page.
        ; Ensure this by aligning the start of the code to a power-of-two large
        ; enough to contain the code.
        ;
        ; [1] "9.9.2 Switching Back to Real-Address Mode".  Volume 3A.
        ; Intel(R) 64 and IA-32 Architectures Software Developer's Manual.
        ; #325462.

        align 256

global mode_switch_test
mode_switch_test:

        ; Switch into protected mode.
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

        ; Switch into real mode.
        jmp 24:.step2
.step2:
        mov ax, 32
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        mov eax, cr0
        xor al, 1
        mov cr0, eax
        jmp 0:.step3

        bits 16
.step3:
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax
        sti

        ; Print a message!
        mov ah, 0x0e
        mov al, 'A'
        int 0x10

        cli
        hlt
