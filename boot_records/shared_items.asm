; Routines shared by the pcboot MBR and VBR boot records.
;
; REQUIREMENTS:
;
;  - byte [bp + disk_number] must be the BIOS boot disk number.
;
;  - dword [bp + match_lba] must exist.  It does not need to be initialized.
;
;  - byte [bp + read_error_flag] must be initialized to zero at startup (or
;    statically).
;
;  - dword [bp + read_sector_lba] must exist.  It does not need to be
;    initialized.
;
;  - sector_buffer must be an integral assembler constant referring to a 512
;    byte buffer to read sectors into.
;
; BIOS register assumptions:
;
;  - Each int instruction has a comment documenting the general-purpose
;    registers required to be preserved (i.e. Live GPRs).
;
;  - BIOS calls are not relied upon to preserve the Direction Flag.
;
;  - Ralph Brown's Interrupt List (RBIL) tries to document which registers each
;    interrupt function changes.
;



;
; When an error is printed, the value here is added to the character on the end
; of the error string.  MBR errors start with '0', and VBR errors start with
; 'A'.  Disk read errors do not immediately abort the loader, but if/when a
; fatal error occurs (e.g. cannot find VBR), the error is incremented by one.
;
geometry_error:                 equ error_char + 0
duplicate_vbr_error:            equ error_char + 2
missing_vbr_error:              equ error_char + 4
missing_post_vbr_marker_error:  equ error_char + 6
read_error:                     equ error_char + 8

dap_size:                       equ 16

;
; The maximum number of logical partitions to examine.  This code only examines
; a finite number of partitions to guard against an infinite loop in a corrupt
; table.  The chosen number is mostly arbitrary.
;
maximum_logical_partitions:     equ 127




%macro define_fail_routine 0
        ;
        ; Print an error and hang.
        ;
        ; Bootloader code commonly assumes that INT 10h/0Eh will not trash SI,
        ; so that assumption is safe.  For example, FreeBSD's boot0.S and GRUB2
        ; make this assumption.
        ;
        ; Inputs: the top of the stack has an error code
        ;         (NOT a return address, i.e. "call fail" is incorrect)
        ;
fail:
        mov si, pcboot_error
        pop ax
        add al, [bp + read_error_flag]
        mov byte [si + pcboot_error_char - pcboot_error], al
.loop:
        cld
        lodsb
        test al, al
        jz short .done
        mov ah, 0x0e
        mov bx, 7
        int 0x10                        ; Live GPRs: SI
        jmp short .loop
.done:
        hlt
        jmp short .done
%endmacro




        ;
        ; Examine a single partition to see whether it is a matching pcboot
        ; VBR.  If it is one, update the global state (and potentially halt).
        ;
        ; Inputs: bx points to a partition entry
        ;         esi is a value to add to the entry's LBA
        ;
        ; Trashes: sector_buffer
        ;
scan_pcboot_vbr_partition:
        pushad
        ; Check the partition type.  Allowed types: 0x0b, 0x0c, 0x1b, 0x1c.
        mov al, [bx + 4]
        sub al, 0x0b            ; (Now looking for: 0x00, 0x01, 0x10, 0x11.)
        and al, 0xee
        jnz short .done

        ; Look for the pcboot marker at the end of the VBR.
        add esi, [bx + 8]
        call read_sector

        ; Test whether the sector we just read has the pcboot marker.  Set the
        ; ZF flag but otherwise leave registers alone.  (In particular, leave
        ; esi alone.)
        pusha
        mov si, sector_buffer + 512 - pcboot_vbr_marker_size
        mov di, pcboot_vbr_marker
        mov cx, pcboot_vbr_marker_size
        cld
        repe cmpsb
        popa

        jne short .done

        ; We found a match!  Abort if this is the second match.
        dec byte [bp + no_match_yet]
        push word duplicate_vbr_error   ; Push error code.
        jnz short fail
        pop ax                          ; Pop error code.
        mov [bp + match_lba], esi

