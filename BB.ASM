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
     sti            						; set The Interrupt Flag => enable interrupts
     cld            						; clear The Direction Flag


PROC main
	checkTime:                      		;time checking loop
		
		mov ah,2Ch 							;get the system time
		int 21h    							;ch = hour cl = minute dh = second dl = 1/100 seconds
		
		cmp dl,timeAux  					;is the current time equal to the previous one(timeAux)?
		je checkTime    		    		;if it is the same, check again
		
;           If it reaches this point, it's because the time has passed

		mov timeAux,dl              		;update time
		
		;CALL all update functions
		
	ret		
ENDP main






PROC setVideoMode
	ARG @@mode:word
	USES eax
	
	mov ax, [@@mode]						; Executes configuration
	int 10h

	ret

ENDP setVideoMode
	
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG

	timeAux db 0                        	;variable used when checking if the time has changed


; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
