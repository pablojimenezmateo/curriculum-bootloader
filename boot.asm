bits 16

boot:
    jmp start
    TIMES 3-($-$$) DB 0x90   ; Support 2 or 3 byte encoded JMPs before BPB.

    ; Dos 4.0 EBPB 1.44MB floppy
    OEMname:           db    "mkfs.fat"  ; mkfs.fat is what OEMname mkdosfs uses
    bytesPerSector:    dw    512
    sectPerCluster:    db    1
    reservedSectors:   dw    1
    numFAT:            db    2
    numRootDirEntries: dw    224
    numSectors:        dw    2880
    mediaType:         db    0xf0
    numFATsectors:     dw    9
    sectorsPerTrack:   dw    18
    numHeads:          dw    2
    numHiddenSectors:  dd    0
    numSectorsHuge:    dd    0
    driveNum:          db    0
    reserved:          db    0
    signature:         db    0x29
    volumeID:          dd    0x2d7e5a1a
    volumeLabel:       db    "Test name"
    fileSysType:       db    "FAT12   "

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

    push 9                  ; column
    push 5                  ; row
    push 20                 ; msg length
    push msg1               ; msg to write
    call print_text
    
    push 11                 ; column
    push 6                  ; row
    push 17                 ; msg length
    push msg2               ; msg to write
    call print_text

    call draw_border

    ;push 50                   ; x
    ;push 50                   ; y
    ;push 0Ch                  ; first color, red
    ;push 0Eh                  ; second color, yellow
    ;push fire                 ; sprite to draw
    ;push 16                   ; how many rows the sprite has
    ;call draw_sprite

    cli ; stop execution
    hlt

; ----------------------------------------------------------------------

draw_border:

xor cx, cx ; draw horizontally
xor dx, dx ; border index

.top_border_init:
    xor si, si
    xor di, di
    mov ax, 320
    jmp .draw

.bottom_left_border_init:

    mov si, 176
    xor di, di
    mov ax, 128
    jmp .draw

.bottom_right_border_init:

    mov di, 192
    mov ax, 304
    jmp .draw

.right_border_init:

    xor si, si
    xor di, di
    mov ax, 192
    mov cx, 1 ; draw vertically
    jmp .draw

.left_border_init:

    xor si, si
    mov di, 304

.draw:

    push si                   ; initial y position to draw the rock
    push di                   ; initial x position to draw the rock
    call draw_rock_tile  

    cmp cx, 0  ;if horizontal
    jne .vertical_index_update

    add di, 16
    cmp di, ax
    je .check_finish

    jmp .draw

.vertical_index_update:
    add si, 16
    cmp si, ax
    je .check_finish

    jmp .draw


.check_finish:

    inc dx       ; we have finished a border

    cmp dx, 1
    je .bottom_left_border_init

    cmp dx, 2
    je .bottom_right_border_init

    cmp dx, 3
    je .right_border_init
   
    cmp dx, 4
    je .left_border_init

    jmp .done

.done:
    ret

draw_rock_tile:

    push bp                ; save old base pointer
    mov bp, sp             ; use the current stack pointer as new base pointer
    pusha

    mov cx, [bp + 4]       ; x coordinate
    mov dx, [bp + 6]       ; y coordinate
    
                            ; initializing to 0, saves one byte from using mov
    xor si, si              ; index of the bit we are checking (width)
    xor di, di

.row: ; main loop, this will iterate over every bit of [rock], if it is a 1 the .one part will be executed, if it is a 0 the .zero part will
  
    cmp si, 16     ; check if we have to move to the next byte/row
    jne .same_row  ; Byte checked

    xor si, si     ; this executes if we move to the next row
    cmp di, 32     ; if we have finished with the tile
    je .done
    add di, 2      ; next row
    inc dx

    mov cx, [bp + 4]       ; x coordinate


.same_row:

    mov ax, [rock + di]
    bt ax, si              ; check the si th bit and store it on cf
    jnc .pass

    ; draw
    mov ah, 0Ch
    xor bh, bh             ; page number 0
    mov al, 06h            ; Brown
    int 10h

