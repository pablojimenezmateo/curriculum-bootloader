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
    volumeLabel:       db    "NO NAME    "
    fileSysType:       db    "FAT12   "

start:

    mov [bootdrv], dl
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

    ;push 11                 ; column
    ;push 6                  ; row
    ;push 17                 ; msg length
    ;push msg2               ; msg to write
    ;call print_text

    call draw_border



    ;----- Not enough space for sprites, move that to the second stage
    ; https://stackoverflow.com/questions/2065370/how-to-load-second-stage-boot-loader-from-first-stage
    ; Load stage 2 to memory.
    mov dl, [bootdrv]

jump_to_stage2:

    mov ah, 0x02
    ; Number of sectors to read.
    mov al, 1
    ; This may not be necessary as many BIOS set it up as an initial state.
    ;mov dl, 0x80
    ; Cylinder number.
    mov ch, 0
    ; Head number.
    mov dh, 0
    ; Starting sector number. 2 because 1 was already loaded.
    mov cl, 2
    ; Where to load to.
    mov bx, stage2
    int 0x13

    mov dl, 0x80
    jc jump_to_stage2 ; if error reading, set dl to 0x80 and try again, this should make it work in qemu

    jmp stage2

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

    mov ax, 7c0h           ; beginning of the code
    mov es, ax
    mov cx, [bp + 6]       ; length of string
    mov dh, [bp + 8]       ; row to put string
    mov dl, [bp + 10]      ; column to put string
    mov bp, [bp + 4]       

    mov ah, 13h          ; function 13 - write string
    mov al, 01h          ; attrib in bl, move cursor
    mov bl, 0Fh          ; color white

    int 10h             ; call BIOS service

    popa
    mov sp, bp
    pop bp

    ret 8

bootdrv: db 0

msg1:    db "IT'S DANGEROUS TO GO"
msg2:    db "ALONE!   TAKE ME."
rock:    dw 0xC3B7, 0xDFCF, 0xFFCF, 0x7FCF, 0x7FE6, 0xFFEF, 0xBFEF, 0xBFEF, 0x7FE7, 0xFFEF, 0x7DE7, 0x3C9B, 0x7DFD, 0xBC7D, 0xFCFF, 0x2CFC ; 32 bytes

times 510 - ($ - $$) db 0   ; padding with 0 at the end
dw 0xAA55                   ; PC boot signature


stage2:

    ;copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [wiseman_left]
    rep      MOVSb

    push 32                   ; how many bytes the sprite has
    push 06h                  ; first color, brown
    push 04h                  ; second color, red
    push 90                   ; y
    push 152                  ; x
    call draw_sprite

    ; copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [wiseman_right]
    rep      MOVSb

    ;push 90                    ; y
    push 160                   ; x
    call draw_sprite

    ; copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [fire_left]
    rep      MOVSb

    pop si
    pop si
    pop si
    push 0Eh                  ; first color, yellow
    push 0Ch                  ; second color, red
    push 90                   ; y
    push 80                   ; x
    call draw_sprite

    ; second fire left
    ;push 90                    ; y
    push 224                   ; x
    call draw_sprite

    ; copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [fire_right]
    rep      MOVSb

    ;push 90                   ; y
    push 88                   ; x
    call draw_sprite

    ;push 90                    ; y
    push 232                   ; x
    call draw_sprite

    ; copy the current sprite
    mov      cx, 44
    lea      di, [current_sprite]
    lea      si, [gef_left]
    rep      MOVSb

    pop si
    pop si
    pop si
    pop si

    push 44                   ; how many bytes the sprite has
    push 07h                  ; first color, brown
    push 06h                  ; second color, red
    push 120                   ; y
    push 152                   ; x
    call draw_sprite

    ; copy the current sprite
    mov      cx, 44
    lea      di, [current_sprite]
    lea      si, [gef_right]
    rep      MOVSb

    ;push 120                   ; y
    push 160                   ; x
    call draw_sprite

   cli
   hlt

