extern call_real_mode

        section .text
        bits 16


        global print_char_16bit
print_char_16bit:
        mov ah, 0x0e
        mov al, [bp]
        mov bx, 7
        int 0x10
        ret


        ;
        ; Arguments:
        ; [bp+0] disk: u8
        ;
        ; Return: 1 if supported, 0 is not
        ;
        global check_for_int13_extensions
check_for_int13_extensions:
        mov ah, 0x41
        mov bx, 0x55aa
        mov dl, [bp + 0]
        int 0x13
        jc .not_supported
        cmp bx, 0xaa55
        jne .not_supported
        mov eax, 1
        ret
.not_supported:
        xor eax, eax
        ret


        ;
        ; Arguments:
        ; [bp+0] disk: u8
        ; [bp+4] geometry: &mut io::Chs
        ;
        ;    struct Chs {
        ;        cylinder: u16,
        ;        head: u16,
        ;        sector: u8,
        ;    }
        ;
        ; Return: 1 on success, 0 on failure
        ;
        global get_disk_geometry
get_disk_geometry:

        ; Get CHS geometry.  According to RBIL, INT13/08h modifies AX, BL, CX,
        ; DX, DI, and the CF flag.
        mov ah, 8
        mov dl, [bp + 0]
        xor di, di
        int 0x13
        jc .fail
        test ah, ah
        jnz .fail

        ; INT13/08h returns the geometry in these variables:
        ;  - CH == Cm & 0xFF
        ;  - CL == (Sm & 0x3f) | ((Cm & 0x300) >> 2)
        ;  - DH == Hm
        ; [CSH]m are maximum indices.
        ;  - Sector indices start at one, so Sm is also the Sc (sectors/track).
        ;  - Head indices start at zero, so Hc (tracks/cylinder) is Hm + 1.
        ;  - Cylinder indices start at zero, so Cc (count of cylinders) is
        ;    Cm + 1.

        mov di, [bp + 4]

        ; Write geometry.cylinder
        mov al, ch
        mov ah, cl
        shr ah, 6
        mov word [di + 0], ax

        ; Write geometry.head
        movzx ax, dh
        inc ax
        mov word [di + 2], ax

        ; Write geometry.sector
        mov al, cl
        and al, 0x3f
        mov byte [di + 4], al

        mov eax, 1
        ret

.fail:
        xor eax, eax
        ret


        ;
        ; Arguments:
        ; [bp+0] disk: u8
        ; [bp+4] dap: &io::DiskAccessPacket
        ;
        ; Return: 1 on success, 0 on failure
        ;
        global read_disk_lba
read_disk_lba:
        mov ah, 0x42
        mov dl, [bp + 0]
        mov si, [bp + 4]
        int 0x13
        jc .fail
        mov eax, 1
        ret
.fail:
        xor eax, eax
        ret


        ;
        ; Arguments:
        ; [bp+0] disk: u8
        ; [bp+4] sector: &io::Chs
        ; [bp+8] buffer: &mut io::SectorBuffer
        ;
        ;    struct Chs {
        ;        cylinder: u16,
        ;        head: u16,
        ;        sector: u8,
        ;    }
        ;
        ; Return: 1 on success, 0 on failure
        ;
        global read_disk_chs
read_disk_chs:
        mov si, [bp + 4]
        mov ax, 0x0201
        mov ch, byte [si + 0]   ; cylinder's low 8 bits
        mov cl, byte [si + 1]   ; cylinder's high 2 bits
        shl cl, 6               ; shift cylinder high bits
        or cl, byte [si + 4]    ; sector (0 - 62)
        inc cl                  ; make sector one-based (1 - 63)
        mov dh, byte [si + 2]   ; head
        mov dl, [bp + 0]        ; disk
        mov bx, [bp + 8]        ; buffer
        int 0x13
        jc .fail
        mov eax, 1
        ret
.fail:
        xor eax, eax
        ret


        section .bss
print_char_data:
        resb 1
