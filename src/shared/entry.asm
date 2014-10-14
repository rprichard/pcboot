extern _bss
extern _bss_size
extern init_protected_mode
extern pcboot_main


;
; 16-bit mode entry point
;
; Guarantees on entry:
;  - stage1: IP is 0x9000, the address at which the image is loaded.
;  - CS, DS, and ES registers are all zeroed.
;
; This file will be listed first on the linker command-line.
;


        section .text
        global _entry
_entry:
        bits 16
        jmp init_protected_mode


;
; Clear .bss section and jump to pcboot_main
;

        bits 32
        global _pcboot_main
_pcboot_main:
        xor eax, eax
        mov edi, _bss
        mov ecx, _bss_size
        cld
        rep stosb
        jmp pcboot_main
