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

PROC drawRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col: byte
	USES 	eax, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	mov eax, [@@y0]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [@@x0]

	; Compute top left corner address
	mov edi, VMEMADR
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [@@w]	; store width in edx for later reuse
	mov	ecx, edx
	mov	al,[@@col]
	rep stosb
	sub edi, edx		; reset edi to left-top corner
	
	; plot both vertical edges
	mov ecx,[@@h]
	@@vertLoop:
		mov	[edi],al		; left edge
		mov	[edi+edx-1],al	; right edge
		add	edi, SCRWIDTH
		loop @@vertLoop
	; edi should point at the bottom-left corner now
	sub edi, SCRWIDTH

	; Plot the bottom horizontal edge.
	mov	ecx, edx
	rep stosb
	ret
ENDP drawRectangle

PROC drawBall
	ARG @@x:dword, @@y:dword, @@size:dword
	USES eax, ebx, ecx, edx
	
	mov eax, [@@x]
	mov ebx, [@@y]
	mov ecx, [@@size]
	mov edx, ecx
	
	sub ecx, 1
	add edx, 3
	
	drawball:
		call drawRectangle, eax, ebx, ecx, edx, 15
		
		cmp ecx, 6
		je done
		
		sub eax, 1
		add ebx, 1
		add ecx, 2
		sub edx, 2
		
		jmp drawball

	done:
		ret

ENDP drawBall

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
    pop es

    call setVideoMode, 13h

    ; Use the variables from DATASEG as arguments
    call drawBall, [Ball_X], [Ball_Y], [Ball_size]


    call waitForSpecificKeystroke, 001Bh ; keycode for ESC

    call terminateProcess
ENDP main



; -------------------------------------------------------------------
DATASEG
	Ball_X dd 160
	Ball_Y dd 100
	Ball_size dd 3
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