; 00 is always black and 11 is always white
draw_sprite:

    push bp                ; save old base pointer
    mov bp, sp             ; use the current stack pointer as new base pointer
    pusha

    mov cx, [bp + 4]       ; x coordinate
    mov dx, [bp + 6]       ; y coordinate
    
                            ; initializing to 0, saves one byte from using mov
    xor si, si              ; index of the bit we are checking (width)
    xor di, di

.row: ; main loop, this will iterate over every bit of [rock], if it is a 1 the .one part will be executed, if it is a 0 the .zero part will
  
    cmp si, 16           ; check if we have to move to the next byte/row
    jne .same_row        ; Byte checked

    xor si, si           ; this executes if we move to the next row
    add di, 2            ; next row
    cmp di, [bp + 12]     ; if we have finished with the tile
    je .done
    inc dx

    mov cx, [bp + 4]       ; x coordinate

.same_row:

    xor bh, bh              ; store the color

    mov ax, [current_sprite + di]

    bt ax, si              ; first bit
    jnc .next_bit
    add bh, 1

.next_bit:
    inc si
    bt ax, si              ; second bit
    jnc .end_bit
    add bh, 2

.end_bit:
    cmp bh, 0              ; black
    je .pass

    mov ah, 0Ch ; draw

    cmp bh, 1              ; first_color
    je .first_color

    cmp bh, 2              ; second_color
    je .second_color

    jmp .white

.first_color:

    ; draw
    ;xor bh, bh
    mov al, [bp + 10]
    ;int 10h
    jmp .draw

.second_color:

    ; draw
    ;xor bh, bh
    mov al, [bp + 8]
    ;int 10h
    jmp .draw

.white:

    ; draw
    mov al, 0Fh
    ;int 10h
    jmp .draw

.draw:
    xor bh, bh
    int 10h

.pass:
    inc si
    inc cx
    jmp .row

.done:
    popa
    mov sp, bp
    pop bp
    ret 2 ; I only pop the y
    

current_sprite: dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,0x0000, 0x0000, 0x0000, 0x0000 ; 32 bytes       

fire_left:     dw 0x2020, 0x8020, 0x8800, 0xA810, 0xA880, 0xA288, 0xA6A8, 0xAAA2, 0x9AA2, 0x66AA, 0x55AA, 0x7568, 0xFD68, 0xF5A0, 0x56A0, 0xAA00 ; 32 bytes
fire_right:    dw 0x0808, 0x0802, 0x0022, 0x042A, 0x022A, 0x228A, 0x2A9A, 0x8AAA, 0x8AA6, 0xAA99, 0xAA55, 0x295D, 0x297F, 0x0A5F, 0x0A95, 0x00AA ; 32 bytes
wiseman_left:  dw 0x5400, 0x7700, 0x4500, 0x4500, 0x5E00, 0xFF80, 0x0FA0, 0xFBE8, 0xFAE9, 0xFAA9, 0xE8A9, 0xA8A8, 0xA8A8, 0xAA20, 0xAA00, 0x9680 ; 32 bytes
wiseman_right: dw 0x0015, 0x00dd, 0x0051, 0x0051, 0x00b5, 0x02ff, 0x0af0, 0x2bef, 0x6baf, 0x6aaf, 0x6a2b, 0x2a2a, 0x2a2a, 0x08aa, 0x00aa, 0x0296 ; 32 bytes
gef_left:      dw 0xAA00, 0xAA80, 0xAAA0, 0x88A8, 0x1818, 0x5158, 0x5558, 0x56A8, 0x5558, 0x5018, 0x5ED8, 0x5ED0, 0x9550, 0x65A0, 0x2A80, 0xBC00, 0x3F00, 0x33C0, 0x30F0, 0x3040, 0x0000, 0x2000 ; 44 bytes
gef_right:     dw 0x00aa, 0x02aa, 0x0aaa, 0x2a22, 0x2424, 0x2545, 0x2555, 0x2a95, 0x2555, 0x2405, 0x27b5, 0x07b5, 0x0556, 0x0a59, 0x02a8, 0x003e, 0x00fc, 0x03cc, 0x0f0c, 0x010c, 0x0000, 0x0008 ; 44 bytes

times 1024 - ($-$$) db 0 ; 1024 maximum size