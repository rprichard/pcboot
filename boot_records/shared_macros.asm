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
        ; Trashes: CL, flags
        ;
        ; GRUB and GRUB2 use DL, but with some kind of adjustment.  Follow the
        ; GRUB2 convention and use DL if it's in the range 0x80-0x8f.
        ; Otherwise, fall back to 0x80.
        ;
%macro init_disk_number 0
        mov cl, 0xf0
        and cl, dl
        cmp cl, 0x80
        jne short .dl_is_implausible
        mov [bp + disk_number], dl
.dl_is_implausible:
%endmacro


        ; Output an assembler error if the two operands are unequal.
%macro static_assert_eq 2
        times -!!((%1) - (%2)) db 0
%endmacro
