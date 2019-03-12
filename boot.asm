bits 16

boot:

    ; This is a BPB, so that the BIOS does not overwrite our code
    ; https://stackoverflow.com/questions/47277702/custom-bootloader-booted-via-usb-drive-produces-incorrect-output-on-some-compute
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

    ; This is used to offset all memory addresses by 8 bytes, or the size of the PDF magic numbers
    dw 0xffff, 0xffff, 0xffff, 0xffff

start:

    ; In real hardware the BIOS puts the address of the booting drive on the dl register
    ; so I am writing that addres into memory at [bootdrv]
    mov [bootdrv], dl

    ; Setting the stack
    mov ax, 07C0h
    add ax, 288
    mov ss, ax              ; ss = stack space
    mov sp, 4096            ; sp = stack pointer

    mov ax, 07C0h
    mov ds, ax              ; ds = data segment

    mov ah, 00d             ; Set video mode to graphical
    mov al, 13d             ; 13h - graphical mode, 40x25. 256 colors.;320x200 pixels. 1 page.

    int 10h                 ; Call


    ; The function print_text accepts a message and position and writes it to screen in
    ; mode 13h
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

    ; draw_border is in charge of calling draw_rock in a loop to draw all the cave border
    ; no parameters
    call draw_border

    ; You only have 512 bytes of space on the first stage, and my napking maths told me that
    ; the sprites were too much. So on the first stage I write the text and draw the border
    ; (or else I would not have enough space on second stage), and then jump to second stagr
    ; https://stackoverflow.com/questions/2065370/how-to-load-second-stage-boot-loader-from-first-stage
    ; Restore the direction of the booting drive
    mov dl, [bootdrv]

; I need this label in case the boot fails, in real hardware the BIOS puts the drive address on dl,
; but if you are using qemu dl must be 0x80 for it to boot. So I try to boot normally first and if it
; fails I retry for qemu
jump_to_stage2:

    mov ah, 0x02
    mov al, 1         ; Number of sectors to read
    mov ch, 0         ; Cylinder number
    mov dh, 0         ; Head number
    mov cl, 2         ; Starting sector number. 2 because 1 was already loaded.
    mov bx, stage2    ; Where the stage 2 code is

    int 0x13

    mov dl, 0x80
    jc jump_to_stage2 ; If error loading, set dl to 0x80 and try again, this should make it work in qemu

    jmp stage2

; Stage 1 functions

; This function calls draw_rock on a loop in order to draw the whole border
draw_border:
                                 ; You will notice that I use xor a lot
                                 ; this is to set a register to 0
                                 ; is on byte less than mov and I need those bytes

xor cx, cx                       ; Draw horizontally
xor dx, dx                       ; Border index

; The inits set the initial parameters for each border
; di = Initial x position
; si = Initial y position
; ax = When to stop
; cx = Draw horizontally (0) or vertically (1)
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

    push si                        ; Initial y position to draw the rock
    push di                        ; Initial x position to draw the rock
    call draw_rock_tile  

    cmp cx, 0                      ; If we are drawing horizontally
    jne .vertical_index_update

    ; Update the horizontal index (di)
    add di, 16
    cmp di, ax
    je .check_finish

    jmp .draw

; Update the vertical index (si)
.vertical_index_update:

    add si, 16
    cmp si, ax
    je .check_finish

    jmp .draw

; If we go here, we have finished a border, increment the border index
; and continue
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

; This function draws a rock, the coordinates are the top-left corner
;
; The rock sprite is encoded as following
;     
;    - The tile is 16x16px
;    - Each 1 represents a brown pixel
;    - Each 0 represents a black pixel (or no draw since the background is black)
;
; So we iterate through every bit on [rock] to do that. Each byte is a row.
;
; Parameters:
;
;    - [bp + 4] x coordinate
;    - [bp + 6] y coordinate
;
draw_rock_tile:

    push bp                 ; Save old base pointer
    mov bp, sp              ; Use the current stack pointer as new base pointer
    pusha

    mov cx, [bp + 4]        ; x coordinate
    mov dx, [bp + 6]        ; y coordinate
    
                            ; Initializing to 0, saves one byte from using mov
    xor si, si              ; Index of the bit we are checking (width)
    xor di, di              ; How many bytes have we read

.row:                       ; Main loop, this will iterate over every bit of [rock]
  
    cmp si, 16              ; Check if we have to move to the next byte/row
    jne .same_row           ; We are still on the same row

                            ; This executes if we move to the next row
    xor si, si              ; Set the index of the bit to 0
    cmp di, 32              ; If we have read all the bytes (finished with the tile)
    je .done

    add di, 2               ; Next row/byte
    inc dx

    mov cx, [bp + 4]        ; Restore the x coordinate

