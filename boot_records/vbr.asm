; pcboot VBR.
;
; TODO:
;  - Compute a checksum of stage1 before jumping into it.
;


        bits 16


;
; Memory layout:
;   0x600..0x7ff                MBR
;   ...
;   0x????..0x7bff              stack
;   0x7c00..0x7dff              pristine, executing VBR
;   0x7e00..0x7fff              uninitialized variables
;   0x8000..0x81ff              sector read buffer
;   0x8200..0x83ff              relocated stage1 load-loop
;   ...
;   0x9000..0x????              stage1
;
; This VBR does not initialize CS, and therefore, the stage1 binary must
; be loaded *above* the 0x7c00 entry point.  (i.e. If the VBR is running at
; 0x7c0:0, then we cannot jump before 0x7c00, but we can reach 0x7c0:0x400.)
;

mbr:                            equ 0x600
vbr:                            equ 0x7c00
stack:                          equ 0x7c00
sector_buffer:                  equ 0x8000
stage1_load_loop:               equ 0x8200
stage1:                         equ 0x9000


;
; Global variables.
;
; For code size effiency, globals are accessed throughout the program using an
; offset from the BP register.
;

disk_number:            equ disk_number_storage         - bp_address
no_match_yet:           equ no_match_yet_storage        - bp_address
match_lba:              equ match_lba_storage           - bp_address
read_error_flag:        equ read_error_flag_storage     - bp_address
no_match_yet_read_error_flag: equ no_match_yet_read_error_flag_storage - bp_address


%include "shared_macros.asm"


        section .boot_record

        global main
main:
        ;
        ; Prologue.  Skip FAT32 boot parameters, setup registers.
        ;
        ;  * According to Intel docs (286, 386, and contemporary), moving into
        ;    SS masks interrupts until after the next instruction executes.
        ;    Hence, this code avoids clearing interrupts.  (Saves one byte.)
        ;
        ;  * The CS register is not initialized.  It's possible that this code
        ;    is running at 0x7c0:0 rather than 0:0x7c00.  The VBR can only use
        ;    relative jumps.
        ;

        jmp short .skip_fat32_params
        times 90-($-main) db 0
.skip_fat32_params:
        xor ax, ax
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
        mov ss, ax
        mov sp, stack
        sti

        ; Use BP to access global variables with smaller memory operands.
        mov bp, bp_address

        ; Initialize globals.
        ;  - set no_match_yet to 1.
        ;  - set read_error_flag to 0.
        mov word [bp + no_match_yet_read_error_flag], 1

        init_disk_number_dynamic

        ; Load the MBR and copy it out of the way.
        xor esi, esi
        call read_sector
        jc short .skip_primary_scan_loop
        mov si, sector_buffer
        mov di, mbr
        mov cx, 512
        cld
        rep movsb

        mov bx, mbr + 446

.primary_scan_loop:
        xor esi, esi
        call scan_pcboot_vbr_partition
        call scan_extended_partition
        add bx, 0x10
        cmp bx, mbr + 510
        jne short .primary_scan_loop

.skip_primary_scan_loop:
        ; If we didn't find a match, fail at this point.
        cmp byte [bp + no_match_yet], 0
        push word missing_vbr_error     ; Push error code. (No return.)
        jne short fail

        ;
        ; Load the next boot sector.
        ;
        mov esi, [bp + match_lba]
        inc esi
        call read_sector

        ;
        ; Verify that the next sector ends with a marker.
        ;
        ; Perhaps a partitioning tool could fail to preserve the reserved
        ; area's contents.
        ;
        push word missing_post_vbr_marker_error         ; Push error code. (No return.)
        cmp dword [sector_buffer + 512 - 4], 0xaa55aa55
        jne short fail
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

        ; Load the VBR.
        add esi, [bx + 8]
        call read_sector

        ; Check whether the VBR matches our own VBR.  Don't trash esi.
        pusha
        mov si, vbr
        mov di, sector_buffer
        mov cx, 512
        cld
        rep cmpsb
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




        times 512-6-6-4-2-($-main) db 0

; Save code space by combining the pcboot marker and error message.
pcboot_error:
        db 0, 'A' - error_bias, "rre "
pcboot_marker:
        db "toobcp"                     ; Marker text and error text
pcboot_error_end:
        db 0x8f, 0x70, 0x92, 0x77       ; Default marker ID number
        dw 0xaa55
pcboot_marker_end:




;
; Uninitialized data area.
;
; Variables here are not initialized at load-time.  They are still defined
; using initialized data directives, because nasm insists on having initialized
; data in a non-bss section.
;

        bp_address:

no_match_yet_read_error_flag_storage:
no_match_yet_storage:           db 0
read_error_flag_storage:        db 0
no_match_yet_read_error_flag_storage_end:

disk_number_storage:            db 0
match_lba_storage:              dd 0




;
; stage1 prep code area
;
; This post-VBR code is loaded by the VBR.  It reuses the code in the VBR to
; load stage1.  As with the MBR code, this sector must be relocated first to
; avoid being trampled by the next sector read.
;

        times (stage1_load_loop-vbr)-($-main) db 0

stage1_load_loop_entry:
        mov di, stage1_load_loop
        mov si, sector_buffer
        mov cx, 512
        cld
        rep movsb
        jmp 0:.relocated                ; Ensure CS is zero.

.relocated:
        ;
        ; Load the next 30 sectors of the volume to 0x9000.
        ;
        push word read_error            ; Push error code. (No return.)
        mov ebx, [bp + match_lba]
        add ebx, 2
        mov di, stage1
        mov al, 30
.read_loop:
        mov esi, ebx
        call read_sector
        jc near fail
        mov cx, 512
        mov si, sector_buffer
        cld
        rep movsb
        inc ebx
        dec al
        jnz short .read_loop

.read_done:
        ;
        ; Jump to stage1.
        ;  - dl is the BIOS disk number.
        ;  - esi points to the starting LBA of the boot volume.
        ;
        mov dl, byte [bp + disk_number]
        mov esi, [bp + match_lba]
        jmp stage1

        ;
        ; pcboot post-VBR sector marker
        ;
        ; In FAT32, if the reserved area disappeared somehow, this 32-bit value
        ; would be the cluster 0x0a55aa55 with two of the reserved highest bits
        ; set.  It is somewhat unlikely to appear by accident.
        ;
        times 508-($-stage1_load_loop_entry) db 0
        dd 0xaa55aa55
