; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Blinder, Stijn Bettens
; date:		23/10/2018
; program:	Video mode 13h
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

; -------------------------------------------------------------------
CODESEG

; Set the video mode
PROC setVideoMode
	ARG @@mode:word
	USES eax
	
	mov ax, [@@mode]
	int 10h

	ret

ENDP setVideoMode

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

; ; Wait for a specific keystroke.
PROC waitForSpecificKeystroke
	USES eax
	press_check:
		mov ah, 01h
		int 16h
		jz press_check
		
		mov ah, 00h
		int 16h
		
		cmp al, 27		;27 is ASCII code for 'ESC'
		jne press_check
		
	mov ax, 03h
	int 10h
	
	ret
	
ENDP waitForSpecificKeystroke

; Terminate the program.
PROC terminateProcess
	USES eax
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

PROC main
	sti
	cld
	
	push ds
	pop	es

	call setVideoMode,13h

    ; Access variables from DATASEG and pass them as arguments to drawRectangle
    mov ax, Ball_X      ; Load Ball_X into ECX
    mov bx, Ball_Y      ; Load Ball_Y into EDX
    mov cx, Ball_size   ; Load Ball_size into ESI
	mov dx, cx
	
	sub cx, 1
	add dx, 3

    call drawRectangle, ax, bx, 2, 6, 63
	
	sub ax, 1
	add bx, 1
	add cx, 2
	sub dx, 2
	
	call drawRectangle, ax, bx, 4, 4, 63
	
	sub ax, 1
	add bx, 1
	add cx, 2
	sub dx, 2
	
	call drawRectangle, ax, bx, 6, 2, 63
	
	
	call waitForSpecificKeystroke, 001Bh ; keycode for ESC
	
	call terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
	Ball_X dw 160
	Ball_Y dw 100
	Ball_size dw 3
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
