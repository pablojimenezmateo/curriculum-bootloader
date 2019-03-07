bits 16

jmp start  ; https://stackoverflow.com/questions/47277702/custom-bootloader-booted-via-usb-drive-produces-incorrect-output-on-some-compute
resb 0x50

start:
    mov ax, 07C0h
    add ax, 288
    mov ss, ax              ; ss = stack space
    mov sp, 4096            ; sp = stack pointer

    mov ax, 07C0h
    mov ds, ax              ; ds = data segment

    mov ah, 00d             ; set video mode to graphical
    mov al, 13d             ; 13h - graphical mode, 40x25. 256 colors.;320x200 pixels. 1 page.

    int 10h                 ; call

    push 9
    push 5
    push 20
    push msg1
    call print_text

    push 11
    push 6
    push 17
    push msg2
    call print_text

    call draw_border

    cli ; stop execution
    hlt

; ----------------------------------------------------------------------

draw_border:

    ; top border
    ; x from 0 to 304 in increments of 16 (19 times)

    xor si, si ; si = 0

.top_border:

    push 0                  ; initial y position to draw the rock
    push si                 ; initial x position to draw the rock
    call draw_rock_tile

    add si, 16

    cmp si, 320
    je .right_border_init

    jmp .top_border

;------------------------ Vertical borders
.right_border_init:

    mov si, 16
    mov di, 0
    jmp .vertical_border

.left_border_init:

    mov si, 16
    mov di, 304

.vertical_border:

    push si                  ; initial y position to draw the rock
    push di                   ; initial x position to draw the rock
    call draw_rock_tile  

    add si, 16

    cmp si, 192
    je .check_finish

    jmp .vertical_border


.check_finish:

    cmp di, 304
    je .bottom_border_left_init
    jmp .left_border_init

;.right_border_init:
;
;    mov si, 16
;
;.right_border:
;
;    push si                  ; initial y position to draw the rock
;    push di                 ; initial x position to draw the rock
;    call draw_rock_tile  
;
;    add si, 16
;
;    cmp si, 192
;    je .bottom_border_left_init
;
;    jmp .right_border


;---------------------- Vertical borders

.bottom_border_left_init:

    mov si, 16

.bottom_border_left:

    push 176                  ; initial y position to draw the rock
    push si                 ; initial x position to draw the rock
    call draw_rock_tile

    add si, 16

    cmp si, 128
    je .bottom_border_right_init

    jmp .bottom_border_left

.bottom_border_right_init:

    mov si, 192

.bottom_border_right:

    push 176                  ; initial y position to draw the rock
    push si                 ; initial x position to draw the rock
    call draw_rock_tile

    add si, 16

    cmp si, 304
    je .done

    jmp .bottom_border_right

.done:
    ret

draw_rock_tile:

    push bp                ; save old base pointer
    mov bp, sp             ; use the current stack pointer as new base pointer
    pusha

    mov ah, 0Ch
    xor bh, bh             ; page number 0

    mov cx, [bp + 4]       ; x coordinate
    mov dx, [bp + 6]       ; y coordinate
    push cx                ; we need to store the x value for .next_row
     
                            ; initializing to 0, saves one byte from using mov
    xor si, si              ; index of the bit we are checking (width)
    xor di, di              ; index of the bit we are checking (height)

.row: ; main loop, this will iterate over every bit of [rock], if it is a 1 the .one part will be executed, if it is a 0 the .zero part will
    
    cmp si, 16 ; width of the rock
    je .next_row

    cmp di, 32 ;32 bytes
    je .done

    push dx
    mov dx, [rock + di]    ; load the bitpattern
    bt dx, si              ; check the si th bit and store it on cf
    pop dx

    jc .one

.zero:

    xor al, al       ; color black
    jmp .draw

.one:

    mov al, 06h       ; color brown

.draw:

    int 10h

    inc si
    inc cx

    jmp .row

.next_row:

    add di, 2  ; next byte
    xor si, si  ; firs bit
    inc dx     ; next row

    pop cx
    push cx

    jmp .row


.done:
    pop cx
    popa
    mov sp, bp
    pop bp
    ret 4

print_text:

    push bp                ; save old base pointer
    mov bp, sp             ; use the current stack pointer as new base pointer
    pusha

    mov ax, 7c0h        ; beginning of the code
    mov es, ax
    mov cx, [bp + 6]            ; length of string
    mov dh, [bp + 8]            ; row to put string
    mov dl, [bp + 10]           ; column to put string
    mov bp, [bp + 4]

    mov ah, 13h          ; function 13 - write string
    mov al, 01h          ; attrib in bl, move cursor
    mov bl, 0Fh          ; color white

    int 10h             ; call BIOS service

    popa
    mov sp, bp
    pop bp

    ret 8

msg1: db "IT'S DANGEROUS TO GO"
msg2: db "ALONE!   HIRE ME."
rock: dw 0xC3B7, 0xDFCF, 0xFFCF, 0x7FCF, 0x7FE6, 0xFFEF, 0xBFEF, 0xBFEF, 0x7FE7, 0xFFEF, 0x7DE7, 0x3C9B, 0x7DFD, 0xBC7D, 0xFCFF, 0x2CFC ; 32 bytes
fire: dw 0x2020, 0x8020, 0x8800, 0xA810, 0xA880, 0xA288, 0xA6A8, 0xAAA2, 0x9AA2, 0x66AA, 0x55AA, 0x7568, 0xFD68, 0xF5A0, 0x56A0, 0xAA00 ; 32 bytes
wiseman: dw 0x5400, 0x7700, 0x4500, 0x4500, 0x5E00, 0xFF80, 0x0FA0, 0xFBE8, 0xFAE9, 0xFAA9, 0xE8A9, 0xA8A8, 0xA8A8, 0xAA20, 0xAA00, 0x9680; 32 bytes

;gef:     dw 0xAA00, 0xAA80, 0xAAA0, 0x88A8, 0x1818, 0x5158, 0x5558, 0x56A8, 0x5558, 0x5018, 0x5ED8, 0x5ED0, 0x9550, 0x65A0, 0x2A80, 0xBC00, 0x3F00, 0x33C0, 0x30F0, 0x3040, 0x0000, 0x2000; 44 bytes

times 510 - ($ - $$) db 0   ; padding with 0 at the end
dw 0xAA55                   ; PC boot signature