.done:
        popad
        ret




        ;
        ; Reads a sector to the 512-byte buffer at the "sector_buffer" address
        ; constant.  Tries to do an LBA read first, but if extensions aren't
        ; supported, the routine falls back to a CHS read.
        ;
        ; If we attempt to do a CHS read, but the LBA is too large, then the
        ; routine returns a sector buffer that does not end in 0xaa55, and the
        ; CF flag is set.
        ;
        ; If the INT13 read call fails, the routine again returns a sector
        ; buffer that does not end in 0xaa55 and sets the CF flag.  It also
        ; sets [bp + read_error_flag], which later affects the error code if
        ; the boot ultimately fails.
        ;
        ; If the read succeeds, the CF flag is clear on return.
        ;
        ; No checking is done to verify that the LBA or the cylinder number is
        ; within the disk's capacity.
        ;
        ; Inputs: esi: the LBA of the sector to read.
        ; Outputs: CF is set on error and clear on success.
        ;          sector_buffer is filled.  Its last two bytes are zero on
        ;              failure.
        ; Trashes: none
        ;
read_sector:
        pushad

        ;
        ; When we read a VBR candidate, the post-VBR sector, or an EBR, we only
        ; accept the sector if it ends with a 0xaa55 marker.  By ensuring that
        ; the marker is cleared on a failed read, we can omit a CF test at
        ; those read_sector call sites.
        ;
        mov [sector_buffer + 512 - 2], ds

        ; Save the input LBA to the read_sector_lba global.  If we trusted BIOS
        ; INT13H/41H and INT13H/08H to preserve ESI, then we could save a few
        ; bytes of code here.
        mov dword [bp + read_sector_lba], esi

        ; Check for INT13 extensions.  According to RBIL, INT13/41h modifies
        ; AX, BX, CX, DH, and the CF flag.  According to a GRUB2 comment, it
        ; also trashes DL on some BIOS versions, such as "AST BIOS 1.04".
        mov ah, 0x41
        mov bx, 0x55aa
        mov dl, [bp + disk_number]
        int 0x13                        ; Live GPRs: BP, SP
        jc short read_sector_chs_fallback
        cmp bx, 0xaa55
        jne short read_sector_chs_fallback

        ; Issue the read using INT13/42h.  Push a 16 byte DAP (disk access
        ; packet) onto the stack and pass it to BIOS.
        push ds                         ; Reserved (0)
        push ds                         ; High 16 bits of sector index (0)
        push dword [bp + read_sector_lba] ; Low 32 bits of sector index
        push ds                         ; Read buffer: segment 0
        push word sector_buffer         ; Read buffer: address
        push word 1                     ; Number of sectors to read: 1
        push word dap_size              ; DAP size
        mov ah, 0x42
        mov dl, [bp + disk_number]
        mov si, sp
        int 0x13                        ; Live GPRs: BP, SP
        add sp, 16
        jmp short read_sector_chs_fallback.int13_read_finished


        ;
        ; The fail routine is located in the center of read_sector to optimize
        ; jump instruction sizes.
        ;
        define_fail_routine


        ;
        ; Second half of the read_sector function.
        ;
read_sector_chs_fallback:
        ; Get CHS geometry.  According to RBIL, INT13/08h modifies AX, BL, CX,
        ; DX, DI, and the CF flag.
        mov ah, 8
        mov dl, [bp + disk_number]
        xor di, di
        int 0x13                        ; Live GPRs: BP, SP
        push word geometry_error        ; Push error code.
        jc short fail
        test ah, ah
        jnz short fail
        pop di                          ; Pop error code.

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

        ; [bp + read_sector_lba] == LBA == (((Ci * Hc) + Hi) * Sc) + (Si - 1)

        ; Divide LBA by Sc.
        xor edx, edx
        mov eax, [bp + read_sector_lba]
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
        ; sector is beyond the maximum cylinder, skip the read and return
        ; failure.
        cmp eax, 1023
        ja short .read_call_failed

        ; ax == Ci

        ; [*] intermediate value
        mov ch, al                      ;     Set CH to (Ci & 0xff).
        shl ah, 6                       ; [*] Set AH to (Ci & 0x300) >> 2.
        or cl, ah                       ;     Set CL to Si | ((Ci & 0x300) >> 2).
        mov dh, dl                      ;     Set DH to Hi.
        mov dl, [bp + disk_number]
        mov bx, sector_buffer
        mov ax, 0x0201
        int 0x13                        ; Live GPRs: BP, SP
