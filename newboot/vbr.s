; pcboot VBR.
;


        bits 16


;
; Memory layout:
;   0x600..0x7ff                MBR
;   0x800..0x9ff                sector_buffer
;   ...
;   0x????..0x7bff              stack
;   0x7c00..0x7dff              pristine, executing VBR
;   0x7e00..0x7fff              uninitialized variables
;   0x8000..0x????              pcboot stage1 binary
;

mbr:                            equ 0x600
sector_buffer:                  equ 0x800
vbr:                            equ 0x7c00
stack:                          equ 0x7c00
stage1:                         equ 0x8000


;
; Global variables.
;
; For code size effiency, globals are accessed throughout the program using an
; offset from the BP register.
;

match_lba:                      equ 0    ; dword
disk_number:                    equ 4    ; byte
no_match_yet:                   equ 8    ; byte


%include "shared_macros.s"


        section .boot_record

        global main
main:
        ;
        ; Prologue.  Skip FAT32 boot parameters, setup registers.
        jmp .skip_fat32_params
        times 90-($-main) db 0
.skip_fat32_params:
        cli
        xor ax, ax
        mov ss, ax                      ; Clear SS
        mov ds, ax                      ; Clear DS
        mov es, ax                      ; Clear ES
        mov sp, stack
        jmp 0:.start                    ; Ensure CS is 0.
.start:
        sti

        ; Use BP to access global variables with smaller memory operands.  We
        ; also use BP as the end address for the primary partition table scan.
        mov bp, uninitialized_variable_area

        ; Initialize globals.
        mov byte [bp + no_match_yet], 1

        init_disk_number_dynamic

        ; Load the MBR and copy it out of the way.
        xor esi, esi
        call read_sector
        mov si, sector_buffer
        mov di, mbr
        mov cx, 512
        cld
        rep movsb

        mov si, mbr + 446

.primary_scan_loop:
        xor edx, edx
        call scan_pcboot_vbr_partition
        call scan_extended_partition
        add si, 0x10
        cmp si, mbr + 510
        jne .primary_scan_loop

        ; If we didn't find a match, fail at this point.
        cmp byte [bp + no_match_yet], 0
        jne fail

        ;
        ; Load the next 31 sectors of the volume to 0x8000.
        ;
        mov ebx, [bp + match_lba]
        mov di, stage1
        mov dl, 31
.read_loop:
        inc ebx
        mov esi, ebx
        call read_sector
        mov cx, 512
        mov si, sector_buffer
        cld
        rep movsb
        dec dl
        jnz .read_loop

.read_done:
        ;
        ; Jump to 0x8000.  ebx points to the last sector (#30) of stage1.
        ;
        jmp stage1




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

        ; Load the VBR.
        mov esi, [si + 8]
        add esi, edx
        call read_sector

        ; Check whether the VBR matches our own VBR.  Don't trash esi.
        pusha
        mov si, vbr
        mov di, sector_buffer
        mov cx, 512
        cld
        rep cmpsb
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


pcboot_error:
        db "pcbootV err",0


        times 504-($-main) db 0

        db "PCBOOT"
        dw 0xaa55

        uninitialized_variable_area:
