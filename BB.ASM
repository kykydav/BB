; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Artyom Petrosyan, Kyan David
; date:		24/10/2023
; program:	Brick Breaker game
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG
	
start:
     sti            ; set The Interrupt Flag => enable interrupts
     cld            ; clear The Direction Flag

PROC setVideoMode
	ARG @@mode:word
	USES eax
	
	mov ax, [@@mode]	; Executes configuration
	int 10h
	
	mov ax, VMEMADR
	mov es, ax

	ret

ENDP setVideoMode

;; Draw Ball
PROC drawBall
	USES ebx, ecx, edx
	
	mov cx, [Ball_X]	; Initialize ball x-coordinate to cx
	mov cy, [Ball_Y]	; Initialize ball y-coordinate to cy
	mov r, [Ball_rad]	; Initialize ball radius to r
	
	; Looping trough each pixel
	mov dx, 2 * r	; Initialize dy to diameter
	xor bx, bx		; Initialize bx to 0
	
	Row:
		push cx			; Save cx to STACK
		mov dl, 2 * r	; Initialize dx to diameter
		xor di, di		; Initialize di to 0
		
	DrawPixelRow:
		mov [es:bx + di], al	; Set pixel color
		inc di					; Move to next pixel
		dec dl					; decrease dx
		
		jnz DrawPixelRow		; Continue drawing while not zero
		
		pop cx		; Restore cx from STACK
		add cx, 320	; Move to the next Row
		sub cy, 1	; Move up by 1 pixel
		add bx, 320	; Move to the next row in memory
		
		dec dx		; Decrease dy
		jnz Row:	; Continue drawing rows
		
	ret
	
ENDP drawBall
		


; ; Draw a rectangle (video mode 13h)
PROC drawRectangle
	ARG @@x0:word, @@y0:word, @@w:word, @@h:word, @@color:byte
	USES edi, ecx, eax, edx
	
	movzx eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add ax, [@@x0]
	
	mov edi, VMEMADR
	add edi, eax
	
	movzx edx, [@@w]
	mov ecx, edx
	mov al, [@@color]
	rep stosb
	sub edi, edx
	
	movzx ecx, [@@h]
	verticalloop:
		mov [edi], al
		mov [edi + edx - 1], al
		add edi, SCRWIDTH
		loop verticalloop
		
	sub edi, SCRWIDTH
	
	mov ecx, edx
	rep stosb
	
	ret
	
ENDP drawRectangle
	
PROC main

	call setVideoMode, 13
	call drawBall
	
	ret
	

ENDP main


	; next lines of code are superfluous as black is default background
	mov ah, 0bh ; set configuration 
	mov bh, 00h ; to the background color
	mov bl, 00h ; choose black as background: https://en.wikipedia.org/wiki/BIOS_color_attributes 
	int 10h		; execute configuration

	; following lines of code draw a pixel at 10,
	mov ah, 0ch ; set the configuration to writing a pixel
	mov al, 0Fh ; choose white as color:
	mov bh, 00h ; set the page number
	mov cx, 0ah ; set the column (x)
	mov dx, 0Ah ; set the line (y) 
	int 10h 	; execute the config
	
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG

	Ball_X dw 00h	; X position Ball
	Ball_Y dw 00h	; Y position Ball
	Ball_size dw 3	; Ball radius

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