.int13_read_finished:
        jnc .return
.read_call_failed:
        ;
        ; Clear the end of the sector buffer and continue.  When we're scanning
        ; the partition table, we might experience errors because:
        ;
        ;  - the cylinder is greater than 1023 in CHS mode
        ;  - the partition table is corrupt
        ;
        ; In those cases, we might prefer to continue booting as long as the
        ; pcboot volume is accessible.  We want to record the disk error,
        ; though, so that if we aren't able to boot, we print a different error
        ; code.
        ;
        mov byte [bp + read_error_flag], 1

        ;
        ; Clear the high two bytes again to be sure.  In theory, this guards
        ; against INT13 returning error and somehow putting the right mark into
        ; the sector buffer.  I'm skeptical that this is necessary, but I don't
        ; know.
        ;
        mov [sector_buffer + 512 - 2], ds

        ;
        ; Set the carry flag.  This is necessary when the CHS-mode cylinder is
        ; too large.
        ;
        ; OPT-SIZE: This 1-byte "stc" instruction is arguably unnecessary in
        ; the VBR.  It is only needed to ensure that CF is set when the
        ; CHS-mode cylinder index is too large, which in the VBR, can only
        ; happen when reloading an EBR.  We already loaded the EBR once, so we
        ; know the cylinder is small enough, assuming INT13 returns consistent
        ; geometry over time.  It is complicated.  If this instruction were
        ; removed, the post-VBR sector would compensate by including its own
        ; copy of read_sector (and also checksumming stage1).
        ;
        stc
.return:
        popad
        ret




        ; Scan a possible extended partition looking for logical pcboot VBRs.
        ;
        ; Inputs: bx points to a partition entry that might be an EBR.
        ;         bx may point into sector_buffer.
        ;
        ; Trashes: esi(high), edx(high), sector_buffer
        ;
scan_extended_partition:
        pusha
        mov edx, [bx + 8] ; edx == start of entire extended partition
        mov esi, edx      ; esi == start of current EBR
        mov cx, maximum_logical_partitions

.loop:
        ; At this point:
        ;  - bx points at an entry that might be an EBR.  It's either any entry
        ;    in the MBR or the second entry of an EBR.
        ;  - esi is the LBA of the referenced partition.

        ; Check the partition type.  Allowed types: 0x05, 0x0f, 0x85.
        mov al, [bx + 4]
        cmp al, 0x0f
        je short .match
        and al, 0x7f
        cmp al, 0x05
        jne short .done

.match:
        ; bx points at an entry for a presumed EBR, whose LBA is in esi.  Read
        ; the EBR from disk.
        call read_sector

        ; Verify that the EBR has the appropriate signature.
        cmp word [sector_buffer + 512 - 2], 0xaa55
        jne short .done

        ; Check the first partition for a pcboot VBR.
        mov bx, sector_buffer + 512 - 2 - 64
        call scan_pcboot_vbr_partition

        ; Advance to the next EBR.  We must reread the EBR because it was
        ; trashed while scanning for a VBR.
        call read_sector
        jc short .done                  ; Guard against a flaky disk.
        mov bx, sector_buffer + 512 - 2 - 64 + 16
        mov esi, edx
        add esi, [bx + 8]
        loop .loop

.done:
        popa
        ret
