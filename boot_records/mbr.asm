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

original_location:              equ 0x7c00
stack:                          equ original_location
sector_buffer:                  equ original_location


;
; Global variables.
;
; For code size effiency, globals are accessed throughout the program using an
; offset from the BP register.  BP points to the aa55_signature (at MBR offset
; 510).  Negative offsets access statically initialized variables, and positive
; offsets access variables with undefined startup content.
;

disk_number:            equ disk_number_storage         - bp_address
no_match_yet:           equ no_match_yet_storage        - bp_address
match_lba:              equ match_lba_storage           - bp_address
read_error_flag:        equ read_error_flag_storage     - bp_address
error_char:             equ '0'


%include "shared_macros.asm"


        section .boot_record

        global main
main:
        ;
        ; Setup the environment and relocate the code.
        ;
        ;  * Be careful not to trash DL, which still contains the BIOS boot
        ;    disk number.
        ;
        ;  * According to Intel docs (286, 386, and contemporary), moving into
        ;    SS masks interrupts until after the next instruction executes.
        ;    Hence, this code avoids clearing interrupts.  (Saves one byte.)
        ;
        xor ax, ax
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
        mov ss, ax                      ; Clear SS
        mov sp, stack                   ; Set SP to 0x7c00
        static_assert_eq stack, original_location
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
        mov bp, bp_address

        init_disk_number

        mov bx, mbr_ptable
.primary_scan_loop:
        xor esi, esi
        call scan_pcboot_vbr_partition
        call scan_extended_partition
        add bx, 0x10
        static_assert_eq bp_address, aa55_signature
        cmp bx, bp
        jne short .primary_scan_loop

        ; If we didn't find a match, fail at this point.
        cmp byte [bp + no_match_yet], 0
        push word missing_vbr_error     ; Push error code. (No return.)
        jne short fail

        ;
        ; Load the matching sector to 0x7c00 and jump.
        ;
        mov esi, [bp + match_lba]
        call read_sector
        push word read_error            ; Push error code. (No return.)
        jc short fail
        xor si, si
        mov dl, [bp + disk_number]
        jmp sector_buffer




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
        and al, 0xef
        sub al, 0x0b
        cmp al, 1
        ja short .done

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




%include "shared_items.asm"




;
; Initialized data
;

; Save code space by combining the pcboot marker and error message.
pcboot_error:
pcboot_vbr_marker:
        db "pcboot err"
pcboot_error_char:
        db 0, 0           ; Marker and error text
        db 0x8f, 0x70, 0x92, 0x77       ; Default marker ID number
        dw 0xaa55                       ; PC bootable sector marker
pcboot_vbr_marker_size: equ ($ - pcboot_vbr_marker)

mbr_code_end:

        times 437-($-main) db 0

disk_number_storage:            db 0x80
no_match_yet_storage:           db 0x01
read_error_flag_storage:        db 0x00

disk_signature:
        dd 0            ; 32-bit disk signature
        dw 0            ; padding

mbr_ptable:
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0
        dd 0, 0, 0, 0

aa55_signature:
bp_address:
        dw 0xaa55




;
; Uninitialized data area.
;
; Variables here are not initialized at load-time.  They are still defined
; using initialized data directives, because nasm insists on having initialized
; data in a non-bss section.
;

match_lba_storage:      dd 0
