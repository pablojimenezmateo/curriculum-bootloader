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


    ;call print_pixel

    call print_text_1

    call print_text_2

    ;call draw_square

    call draw_border

    cli ; stop execution
    hlt

; ----------------------------------------------------------------------

draw_border:

    ; top border
    ; x from 0 to 304 in increments of 16 (19 times)

    mov si, 0

.top_border:

    push 0                  ; initial y position to draw the rock
    push si                 ; initial x position to draw the rock
    call draw_rock_tile

    add si, 16

    cmp si, 320
    je .left_border_init

    jmp .top_border

.left_border_init:

    mov si, 16

.left_border:

    push si                  ; initial y position to draw the rock
    push 0                 ; initial x position to draw the rock
    call draw_rock_tile  

    add si, 16

    cmp si, 192
    je .right_border_init

    jmp .left_border

.right_border_init:

    mov si, 16

.right_border:

    push si                  ; initial y position to draw the rock
    push 304                 ; initial x position to draw the rock
    call draw_rock_tile  

    add si, 16

    cmp si, 192
    je .bottom_border_left_init

    jmp .right_border

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

print_pixel:

    ; drawing random pixels

    mov ah, 0Ch             ; change color for a single pixel

    mov al, 0000b           ; color
    mov bh, 0               ; page number
    mov cx, 30              ; x
    mov dx, 100             ; y

    int 10h                 ; paint 1st pixel

.repeat:

    inc al                  ; change color
    inc cx                  ; go one pixel right
    inc dx                  ; go one pixel down

    int 10h                 ; paint

    cmp al, 1111b
    je .done                ; last color was painted

    jmp .repeat

.done:   
    ret

draw_square:

    mov ah, 0Ch             ; change color for a single pixel

    mov al, 0ah             ; color
    mov bh, 0               ; page number
    mov cx, 80             ; x
    mov dx, 30             ; y

.row:

    int 10h                 ; paint

    inc cx                  ; go one pixel right

    cmp cx, 96          ; 16 px width
    je .nextrow             ; paint next row


    jmp .row

.nextrow:

    mov cx, 80
    inc dx                  ; go one pixel down

    cmp dx, 62             ;32 px high
    je .done

    jmp .row


.done:   
    ret

draw_rock_tile:

    push bp                ; save old base pointer
    mov bp, sp             ; use the current stack pointer as new base pointer
    pusha

    mov ah, 0Ch
    mov bh, 0              ; page number

    mov cx, [bp + 4]       ; first argument
    mov dx, [bp + 6]       ; second argument
    push cx                ; we need to store the x value for .next_row

    mov si, 0              ; index of the bit we are checking (width)
    mov di, 0              ; index of the bit we are checking (height)

.row: ; main loop, this will iterate over every bit of [rock], if it is a 1 the .one part will be executed, if it is a 0 the .zero part will
    
    cmp si, 16 ; width of the rock
    je .next_row

    cmp di, 32 ;32 bytes
    je .done

    push dx
    mov dx, [rock + di]    ; load the bitpattern
    bt dx, si      ; check the si th bit and store it on cf
    pop dx

    jc .one
    jmp .zero

.one:

    mov al, 06h       ; color brown
    int 10h

    inc si
    inc cx

    jmp .row

.zero:

    mov al, 00h       ; color black
    int 10h

    inc si
    inc cx

    jmp .row

.next_row:

    add di, 2  ; next byte
    mov si, 0  ; firs bit
    inc dx     ; next row
    ;mov cx, 0  ; first row
    pop cx
    push cx

    jmp .row


.done:
    pop cx
    popa
    mov sp, bp
    pop bp
    ret 4

print_text_1:

    mov ax, 7c0h        ; beginning of the code
    mov es, ax
    mov bp, msg1
    mov ah,13h          ; function 13 - write string
    mov al,01h          ; attrib in bl, move cursor
    mov bl,0Fh          ; color white
    mov bh, 0
    mov cx,20           ; length of string
    mov dh,5            ; row to put string
    mov dl,9            ; column to put string
    int 10h             ; call BIOS service
    ret

print_text_2:

    mov ax, 7c0h        ; beginning of the code
    mov es, ax
    mov bp, msg2
    mov ah,13h          ; function 13 - write string
    mov al,01h          ; attrib in bl, move cursor
    mov bl,0Fh          ; color white
    mov bh, 0
    mov cx,17           ; length of string
    mov dh,6            ; row to put string
    mov dl,11            ; column to put string
    int 10h             ; call BIOS service
    ret

msg1: db "IT'S DANGEROUS TO GO"
msg2: db "ALONE!   HIRE ME."
rock: dw 0xEDC3, 0xF3FB, 0xF3FF, 0xF3FE, 0x67FE, 0xF7FF, 0xF7FD, 0xF7FD, 0xE7FE, 0xF7FF, 0xE7BE, 0xD93C, 0xBFBE, 0xBE3D, 0xFF3F, 0x3F34 ; 32 bytes

times 510 - ($ - $$) db 0   ; padding with 0 at the end
dw 0xAA55                   ; PC boot signature