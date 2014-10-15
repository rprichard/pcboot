extern call_real_mode

;
; Lowlevel routines
;

        section .text


        ;
        ; halt_32bit
        ; halt_32bit_cli
        ;
        ; Halts the CPU.  halt_32bit attempts to return the CPU to real mode,
        ; so interrupts continue working while the system is frozen.  Use
        ; halt_32bit_cli when the state of the system is unpredictable (i.e.
        ; memory may be corrupted).
        ;

        global halt_32bit
        global halt_32bit_cli
        bits 32
halt_32bit:
        push halt_16bit
        call call_real_mode
halt_32bit_cli:
.loop:
        hlt
        jmp .loop


        ;
        ; halt_16bit.  Halts the CPU without affecting the interrupt state.
        ;

        global halt_16bit
        bits 16
halt_16bit:
.loop:
        hlt
        jmp .loop
