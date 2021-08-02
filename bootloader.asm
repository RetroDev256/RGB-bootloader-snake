BITS 16
ORG 0x7C0
setup_mode:				; Sets up 300x200 8 bd mode, and a custom palette!
	mov ax, 0x0013		; Set video mode to 320x200 8 bpp
	int 0x10			; Video address starts at 0xA0000, ends at 0xAF8C0
.grays:					; bx = color number
	mov dh, bl	; dh = red (6 bits)
	mov ch, bl	; ch = green (6 bits)
	mov cl, bl	; cl = blue (6 bits)
	call set_palette_value
	inc bl
	cmp bl, 64	; Make sure it loops for every value
	jl .grays
.hues:
	; Calculate appropriate 6 bit RGB triplet for hues in bl, and move as 6 bit RGB values to dh, ch, cl
	push bx
	sub bx, 64
	mov al, bl		; Move bx into ax register for division
	mov bh, 0x20	; Set to get 32 colors per 6 hue segments
	div bh			; Result is in AL, Modulus is in AH
	shl ah, 1		; Multiply Modulus for 6 bit (not 5 bit) colors
	mov dl, 0x3F
	sub dl, ah	; Reverse slope Modulus is now in dl
	xor bh, bh
	mov ch, ah
	xor cl, cl
	mov dh, 0x3F	; Prepare RGB for if Section one is selected
	cmp bx, 0x20
	jl .done
	mov ch, 0x3F
	mov dh, dl		; Prepare RGB for if Section two is selected
	cmp bx, 0x40
	jl .done
	xor dh, dh
	mov cl, ah		; Prepare RGB for if Section three is selected
	cmp bx, 0x60
	jl .done
	mov ch, dl
	mov cl, 0x3F	; Prepare RGB for if Section four is selected
	cmp bx, 0x80
	jl .done
	mov dh, ah
	xor ch, ch		; Prepare RGB for if Section five is selected
	cmp bx, 0xA0
	jl .done
	mov dh, 0x3F
	mov cl, dl		; Set RGB for section six
.done:					; End of 6 segment split, write end result to 
	pop bx
	call set_palette_value
	inc bl			; Complete loop through hue range
	jnz .hues

.game_start:
	xor bx, bx
.clear_buffer_loop:		; Clear screen buffer
	xor di, di
	mov ax, bx
	shr ax, 1
	mov si, 0x28
	xor dx, dx
	div si		;ax holds row, dx holds column
	cmp ax, 0
	je .wall
	cmp ax, 24
	je .wall
	cmp dx, 0
	je .wall
	cmp dx, 39
	je .wall
	jmp .empty_space
.wall:
	mov di, 63
.empty_space:
	mov [ebx + 0x9F830], word di
	inc bx
	inc bx
	cmp bx, 0x7D0
	jl .clear_buffer_loop

	mov [0xFA01], word 1000	; Snake starts in the middle of the screen
	mov [0xFA03], word 65	; Snake starts with a length of two
	call place_food
.game_loop:
	mov ax, word [0xFA01]		; Draw snake
	mov bx, word [0xFA03]
	mov [eax + 0x9F830], bx

.draw_block_buffer:
	xor ax, ax	; Use eax to hold the position of the screen buffer
.dbb_screen_loop:
	push ax
	mov si, 320
	xor dx, dx
	div si	; ax holds rows, dx holds columns
	shr ax, 3
	shr dx, 3
	mov di, dx
	mov si, 40
	mul si
	add ax, di
	shl ax, 1
	mov dx, [eax + 0x9F830]; TODO: make color loop
	cmp dx, 64
	jl .dbb_static_color
	mov ax, dx
	mov bx, 192
	xor dx, dx
	div bx
	add dx, 64
.dbb_static_color:
	pop ax
	mov [eax + 0xA0000], dl
	inc ax
	cmp ah, 0xFA
	jne .dbb_screen_loop

.decay_snake:
	cmp word [eax + 0x9F830], 0x40
	jl .static_item_decay
	dec word [eax + 0x9F830]
	cmp word [eax + 0x9F830], 0x40
	jge .static_item_decay
	mov [eax + 0x9F830], word 0
.static_item_decay:
	inc ax
	inc ax
	cmp ax, 0x7D0
	jne .decay_snake

	mov cx, 2
	xor dx, dx	; Sleep for 1/8 second
	mov ah, 0x86
	int 0x15

.check_keys:				; Checks for any key presses, updates snakes heading
	mov ah, 0x01     ; Any key pressed?
    int 0x16
    jz .nokey        ; No, go to main loop
    xor ax, ax
    int 0x16        ; Get key
	cmp ah, 0x48
	jne .nu_key
	cmp [0xFA00], byte 1	; Snake must also not be going down
	je .nd_key
	mov [0xFA00], byte 3
.nu_key:
	cmp ah, 0x50
	jne .nd_key
	cmp byte [0xFA00], 3	; Snake must also not be going up
	je .nr_key
	mov [0xFA00], byte 1
.nd_key:
	cmp ah, 0x4D
	jne .nr_key
	cmp byte [0xFA00], 2	; Snake must also not be going left
	je .nokey
	mov [0xFA00], byte 0
.nr_key:
	cmp ah, 0x4B
	jne .nokey
	cmp byte [0xFA00], 0	; Snake must also not be going right
	je .nokey
	mov [0xFA00], byte 2
.nokey:

	mov ax, word [0xFA01]		; Get snake position
	mov dl, byte [0xFA00]	; Get direction of snake, evaluate next position
	cmp dl, 1
	jge .not_right
	inc ax
	inc ax
	jmp .continue
.not_right:
	jg .not_down
	add ax, 0x50		; The snake is facing down
	jmp .continue
.not_down:
	cmp dl, 2
	jne .not_left
	dec ax
	dec ax
	jmp .continue
.not_left:
	sub ax, 0x50		; The snake is facing up
.continue:
	mov [0xFA01], word ax
	cmp [eax + 0x9F830], word 48	; Block must be food
	jne .no_food
	mov ax, [0xFA03]
	inc ax							; Increase length of snake
	mov [0xFA03], ax
	call place_food
	jmp .game_loop					; Skip death evaluation, because the block is food.
.no_food:				; The block which the snake advances to is not food
	mov ax, word [0xFA01]			; Evaluate any Death
	cmp [eax + 0x9F830], word 0	;	 Block must be empty
	jnz .game_start
	jmp .game_loop

place_food:
	xor ah, ah ; interrupts to get system time
	int 0x1A ; CX:DX now hold number of clock ticks since midnight
.loop:
	inc ax	; increase ax
	inc ax
	cmp ax, 1920	;if ax is over the limit, zero ax
	jl .ax_not_overflown
	xor ax, ax
.ax_not_overflown:
	cmp dx, 0
	jz .dx_zero
	dec dx	; decrement dx
	jmp .loop
.dx_zero:
	cmp [eax + 0x9F830], word 0
	jnz .loop
	mov [eax + 0x9F830], word 48
	ret
set_palette_value:
	mov ax, 0x1007
	int 0x10
	mov ax, 0x1010
	int 0x10
	ret

times 510-($-$$) db 0		;Pad remainder of boot sector with 0s
dw 0xAA55					;The standard PC boot signature