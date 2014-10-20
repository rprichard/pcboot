; pcboot master boot record (MBR)
;
; Searches the boot disk for the pcboot boot volume and launches it via the
; conventional MBR-VBR interface.
;
; The MBR only searches the disk indicated by the DL value, and only if DL is
; between 0x80 and 0x8f.  It otherwise searches the disk 0x80.  Searching other
; disks might(?) be insecure (e.g. an unexpectedly bootable USB flash drive?).
;
; The VBR is identified by an 18-byte marker at the end of the VBR.  The MBR
; searches for the marker in all primary and logical partitions with a FAT32
; partition type, and succeeds if only a single VBR is found.  If multiple VBRs
; match, the MBR aborts.
;
; pcboot marker:
;
;     0 1 2 3 4 5  6  7 8 9  10   11   12   13   14   15   16   17
;     p c b o o t ' ' e r r 0x00 0x00 0x8f 0x70 0x92 0x77 0x55 0xAA
;                                     ^^^^^^^^^^^^^^^^^^^
;     These 4 bytes are configurable ----/
;
; To avoid a hypothetical(?) DOS vulnerability, the MBR only considers
; partitions whose type ID is one of the expected values for a FAT32 volume.
; (Suppose an attacker could control all of some partition's data.  It could
; create a partition that looked like the boot volume.)  If this risk could be
; ruled out somehow, it could reduce the amount of code here.
;
; The pcboot MBR and VBR read sectors using the function "read_sector".  This
; function checks for INT13 LBA extensions and uses them if present.  If they
; are not present, it converts an LBA to CHS using INT13H/08H, then passes the
; CHS to INT13H/02H.  It does not assume that the CHS values in the partition
; table are accurate.[1]  Using the partition table's CHS values is also tricky
; when the VBR needs to read the post-VBR sectors--it wants to increment the
; sector, but it could wrap!  It could issue a multi-sector read, but reads
; that span tracks might be unreliable.
;
; [1] The CHS interface does not describe true disk geometry, but what we
; actually need is *consistency*.  Because BIOS cannot report the "true"
; disk geometry provided via ATA, due to field size mismatches, it must emulate
; a different geometry, and the emulation apparently varies by BIOS vendor and
; setting.  Partitioning software might not know what the current BIOS-reported
; geometry is.  Disks can move between computers.  Hence, any CHS values
; written on disk are not trustworthy.
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
read_sector_lba:        equ read_sector_lba_storage     - bp_address
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
        mov ss, ax                      ; Clear SS
        mov sp, stack                   ; Set SP to 0x7c00
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
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




%include "shared_items.asm"




;
; Statically-initialized data area.
;
; The variables need to be within 128 bytes of bp_address.
;

; Save code space by combining the pcboot marker and error message.
pcboot_error:
pcboot_vbr_marker:
        db "pcboot err"                 ; Error text and part of marker
pcboot_error_char:
        db 0, 0                         ; Error code and NUL terminator
        db 0x8f, 0x70, 0x92, 0x77       ; Default marker ID number
        dw 0xaa55                       ; PC bootable sector marker
pcboot_vbr_marker_size: equ ($ - pcboot_vbr_marker)

disk_number_storage:            db 0x80
no_match_yet_storage:           db 0x01

mbr_code_end:




;
; Disk signature and partition table
;

        times 440-($-main) db 0

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

match_lba_storage:              dd 0
read_sector_lba_storage:        dd 0
