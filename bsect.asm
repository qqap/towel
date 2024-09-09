; Tiny Linux Bootloader
; (c) 2014- Dr Gareth Owen (www.ghowen.me). All rights reserved.
; Some code adapted from Sebastian Plotz - rewritten, adding pmode and initrd support.

;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.

; Enable debug mode
%define DEBUG
; Include configuration file
%include "config.inc"

; Set 16-bit mode
[BITS 16]
; Set the origin to 0x7c00 (standard boot sector location)
org	0x7c00

; Initialize the system
	cli                     ; Clear interrupts
	xor	ax, ax              ; Zero out AX register
	mov	ds, ax              ; Set data segment to 0
	mov	ss, ax              ; Set stack segment to 0
	mov	sp, 0x7c00          ; Set stack pointer to 0x7c00 (top of boot sector)

; Enable A20 line and enter protected mode
    mov ax, 0x2401          ; Function to enable A20 line
    int 0x15                ; BIOS interrupt to enable A20
    ; jc err                ; Commented out error jump

    ; Load Global Descriptor Table
    lgdt [gdt_desc]         ; Load GDT (Global Descriptor Table) descriptor
    mov eax, cr0            ; Get current value of CR0 (Control Register 0)
    or eax, 1               ; Set Protection Enable (PE) bit to enter protected mode
    mov cr0, eax            ; Set CR0 to enter protected mode

    jmp $+2                 ; Short jump to flush prefetch queue

    ; Set up segment registers for protected mode
    mov bx, 0x8             ; Offset of first GDT descriptor
    mov ds, bx              ; Set Data Segment (DS) to first descriptor
    mov es, bx              ; Set Extra Segment (ES) to first descriptor
    mov gs, bx              ; Set General Segment (GS) to first descriptor

    ; Return to real mode (entering unreal mode)
    and al, 0xFE            ; Clear Protection Enable (PE) bit to return to real mode
    mov cr0, eax            ; Update CR0
    
    ; Reset segment registers for unreal mode
    xor ax,ax               ; Zero out Accumulator (AX)
	mov	ds, ax              ; Reset Data Segment (DS)
	mov	gs, ax              ; Reset General Segment (GS)
    mov ax, 0x1000          ; Set Extra Segment (ES) to 0x1000 (for kernel loading)
	mov	es, ax
    sti                     ; Enable interrupts

    ; Now in UNREAL mode

    ; Read first sector of kernel
    mov ax, 1               ; Read one sector
    xor bx,bx               ; Offset 0
    mov cx, 0x1000          ; Segment 0x1000
    call hddread            ; Call hard disk read function

; Read kernel setup
read_kernel_setup:
    mov al, [es:0x1f1]      ; Get number of setup sectors
    cmp ax, 0               ; Check if it's 0
    jne read_kernel_setup.next
    mov ax, 4               ; If 0, use default of 4 sectors

.next:
    ; Read rest of kernel setup
    mov bx, 512             ; Next offset (after first sector)
    mov cx, 0x1000          ; Segment 0x1000
    call hddread            ; Call hard disk read function

   ; Commented out error checks
   ; cmp word [es:0x206], 0x204
   ; jb err
   ; test byte [es:0x211], 1
   ; jz err

    ; Set up kernel parameters
    mov byte [es:0x210], 0xe1   ; Set loader type (0xe1 = Tiny Linux Bootloader)
    mov byte [es:0x211], 0x81   ; Set heap use flag (bit 5 set to make kernel quiet)
    mov word [es:0x224], 0xde00 ; Set head_end_ptr
    mov byte [es:0x227], 0x01   ; Set ext_loader_type / bootloader id
    mov dword [es:0x228], 0x1e000 ; Set cmd line ptr

    ; Copy command line
    mov si, cmdLine         ; Source: command line
    mov di, 0xe000          ; Destination: 0x1e000
    mov cx, cmdLineLen      ; Length of command line
    rep movsb               ; Copy command line

; Load kernel
    mov edx, [es:0x1f4]     ; Get bytes to load
    shl edx, 4              ; Multiply by 16 (convert paragraphs to bytes)
    call loader             ; Call loader function

; Load initial ramdisk (initrd)
    ;mov eax, 0x7fab000      ; Address where QEMU loads initrd
    ;mov [highmove_addr],eax ; Set as end of kernel and initrd load address
    ;mov [es:0x218], eax     ; Store initrd address in kernel header
    ;mov edx, [initRdSize]   ; Get ramdisk size in bytes
    ;mov [es:0x21c], edx     ; Store ramdisk size in kernel header
    ;call loader             ; Call loader function

; Start kernel
kernel_start:
    cli                     ; Clear interrupts
    mov ax, 0x1000          ; Set all segment registers to 0x1000
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xe000          ; Set stack pointer
    jmp 0x1020:0            ; Jump to kernel entry point

    jmp $                   ; Infinite loop (should never reach here)

; ================= functions ====================

