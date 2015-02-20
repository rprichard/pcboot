extern _bss
extern _bss_size
extern _stack_rust_limit
extern _tls_stack_limit
extern init_protected_mode
extern pcboot_main


;
; 16-bit mode entry point
;
; Guarantees on entry:
;  - stage1: IP is 0x9000, the address at which the image is loaded.
;  - stage2: IP is 0x5000, the address at which the image is loaded.
;  - DL is the BIOS disk number
;  - ESI is the LBA of the pcboot volume.
;  - CS, DS, and ES registers are all zeroed.
;
; This file will be listed first on the linker command-line.
;


        section .text16
        global _entry
_entry:
        bits 16
        jmp init_protected_mode


;
; Finish setting up memory and jump into Rust.
;

        bits 32
        global _pcboot_main
_pcboot_main:
        ; Clear .bss section
        xor eax, eax
        mov edi, _bss
        mov ecx, _bss_size
        cld
        rep stosb

        ; Rust-generated code checks for stack overflow by reading gs:0x30,
        ; which refers to the _tls_stack_limit variable.  Initialize the stack
        ; limit.
        mov eax, _stack_rust_limit
        mov [_tls_stack_limit], eax

        ; Jump into Rust.
        movzx edx, dl
        push esi
        push edx
        call pcboot_main
.loop:
        hlt
        jmp .loop
