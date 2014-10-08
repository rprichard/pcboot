; pcboot MBR.
;
; Searches the boot disk for the pcboot boot volume and launches it via the
; conventional MBR-VBR interface.
;
; The MBR only searches the disk indicated by the DL value.  Other disks could
; conceivably be insecure (e.g. a USB flash drive).
;
; The VBR is identified by the string "PCBOOT" followed by 0xAA55 at the end of
; the VBR.  The MBR searches all partitions, and succeeds if only a single VBR
; is found.  If multiple VBRs match, the MBR aborts.
;
; To avoid a hypothetical(?) DOS vulnerability, the MBR only considers
; partitions whose type ID is one of the expected values for a FAT32 volume.
; (Suppose an attacker could control all of some partition's data.  It could
; create a partition that looked like the boot volume.)  If this risk could be
; ruled out somehow, it could reduce the amount of code here.
;
; TODO:
;  - Improved error checking, such as:
;     - Protecting against infinite loops in the logical partition scanning.
;     - Call the BIOS routine to check for INT13 extensions
;     - If we don't have INT13 extensions, we should avoid scanning partitions
;       past the CHS limit, maybe?
;  - Improve the MBR-VBR interface.  Review the Wikipedia MBR page for details.
;     - Consider passing through DH and DS:DI for some kind of "PnP" data.
;     - Consider whether interrupts should be on or off.
;     - Does the Direction Flag need to be cleared?
;


        bits 16


;
; The address 0x7c00 serves three purposes in this program:
;  - It is the program's initial address, where we must read to relocate to
;    0x600.
;  - It is the top of the stack.
;  - Sectors are read into 0x7c00.  When we chain to the VBR, we don't have to
;    move it to 0x7c00 before jumping.
;

sector_buffer:                  equ 0x7c00


;
; Global variables.
;
; For code size effiency, globals are accessed throughout the program using an
; offset from the BP register.  BP points to the aa55_signature (at MBR offset
; 510).  Negative offsets access statically initialized variables, and positive
; offsets access variables with undefined startup content.
;

disk_number:                    equ disk_number_storage - aa55_signature
no_match_yet:                   equ no_match_yet_storage - aa55_signature
extra_storage_offset:           equ 2
match_lba:                      equ extra_storage_offset + 0    ; dword


%include "shared_macros.s"


        section .boot_record

        global main
main:
        ;
        ; Setup the environment and relocate the code.  Be careful not to
        ; trash DL, which still contains the BIOS boot disk number.
        ;
        cli
        xor ax, ax
        mov ss, ax                      ; Clear SS
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
        mov sp, sector_buffer           ; Set SP to 0x7c00
        mov si, sp
        mov di, main
        mov cx, 512
        cld
        rep movsb                       ; Copy MBR from 0x7c00 to 0x600.
        jmp 0:.relocated                ; Set CS:IP to 0:0x600.

.relocated:
        sti

        ; Use BP to access global variables with smaller memory operands.  We
        ; also use BP as the end address for the primary partition table scan.
        mov bp, aa55_signature

        init_disk_number

        mov si, mbr_ptable
.primary_scan_loop:
        xor edx, edx
        call scan_pcboot_vbr_partition
        call scan_extended_partition
        add si, 0x10
        cmp si, bp
        jne .primary_scan_loop

        ; If we didn't find a match, fail at this point.
        cmp byte [bp + no_match_yet], 0
        jne fail

        ;
        ; Load the matching sector to 0x7c00 and jump.
        ;
        mov esi, [bp + match_lba]
        call read_sector
        xor si, si
        mov dl, [bp + disk_number]
        jmp sector_buffer




        ;
        ; Examine a single partition to see whether it is a matching pcboot
        ; VBR.  If it is one, update the global state (and potentially halt).
        ;
        ; Inputs: si points to a partition entry
        ;         edx is a value to add to the entry's LBA
        ;
        ; Trashes: esi(high), sector_buffer
        ;
scan_pcboot_vbr_partition:
        pusha
        ; Check the partition type.  Allowed types: 0x0b, 0x0c, 0x1b, 0x1c.
        mov al, [si + 4]
        and al, 0xef
        sub al, 0x0b
        cmp al, 1
        ja .done

        ; Look for the appropriate 8-byte signature at the end of the VBR.
        mov esi, [si + 8]
        add esi, edx
        call read_sector

        ; Test whether the sector we just read has the pcboot marker.  Set the
        ; ZF flag but otherwise leave registers alone.  (In particular, leave
        ; esi alone.)
        pusha
        mov si, sector_buffer + 512 - 8
        mov di, pcboot_vbr_marker
        mov cx, 8
        cld
        repe cmpsb
        popa

        jne .done

        ; We found a match!  Abort if this is the second match.
        dec byte [bp + no_match_yet]
        jnz fail
        mov [bp + match_lba], esi

.done:
        popa
        ret




%include "shared_items.s"




;
; Initialized data
;

pcboot_error:
        db "pcbootM err",0

pcboot_vbr_marker:
        db "PCBOOT"
        dw 0xaa55

mbr_code_end:

        times 438-($-main) db 0

disk_number_storage:    db 0x80
no_match_yet_storage:   db 0x01

disk_signature:
        dd 0            ; 32-bit disk signature
        dw 0            ; padding

mbr_ptable:
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0

aa55_signature:
        dw 0xaa55
