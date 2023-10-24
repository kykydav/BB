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

PROC moveBall
	mov ax, ballVelocityX
	add ballX, ax							; Move in x Direction

	; Those collision teste need to be adjusted to the size of the ball
	cmp ballX, 00h					
	jle negVelocityX							; If the ball hits left border, negate x velocity
	
	mov ax, windowWidth
	cmp ballX, ax
	jge negVelocityX							; If the ball hits right border, negate x velocity


	mov ax, ballVelocityY
	add ballY, ax							; Move in y direction
	
	cmp ballY, 00h
	jle negVelocityY							; If the ball hits upper border, negate x velocity

	;mov ax, windowHeigth
	;cmp ballY, ax							
	;jge gameOver							; If the ball hits the lower border --> jump to gameOver
	
	
	; is this needed as we have only one line
	negVelocityY:
		neg ballVelocityY   				; Reverse the vertical velocity of the ball 
		ret
	negVelocityX:
		neg ballVelocityX              		; Reverses the horizontal velocity of the ball
		ret                   

ENDP moveBall
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


	; Ball variables
	ballX
	ballY
	ballVelocityX 
	ballVelocityY
	



	timeAux db 0                        	; Variable used when checking if the time has changed
	windowWidth dw 140h						; WindowWidth(320px in hex) 
	windowHeigth dw 0c8h					; WindowHeigth (200px in hex)

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