.pass:
    inc si
    inc cx
    jmp .row

.done:
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


; 00 is always black and 11 is always white
;draw_sprite:
;
;    push bp                ; save old base pointer
;    mov bp, sp             ; use the current stack pointer as new base pointer
;    pusha
;
;    mov ah, 0Ch
;    xor bh, bh             ; page number 0
;
;    mov cx, [bp + 12]       ; x coordinate where to draw the sprite
;    mov dx, [bp + 14]       ; y coordinate where to draw the sprite
;    push cx                 ; we need to store the x value for .next_row
;     
;                            ; initializing to 0, saves one byte from using mov
;    xor si, si              ; index of the bit we are checking (width)
;    xor di, di              ; index of the bit we are checking (height)
;
;.row:
;    
;    push dx
;    push ax
;    mov ax, [bp + 4]       ; sprite address
;
;    ; most significant
;    mov dx, [bp + 4 + di]      ; load byte  00 10 00 00 # 00 10 00 00
;    bt dx, si              ; check the si th bit and store it on cf
;
;    xor ax, ax             ; store the color index
;
;    jnc .zero_1                ; if the bit is zero
;    add ax, 2
;    inc si
;
;.zero_1:
;    ; less significant
;    mov dx, [bp + 4 + di]      ; load byte  00 10 00 00 # 00 10 00 00
;    bt dx, si              ; check the si th bit and store it on cf
;    jnc .zero_2
;    add ax, 1
;    inc si
;
;.zero_2:
;    cmp ax, 0              ; black
;    je .black
;
;    cmp ax, 1              ; first color
;    je .first_color
;
;    cmp ax, 2              ; second color
;    je .second_color
;
;    cmp ax, 3              ; white
;    je .white
;
;
;.black:
;    pop ax
;    pop dx
;
;    mov al, 01h            ; Brown
;    int 10h
;    jmp .row
;
;
;.first_color:
;    pop ax
;    pop dx
;    mov al, 02h            ; Brown
;    int 10h
;    jmp .row
;
;.second_color:
;    pop ax
;    pop dx
;    mov al, 03h            ; Brown
;    int 10h
;    jmp .row
;
;.white:
;    pop ax
;    pop dx
;    mov al, 0fh            ; Brown
;    int 10h
;    jmp .row
;
;.done:
;    popa
;    mov sp, bp
;    pop bp
;
;    ret 12

msg1:    db "IT'S DANGEROUS TO GO"
msg2:    db "ALONE!   HIRE ME."
rock:    dw 0xC3B7, 0xDFCF, 0xFFCF, 0x7FCF, 0x7FE6, 0xFFEF, 0xBFEF, 0xBFEF, 0x7FE7, 0xFFEF, 0x7DE7, 0x3C9B, 0x7DFD, 0xBC7D, 0xFCFF, 0x2CFC ; 32 bytes
fire:    dw 0x2020, 0x8020, 0x8800, 0xA810, 0xA880, 0xA288, 0xA6A8, 0xAAA2, 0x9AA2, 0x66AA, 0x55AA, 0x7568, 0xFD68, 0xF5A0, 0x56A0, 0xAA00 ; 32 bytes
;wiseman: dw 0x5400, 0x7700, 0x4500, 0x4500, 0x5E00, 0xFF80, 0x0FA0, 0xFBE8, 0xFAE9, 0xFAA9, 0xE8A9, 0xA8A8, 0xA8A8, 0xAA20, 0xAA00, 0x9680 ; 32 bytes

;gef:     dw 0xAA00, 0xAA80, 0xAAA0, 0x88A8, 0x1818, 0x5158, 0x5558, 0x56A8, 0x5558, 0x5018, 0x5ED8, 0x5ED0, 0x9550, 0x65A0, 0x2A80, 0xBC00, 0x3F00, 0x33C0, 0x30F0, 0x3040, 0x0000, 0x2000; 44 bytes

times 510 - ($ - $$) db 0   ; padding with 0 at the end
dw 0xAA55                   ; PC boot signature