; Loader function
; Input: EDX = length in bytes to load
; Uses hddread [hddLBA] and highmove [highmove_addr] variables
; Clobbers 0x2000 segment
loader:
.loop:
    cmp edx, 127*512        ; Compare remaining bytes to 127 sectors
    jl loader.part_2        ; If less, jump to part 2
    jz loader.finish        ; If equal, finish

    mov ax, 127             ; Load 127 sectors
    xor bx, bx              ; Offset 0
    mov cx, 0x2000          ; Segment 0x2000
    push edx                ; Save remaining bytes
    call hddread            ; Read from hard disk
    call highmove           ; Move to high memory
    pop edx                 ; Restore remaining bytes
    sub edx, 127*512        ; Subtract loaded bytes

    jmp loader.loop         ; Continue loop

.part_2:                    ; Load less than 127 sectors
    shr edx, 9              ; Divide by 512 (convert bytes to sectors)
    inc edx                 ; Round up to next sector THIS MUST BE THE PROBLEM
    mov ax, dx              ; Set number of sectors to read
    xor bx,bx               ; Offset 0
    mov cx, 0x2000          ; Segment 0x2000
    call hddread            ; Read from hard disk
    call highmove           ; Move to high memory

.finish:
    ret                     ; Return from function

; High memory move function
highmove_addr dd 0x100000   ; Starting address for high memory move
highmove:
    mov esi, 0x20000        ; Source address
    mov edi, [highmove_addr] ; Destination address
    mov edx, 512*127        ; Number of bytes to move
    mov ecx, 0              ; Initialize counter
.loop:
    mov eax, [ds:esi]       ; Load 4 bytes from source
    mov [ds:edi], eax       ; Store 4 bytes to destination
    add esi, 4              ; Increment source pointer
    add edi, 4              ; Increment destination pointer
    sub edx, 4              ; Decrement remaining bytes
    jnz highmove.loop       ; Continue if not zero
    mov [highmove_addr], edi ; Update highmove_addr
    ret                     ; Return from function

errhddread:
%ifdef DEBUG
    mov si, hdderrmsg       ; Load address of error message
    mov ah, 0x0E            ; BIOS teletype output
.print_loop:
    lodsb                   ; Load next character
    test al, al             ; Check if it's null terminator
    jz .done                ; If null, we're done
    int 0x10                ; Print character
    jmp .print_loop         ; Continue loop
.done:
    jmp $                   ; Hang system after printing

hdderrmsg db 'Error reading from disk', 0

%endif

; Hard disk read function
hddread:
    push eax                ; Save EAX
    mov [dap.count], ax     ; Set number of sectors to read
    mov [dap.offset], bx    ; Set destination offset
    mov [dap.segment], cx   ; Set destination segment
    mov edx, dword [hddLBA] ; Get current LBA
    mov dword [dap.lba], edx ; Set LBA in DAP
    and eax, 0xffff         ; Clear upper 16 bits of EAX
    add edx, eax            ; Advance LBA pointer
    mov [hddLBA], edx       ; Store new LBA
    mov ah, 0x42            ; Extended read sectors function
    mov si, dap             ; Address of DAP
    mov dl, 0x80            ; First hard disk
    int 0x13                ; BIOS disk interrupt
    ; jc errhddread           ; If carry set, jump to error
    pop eax                 ; Restore EAX
    ret                     ; Return from function

; Disk Address Packet (DAP) structure
dap:
    db 0x10                 ; DAP size (16 bytes)
    db 0                    ; Unused
.count:
    dw 0                    ; Number of sectors to transfer
.offset:
    dw 0                    ; Destination offset
.segment:
    dw 0                    ; Destination segment
.lba:
    dd 0                    ; LBA (low 32 bits)
    dd 0                    ; LBA (high 32 bits, unused in this code)

; Global Descriptor Table (GDT) descriptor
gdt_desc:
    dw gdt_end - gdt - 1    ; Size of GDT
    dd gdt                  ; Address of GDT

; Global Descriptor Table (GDT)
gdt:
    dq 0                    ; Null descriptor
; Flat data segment descriptor
    dw 0FFFFh               ; Limit (0-15)
    dw 0                    ; Base (0-15)
    db 0                    ; Base (16-23)
    db 10010010b            ; Access byte
    db 11001111b            ; Flags and Limit (16-19)
    db 0                    ; Base (24-31)
gdt_end:

; Debug error string
%ifdef DEBUG
%endif

; Configuration options
    cmdLine db cmdLineDef,0              ; Command line (defined in config.inc)
    cmdLineLen equ $-cmdLine             ; Length of command line
    initRdSize dd initRdSizeDef          ; Initial ramdisk size (from config.inc)
    hddLBA dd 1          ; Starting Logical Block Address for kernel

; Boot sector magic number
	times	510-($-$$)	db	0            ; Pad to 510 bytes
	dw	0xaa55                           ; Boot signature

; Commented out real mode print code
;    mov si, strhw
;    mov eax, 0xb8000
;    mov ch, 0x1F ; white on blue
;loop:
;    mov cl, [si]
;    mov word [ds:eax], cx
;    inc si
;    add eax, 2
;    cmp [si], byte 0
;    jnz loop
