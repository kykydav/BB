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
	
PROC setVideoMode
	ARG @@mode:word
	USES eax
	
	mov ax, [@@mode]	; Executes configuration
	int 10h

	ret

ENDP setVideoMode
	

	
start:
     sti            ; set The Interrupt Flag => enable interrupts
     cld            ; clear The Direction Flag
	
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

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
