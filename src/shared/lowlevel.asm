extern call_real_mode

;
; Lowlevel routines
;

        section .text16


        ;
        ; halt_16bit.  Halts the CPU without affecting the interrupt state.
        ;

        global halt_16bit
        bits 16
halt_16bit:
.loop:
        hlt
        jmp .loop