.same_row:

    mov ax, [rock + di]    ; Get the Byte
    bt ax, si              ; Store the bit in position si on the carry flag (CF)
    jnc .pass              ; jnc = jump if no carry, a.k.a. if it is a 0

                           ; It is a 1, draw
    mov ah, 0Ch
    xor bh, bh             ; Page number 0
    mov al, 06h            ; Color brown
    int 10h

.pass:                     ; Increment the counters
    inc si
    inc cx
    jmp .row

.done:                     ; Restore the stack and return

    popa
    mov sp, bp
    pop bp
    ret 4

; Given a row, a column, a text and a length draws it to screen
;
;   - [bp + 4]  message direction
;   - [bp + 6]  length of string
;   - [bp + 8]  row to put the string
;   - [bp + 10] column to put the string
;
print_text:

    push bp                ; Save old base pointer
    mov bp, sp             ; Use the current stack pointer as new base pointer
    pusha

    mov ax, 7c0h           ; Beginning of the code
    mov es, ax
    mov cx, [bp + 6]       ; Length of string
    mov dh, [bp + 8]       ; Row to put string
    mov dl, [bp + 10]      ; Column to put string
    mov bp, [bp + 4]       

    mov ah, 13h            ; Function 13 - write string
    mov al, 01h            ; Attrib in bl, move cursor
    mov bl, 0Fh            ; Color white

    int 10h

                           ; Restore the stack and return
    popa
    mov sp, bp
    pop bp

    ret 8

; Store the drive addres given by the BIOS
bootdrv: db 0              

; Data
msg1:    db "IT'S DANGEROUS TO GO"
msg2:    db "ALONE!   TAKE ME."
rock:    dw 0xC3B7, 0xDFCF, 0xFFCF, 0x7FCF, 0x7FE6, 0xFFEF, 0xBFEF, 0xBFEF, 0x7FE7, 0xFFEF, 0x7DE7, 0x3C9B, 0x7DFD, 0xBC7D, 0xFCFF, 0x2CFC ; 32 bytes

; The first sector MUST be 512 bytes and the last 2 bytes have to be 0xAA55 for it
; to be bootable
times 510 - ($ - $$) db 0   ; Padding with 0 at the end
dw 0xAA55                   ; PC boot signature


stage2:

    ; So apparently I was unable to pass the memory address of the current sprite as an argument
    ; so I copy it to a new memory location and execute from there

    ; Copy the current sprite
    mov      cx, 32               ; How many bytes
    lea      di, [current_sprite] ; To where
    lea      si, [wiseman_left]   ; From where
    rep      movsb

    push 32                       ; How many bytes the sprite has
    push 06h                      ; First color, brown
    push 04h                      ; Second color, red
    push 90                       ; y coordinate
    push 152                      ; x coordinate
    call draw_sprite

    ; Copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [wiseman_right]
    rep      movsb

    ; Now, the trick that saved most bytes (and the project) is to reuse the values stored in the stack
    ; between sprites. So I reuse coordinates and sprite size. When the draw_sprite returns it DOES NOT
    ; pop all the arguments, only the x coordinate

    push 160                      ; x coordinate
    call draw_sprite

    ; Copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [fire_left]
    rep      movsb

    ; We need to change the colors, therefore we need to pop them
    pop si
    pop si
    pop si



    ; We draw the two left parts of the fire to reuse the stack
    push 0Eh                      ; First color, yellow
    push 0Ch                      ; Second color, light red
    push 90                       ; y coordinate
    push 80                       ; x coordinate
    call draw_sprite


    push 224                      ; x coordinate
    call draw_sprite

    ; Copy the current sprite
    mov      cx, 32
    lea      di, [current_sprite]
    lea      si, [fire_right]
    rep      movsb

    ; Same y, same colors
    push 88                       ; x coordinate
    call draw_sprite

    push 232                      ; x coordinate
    call draw_sprite

    ; Copy the current sprite
    mov      cx, 44               ; This one is 44 bytes instead of 32         
    lea      di, [current_sprite]
    lea      si, [gef_left]
    rep      movsb

    ; Delete the arguments on the stack
    pop si
    pop si
    pop si
    pop si

    push 44                      ; How many bytes the sprite has
    push 07h                     ; First color, gray
    push 06h                     ; Second color, brown
    push 120                     ; y coordinate
    push 152                     ; x coordinate
    call draw_sprite

    ; Copy the current sprite
    mov      cx, 44
    lea      di, [current_sprite]
    lea      si, [gef_right]
    rep      movsb

    push 160                     ; x coordinate
    call draw_sprite

   cli
   hlt

