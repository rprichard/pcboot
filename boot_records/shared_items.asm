; Routines shared by the pcboot MBR and VBR boot records.
;
; REQUIREMENTS:
;
;  - byte [bp + disk_number] must be the BIOS boot disk number.
;
;  - sector_buffer must be an integral assembler constant referring to a 512
;    byte buffer to read sectors into.
;



error_bias:                     equ 16
disk_read_error:                equ error_bias + 0
duplicate_vbr_error:            equ error_bias + 1
missing_vbr_error:              equ error_bias + 2

dap_size:                       equ 16




        ; Reads a sector to the 512-byte buffer at the "sector_buffer" address
        ; constant.  Tries to do an LBA write first, but if extensions aren't
        ; supported, the routine falls back to a CHS write.
        ;
        ; If a write fails, the routine aborts.
        ;
        ; If the LBA is out-of-bounds for a CHS access, the routine returns
        ; after filling the sector buffer with zeros.
        ;
        ; No checking is done to verify that the LBA or cylinder number is too
        ; large for the disk.
        ;
        ; Inputs: esi: the LBA of the sector to read.
        ; Trashes: none
read_sector:
        pushad

        ; Clear the sector buffer.  If the machine lacks INT13 extensions, and
        ; our sector isn't addressable using CHS, then instead of aborting, we
        ; "succeed" and pretend the sector was empty.  We don't want to abort
        ; on an unreachable partition when the pcboot VBR *is* CHS-addressable.
        mov di, sector_buffer
        xor al, al
        mov cx, 512
        cld
        rep stosb

        ; Check for INT13 extensions.  According to RBIL, INT13/41h modifies
        ; AX, BX, CX, DH, and the CF flag.  According to a GRUB2 comment, it
        ; also trashes DL on some BIOS versions, such as "AST BIOS 1.04".
        mov ah, 0x41
        mov bx, 0x55aa
        mov dl, [bp + disk_number]
        int 0x13
        jc .chs_fallback
        cmp bx, 0xaa55
        jne .chs_fallback

        ; Issue the read using INT13/42h.  Push a 16 byte DAP (disk access
        ; packet) onto the stack and pass it to BIOS.
        push ds                         ; Reserved (0)
        push ds                         ; High 16 bits of sector index (0)
        push esi                        ; Low 32 bits of sector index
        push ds                         ; Read buffer: segment 0
        push word sector_buffer         ; Read buffer: address
        push word 1                     ; Number of sectors to read: 1
        push word dap_size              ; DAP size -- and push error code
        static_assert_eq disk_read_error, dap_size
        mov ah, 0x42
        mov dl, [bp + disk_number]
        mov si, sp
        int 0x13
        jc fail                         ; Error code overlaps with DAP size
        add sp, 16
        jmp .done

.chs_fallback:
        push word disk_read_error       ; Push error code.

        ; Get CHS geometry.  According to RBIL, INT13/08h modifies AX, BL, CX,
        ; DX, DI, and the CF flag.
        mov ah, 8
        mov dl, [bp + disk_number]
        xor di, di
        int 0x13
        jc fail
        test ah, ah
        jnz fail

        ; INT13/08h returns the geometry in these variables:
        ;  - CH == Cm & 0xFF
        ;  - CL == (Sm & 0x3f) | ((Cm & 0x300) >> 2)
        ;  - DH == Hm
        ; [CSH]m are maximum indices.
        ;  - Sector indices start at one, so Sm is also the Sc (sectors/track).
        ;  - Head indices start at zero, so Hc (tracks/cylinder) is Hm + 1.
        ;  - Cylinder indices start at zero, so Cc (count of cylinders) is
        ;    Cm + 1.

        push dx

        ; esi == LBA == (((Ci * Hc) + Hi) * Sc) + (Si - 1)

        ; Divide LBA by Sc.
        xor edx, edx
        mov eax, esi
        and ecx, 0x3f
        div ecx

        ; eax == (Ci * Hc) + Hi
        ; edx == Si - 1

        pop cx          ; post-invariant: cx == int13 dx
        movzx ecx, ch   ; post-invariant: ecx == Hm
        inc cx          ; post-invariant: ecx == Hc

        inc dx
        push dx         ; Push Si.

        ; Divide eax by Hc.
        xor edx, edx
        div ecx

        ; dx == Hi
        ; eax == Ci

        ; [*] intermediate value
        pop cx                          ; [*] Set CL to Si.

        ; Ci can exceed 0xffff, so we must use a 32-bit compare.  If the
        ; sector is beyond the maximum cylinder, skip the write (and return a
        ; buffer of all zeros.)
        cmp eax, 1023
        ja .done

        ; ax == Ci

        ; [*] intermediate value
        mov ch, al                      ;     Set CH to (Ci & 0xff).
        shl ah, 6                       ; [*] Set AH to (Ci & 0x300) >> 2.
        or cl, ah                       ;     Set CL to Si | ((Ci & 0x300) >> 2).
        mov dh, dl                      ;     Set DH to Hi.
        mov dl, [bp + disk_number]
        mov bx, sector_buffer
        mov ax, 0x0201
        int 0x13
        jc fail

        pop ax                          ; Pop error code.
.done:
        popad
        ret




        ; Scan a possible extended partition looking for logical pcboot VBRs.
        ;
        ; Inputs: bx points to a partition entry that might be an EBR.
        ;         bx may point into sector_buffer.
        ;
        ; Trashes: esi(high), ecx(high), edx(high), sector_buffer
        ;
scan_extended_partition:
        pusha
        mov ecx, [bx + 8] ; ecx == start of entire extended partition
        mov edx, ecx      ; edx == start of current EBR

.loop:
        ; At this point:
        ;  - bx points at an entry that might be an EBR.  It's either any entry
        ;    in the MBR or the second entry of an EBR.
        ;  - edx is the LBA of the referenced partition.

        ; Check the partition type.  Allowed types: 0x05, 0x0f, 0x85.
        mov al, [bx + 4]
        cmp al, 0x0f
        je .match
        and al, 0x7f
        cmp al, 0x05
        jne .done

.match:
        ; bx points at an entry for a presumed EBR, whose LBA is in edx.  Read
        ; the EBR from disk.
        mov esi, edx
        call read_sector

        ; Verify that the EBR has the appropriate signature.
        cmp word [sector_buffer + 512 - 2], 0xaa55
        jne .done

        ; Check the first partition for a pcboot VBR.
        mov bx, sector_buffer + 512 - 2 - 64
        call scan_pcboot_vbr_partition

        ; Advance to the next EBR.  We must reread the EBR because it was
        ; trashed while scanning for a VBR.
        mov esi, edx
        call read_sector
        mov bx, sector_buffer + 512 - 2 - 64 + 16
        mov edx, ecx
        add edx, [bx + 8]
        jmp .loop

.done:
        popa
        ret




        ; Print an error and hang.  pcboot_error should be in reverse order.
fail:
        mov si, pcboot_error_end
        pop ax
        add byte [si + pcboot_error - pcboot_error_end + 1], al
.loop:
        dec si
        mov al, [si]
        test al, al
        jz .done
        mov ah, 0x0e
        mov bx, 7
        int 0x10
        jmp .loop
.done:
        hlt
        jmp .done
