        ; CRC-32C polynomial (0x1edc6f41) reversed bit-by-bit.
polynomial:     equ 0x82f63b78




        ;
        ; Compute a CRC-32C checksum.
        ;
        ; The CRC-32C checksum is used by iSCSI among other places.  Its
        ; algorithm is the same as CRC-32 (used by PKZIP), but its polynomial
        ; has better error detection properties.
        ;
        ; Inputs: si: pointer to a buffer to checksum
        ;         cx: the buffer size in bytes
        ;
        ; Outputs: eax: the CRC-32C checksum
        ;
        ; Trashes: ebx, ecx, esi
        ;

        global crc32c
crc32c:
        ;
        ; Initialize the 1KiB table.
        ;
        pusha
        mov di, crc32c_table
        xor ecx, ecx
.loop_per_table_entry:
        mov esi, ecx
        mov ax, 8
.loop_per_iteration:
        shr esi, 1
        jnc .skip_polynomial_xor
        xor esi, polynomial
.skip_polynomial_xor:
        dec ax
        jnz .loop_per_iteration
        mov [di], esi
        add di, 4
        inc cl
        jnz .loop_per_table_entry
        popa

        ;
        ; Use the table to compute the checksum.
        ;
        mov eax, 0xffffffff
.loop:
        xor bx, bx
        mov bl, byte [si]
        xor bl, al
        shl bx, 2
        add bx, crc32c_table
        mov ebx, dword [bx]
        shr eax, 8
        xor eax, ebx
        inc si
        dec ecx
        jnz .loop
        not eax
        ret
