; pcboot MBR.
;
; Searches the boot disk for the pcboot boot volume and launches it via the
; conventional MBR-VBR interface.  Specifically, it searches the disk indicated
; by the initial DL value for the partition with the pcboot marker and the
; lowest pcboot timestamp value, breaking ties to the lower partition indices.
;
; TODO:
;  - Improved error checking, such as:
;     - Look for a valid FAT32 partition type.
;     - Protecting against infinite loops in the logical partition scanning.
;     - Verify that the second partition in an EBR has the right partition
;       type.
;     - Call the BIOS routine to check for INT13 extensions
;  - Reduce code size.  This is necessary before adding more error checks and a
;    good idea in any case to allow for future expansion/tweaking.
;  - Improve the MBR-VBR interface.  Review the Wikipedia MBR page for details.
;     - Consider passing through DH and DS:DI for some kind of "PnP" data.
;     - Zero other registers to avoid leaking implementation details.  This
;       wastes code size, though.
;     - Review whether the MBR should use drive 0x80 or DL.


        bits 16

        extern _bss
        extern _bss_size
        extern _stack_end
        extern _mbr
        extern _mbr_unrelocated
        extern _vbr

; Reuse the VBR chain address, 0x7c00, as the buffer
sector_buffer:                  equ _vbr

; Address constants
vbr_timestamp_offset:           equ 0x1e6       ; 8 bytes
vbr_marker_offset:              equ 0x1ee       ; 16 bytes
vbr_marker_size:                equ 16




;
; Executable code
;

        section .mbr

        global main
main:
        ; Setup the environment and relocate the code.  Be careful not to
        ; trash DL, which still contains the BIOS boot disk number.
        cli
        xor ax, ax
        mov ss, ax
        mov ds, ax
        mov es, ax
        mov sp, _stack_end
        mov di, _bss
        mov cx, _bss_size
        rep stosb
        mov si, _mbr_unrelocated
        mov di, _mbr
        mov cx, 512
        rep movsb
        jmp 0:.relocated
.relocated:
        sti
        ; Save the disk number.
        mov [disk_number], dl
        ; Scan for the VBR.
        call scan_partitions
        mov eax, [vol_candidate_lba]
        test eax, eax
        jz .error_no_pcboot_volume
        ; Launch stage2.
        mov si, msg_transfer
        call print_string
        mov eax, [vol_candidate_lba]
        call read_sector
        mov dl, [disk_number]
        jmp 0:_vbr
.error_no_pcboot_volume:
        mov si, error_no_volume
        call print_string
        cli
        hlt




        ; Scan all the primary and logical partitions on the disk looking for
        ; the best pcboot volume candidate.
scan_partitions:
        mov si, mbr_ptable
        lea di, [mbr_ptable+0x40]
.loop:
        call scan_mbr_partition
        add si, 0x10
        cmp si, di
        jne .loop
        ret




        ; Partition scanning: scan the MBR partition.
        ; Inputs: si: address of ptable entry.
scan_mbr_partition:
        cmp byte [si+4], 0x5
        je scan_extended
        cmp byte [si+4], 0xf
        je scan_extended
        jmp scan_partition




        ; Scan an extended partition.
        ; Inputs: si: address of the ptable entry pointing to the extended
        ; partition.
scan_extended:
        push si
        push ebx
        push ebp
        mov ebx, [si+8]         ; ebx: LBA of first EBR.
        test ebx, ebx
        jz .done
        mov ebp, ebx            ; ebp: LBA of current EBR in loop.
.loop:
        ; Look in entry 1 for a normal partition.
        mov eax, ebp
        call read_sector
        lea si, [sector_buffer + 446]
        mov [extended_lba], ebp
        call scan_partition
        ; Look in entry 2 for a linked EBR partition.
        ; Reload the parent EBR because the static buffer has been trashed.
        mov eax, ebp
        call read_sector
        mov ebp, [sector_buffer + 446 + 0x10 + 8]
        test ebp, ebp
        jz .done
        add ebp, ebx
        jmp .loop
.done:
        xor eax, eax
        mov [extended_lba], eax
        pop ebp
        pop ebx
        pop si
        ret




        ; Scan a single partition entry and update the best candidate global
        ; variables.  The entry might not contain a partition.
        ;
        ; Inputs: si: address of ptable entry.
scan_partition:
        push si
        push di
        push ebx
        mov ebx, [si+8]
        test ebx, ebx
        jz .done
        add ebx, [extended_lba]
        mov eax, ebx
        call read_sector
        mov si, pcboot_marker
        lea di, [sector_buffer + vbr_marker_offset]
        mov cx, vbr_marker_size
        repe cmpsb
        jne .done
        mov eax, [sector_buffer + vbr_timestamp_offset]
        mov edx, [sector_buffer + vbr_timestamp_offset + 4]
        cmp edx, [vol_candidate_timestamp + 4]
        ja .new_candidate
        jb .done
        cmp eax, [vol_candidate_timestamp]
        jbe .done
.new_candidate:
        mov [vol_candidate_lba], ebx
        mov [vol_candidate_timestamp], eax
        mov [vol_candidate_timestamp+4], edx
.done:
        pop ebx
        pop di
        pop si
        ret




        ; Inputs: eax: the LBA of the sector to read.
read_sector:
        push si
        mov [int13_dap.sect], eax
        mov ah, 0x42
        mov dl, [disk_number]
        mov si, int13_dap
        int 0x13
        jc .error
        pop si
        ret
.error:
        mov si, error_read
        call print_string
        cli
        hlt




        ; Print a NUL-terminated string.
        ; Inputs: si: the address of the string to print.
        ; I think this code can be made smaller. (OPTSIZE)
print_string:
        pusha
.loop:
        mov al, [si]
        test al, al
        jz .done
        mov ah, 0x0e
        mov bx, 7
        int 0x10
        inc si
        jmp .loop
.done:
        popa
        ret




;
; Initialized data
;

error_no_volume:
        db "pcboot-MBR: cannot find VBR",0
error_read:
        db "pcboot-MBR: read error",0
msg_transfer:
        db "pcboot-MBR: chaining...",13,10,0

        align 16
pcboot_marker:
        db 0xbd,0x22,0x77,0x91,0x19,0xe3,0xaf,0x57
        db 0xab,0x45,0xb0,0xf9,0xa8,0xc7,0x1e,0x0d

        align 16
int13_dap:
        db 16                   ; size of DAP structure
        db 0                    ; reserved
        dw 1                    ; sector count
        dw sector_buffer        ; buffer offset
        dw 0                    ; buffer segment
.sect:  dq 0                    ; 64-bit sector LBA

        times 440-($-main) db 0
        dd 0            ; 32-bit disk signature
        dw 0            ; padding
mbr_ptable:
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dw 0xaa55




;
; Zeroed data
;

        section .bss

vol_candidate_lba:              resd 1
vol_candidate_timestamp:        resq 1
extended_lba:                   resd 1
disk_number:                    resb 1