; This function is in charge of drawing a sprite, the sprite MUST be 16 pixels wide
; but can be as high as necessary. Note that the coordinates are for the top-left corner
;
; The sprites are encoded as following:
;
;    - Each sprite has a maximum of 4 colors
;    - Each pixel is encoded in 2 bits
;    - 00 is always black
;    - 11 is always white
;    - 01 is the first color
;    - 10 is the second color
;
; Parameters:
;    
;    - [bp + 4]         x coordinate
;    - [bp + 6]         y coordinate
;    - [bp + 8]         Second color
;    - [bp + 10]        First color
;    - [bp + 12]        How many bytes/rows the sprite has
;    - [current_sprite] The sprite 
;
draw_sprite:

    push bp                 ; Save old base pointer
    mov bp, sp              ; Use the current stack pointer as new base pointer
    pusha

    mov cx, [bp + 4]        ; x coordinate
    mov dx, [bp + 6]        ; y coordinate
    
                            ; Initializing to 0, saves one byte from using mov
    xor si, si              ; Index of the bit we are checking (width)
    xor di, di              ; How many bytes we have checked

.row:                       ; Main loop, we get 2 bits at a time to check the color
  
    cmp si, 16              ; Check if we have to move to the next byte/row
    jne .same_row           ; Same byte

                            ; This executes if we move to the next row
    xor si, si              ; Start from 0
    add di, 2               ; Next row/byte
    cmp di, [bp + 12]       ; If we have checked all bytes
    je .done
                            ; Increment byte and x coordinate 
    inc dx
    mov cx, [bp + 4]        ; x coordinate

.same_row:

    xor bh, bh                    ; We will store the color index here

    mov ax, [current_sprite + di] ; Get the current byte

    bt ax, si                     ; First bit
    jnc .next_bit                 ; If it is 1 increment bh by one
    inc bh

.next_bit:

    inc si
    bt ax, si                     ; Second bit
    jnc .end_bit                  ; If it is 1 increment bh by two
    add bh, 2

.end_bit:
    cmp bh, 0                     ; If the color is 0 (black) we just don't draw anything
    je .pass

    mov ah, 0Ch                   ; Draw instruction

    cmp bh, 1                     ; Draw first color
    je .first_color

    cmp bh, 2                     ; Draw second color
    je .second_color

    jmp .white                    ; Draw white

.first_color:

    mov al, [bp + 10]             ; Set the first color
    jmp .draw

.second_color:

    mov al, [bp + 8]              ; Set the second color
    jmp .draw

.white:

    mov al, 0Fh                   ; Set white
    jmp .draw

.draw:
    xor bh, bh                    ; First page, funny note if you remove this instruction qemu will
                                  ; still execute but it won't work in real hardware
    int 10h

.pass:
                                  ; Increment indexes and move on
    inc si
    inc cx
    jmp .row

.done:

    popa
    mov sp, bp
    pop bp
    ret 2                         ; Only pop the y
    

current_sprite: dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,0x0000, 0x0000, 0x0000, 0x0000 ; 32 bytes       
fire_left:     dw 0x2020, 0x8020, 0x8800, 0xA810, 0xA880, 0xA288, 0xA6A8, 0xAAA2, 0x9AA2, 0x66AA, 0x55AA, 0x7568, 0xFD68, 0xF5A0, 0x56A0, 0xAA00 ; 32 bytes
fire_right:    dw 0x0808, 0x0802, 0x0022, 0x042A, 0x022A, 0x228A, 0x2A9A, 0x8AAA, 0x8AA6, 0xAA99, 0xAA55, 0x295D, 0x297F, 0x0A5F, 0x0A95, 0x00AA ; 32 bytes
wiseman_left:  dw 0x5400, 0x7700, 0x4500, 0x4500, 0x5E00, 0xFF80, 0x0FA0, 0xFBE8, 0xFAE9, 0xFAA9, 0xE8A9, 0xA8A8, 0xA8A8, 0xAA20, 0xAA00, 0x9680 ; 32 bytes
wiseman_right: dw 0x0015, 0x00dd, 0x0051, 0x0051, 0x00b5, 0x02ff, 0x0af0, 0x2bef, 0x6baf, 0x6aaf, 0x6a2b, 0x2a2a, 0x2a2a, 0x08aa, 0x00aa, 0x0296 ; 32 bytes
gef_left:      dw 0xAA00, 0xAA80, 0xAAA0, 0x88A8, 0x1818, 0x5158, 0x5558, 0x56A8, 0x5558, 0x5018, 0x5ED8, 0x5ED0, 0x9550, 0x65A0, 0x2A80, 0xBC00, 0x3F00, 0x33C0, 0x30F0, 0x3040, 0x0000, 0x2000 ; 44 bytes
gef_right:     dw 0x00aa, 0x02aa, 0x0aaa, 0x2a22, 0x2424, 0x2545, 0x2555, 0x2a95, 0x2555, 0x2405, 0x27b5, 0x07b5, 0x0556, 0x0a59, 0x02a8, 0x003e, 0x00fc, 0x03cc, 0x0f0c, 0x010c, 0x0000, 0x0008 ; 44 bytes

; The PDF header needs to be at most, here in 03FA (it must start at 1018 bytes) a lots of bytes were sacrified for this to work