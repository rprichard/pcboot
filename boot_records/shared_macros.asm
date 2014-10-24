; REQUIREMENTS:
;
;  - byte [bp + disk_number] must be the BIOS boot disk number, statically
;    initialized to 0x80.
;


        ;
        ; Update [bp + disk_number] with the BIOS DL value if appropriate.
        ;
        ; [bp + disk_number] should be statically initialized to 0x80.  If DL
        ; is inappropriate, the static value is left unchanged.  DL is not set
        ; to 0x80.
        ;
        ; Input: DL is the value provided by the previous boot stage (i.e. BIOS
        ;            or MBR)
        ; Trashes: flags
        ;
        ; GRUB and GRUB2 use DL, but with some kind of adjustment.  Follow the
        ; GRUB2 convention and use DL if it's in the range 0x80-0x8f.
        ; Otherwise, fall back to 0x80.
        ;
%macro init_disk_number 0
        cmp dl, 0x8f                    ; Use a signed 8-bit comparison.
        jg short .dl_is_implausible     ; 0x80 is INT8_MIN.
        mov [bp + disk_number], dl
.dl_is_implausible:
%endmacro


        ; Output an assembler error if the two operands are unequal.
%macro static_assert_eq 2
        times -!!((%1) - (%2)) db 0
%endmacro


        ; Assert that the first operand is <= the second.  (Specifically, it
        ; asserts that the signed 32-bit value (op2 - op1) is non-negative.)
%macro static_assert_i32_le 2
        static_assert_eq (((%2) - (%1)) & 0x8000_0000), 0
%endmacro


        ; Assert that the first operand is < the second.  (Specifically, it
        ; asserts that the signed 32-bit value (op2 - op1) is positive.)
%macro static_assert_i32_lt 2
        static_assert_eq (((%2) - 1 - (%1)) & 0x8000_0000), 0
%endmacro


        ; Given a base address and a target address, assert that the target can
        ; be reached using a signed 8-bit offset from the base.
%macro static_assert_in_i8_range 2
        static_assert_i32_le ((%2) - (%1)), 127
        static_assert_i32_le ((%1) - (%2)), 128
%endmacro
