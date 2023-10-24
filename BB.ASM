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


PROC movePaddle								;Compute movement of the paddles
			
;       Paddle movement
	checkPaddleMovement:
		mov ah, 01h
		int 16h
		jz exitPaddleMovement 				;jz -> Jump If Zero | so if no key jump to exit
		
		;check which key is being pressed (AL = ASCII character)
		mov ah, 00h
		int 16h
		
		;if it is '<--'  move left and '-->' move right
		cmp al, 4bh 						;'<--'
		je movePaddleLeft
		cmp al, 4dh							;'-->'
		je movePaddleRight 
		
		movePaddleLeft:
			mov ax, paddleVelocity
			sub paddleX, ax
			
			mov ax, 00h			
			cmp paddleX,ax
			jl paddleRigthOfBorder
			jmp exitPaddleMovement
			
			paddleRigthOfBorder:
				mov paddleX,ax
				jmp exitPaddleMovement
		
		movePaddleRight:
			mov ax,paddleVelocity
			add paddleX,ax
			
			mov ax, windowWidth				; has to change depending on how we draw paddle and testing
			sub ax,paddleWidth
			cmp paddleX,ax
			jg paddleLeftOfBorder
			jmp exitPaddleMovement
			
			paddleLeftOfBorder:
				mov paddleX,ax
				jmp exitPaddleMovement
	
	exitPaddleMovement:
	
		ret
	
MOVE_PADDLES ENDP



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
	ballX dw 00h
	ballY dw 00h
	ballVelocityX dw 05h               		;X (horizontal) velocity of the ball
	ballVelocityY dw 02h           			;Y (vertical) velocity of the ball
	
	; paddle constants	
	paddleWidth dw 19h                  	;default paddle width (25px)
	paddleHeigth dw 07h                		;default paddle height (7px)
	paddleVelocity dw 0Fh               	;default paddle velocity (15 px/100th sec  ??? excesive speed)	

	timeAux db 0                        	; Variable used when checking if the time has changed
	windowWidth dw 140h						; WindowWidth(320px in hex) 
	windowHeigth dw 0c8h					; WindowHeigth (200px in hex)

; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
