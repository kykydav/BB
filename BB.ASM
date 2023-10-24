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


PROC main
	CHECK_TIME:                      ;time checking loop
		
		MOV AH,2Ch 					 ;get the system time
		INT 21h    					 ;CH = hour CL = minute DH = second DL = 1/100 seconds
		
		CMP DL,TIME_AUX  			 ;is the current time equal to the previous one(TIME_AUX)?
		JE CHECK_TIME    		     ;if it is the same, check again
		
;           If it reaches this point, it's because the time has passed

		MOV TIME_AUX,DL              ;update time
		
		;CALL all update functions
		
	RET		
ENDP main






PROC setVideoMode
	ARG @@mode:word
	USES eax
	
	mov ax, [@@mode]	; Executes configuration
	int 10h

	ret

ENDP setVideoMode
	
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
