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
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@col:byte   ; col = 15 is white
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
	mov	al, [@@col]
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
	ARG @@x:dword, @@y:dword, @@size:dword, @@col:word
	USES eax, ebx, ecx, edx

	mov eax, [@@x]
	mov ebx, [@@y]
	mov ecx, [@@size]
	mov edx, ecx

	sub ecx, 1
	add edx, 3

	drawball:
		call drawRectangle, eax, ebx, ecx, edx, [@@col]

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

PROC drawPaddle
		ARG @@col:word

		call drawRectangle, [Paddle_X], [Paddle_Y], [Paddle_Width], [Paddle_Heigtht], [@@col]

		ret

ENDP drawPaddle




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




PROC moveBall
	mov eax, [Ball_VX]
	add [Ball_X], eax							; Move in x Direction

	; Those collision teste need to be adjusted to the size of the ball
	cmp [Ball_X], 00h
	jle negVelocityX							; If the ball hits left border, negate x velocity

	mov eax, [Window_Width]
	sub eax, [Ball_Size]
	sub eax, [Ball_Size]

	cmp [Ball_X], eax
	jge negVelocityX							; If the ball hits right border, negate x velocity


	mov eax, [Ball_VY]
	add [Ball_Y], eax							; Move in y direction

	cmp [Ball_Y], 00h
	jle negVelocityY							; If the ball hits upper border, negate x velocity

	mov eax, [Window_Heigth]
	sub eax, [Ball_Size]
	
	cmp [Ball_Y], eax
	jge gameOver							; If the ball hits the lower border --> jump to gameOver

	ret										; Needed otherwise go trough the rest of the procedure

	; is this needed as we have only one line
	negVelocityY:
		neg [Ball_VY]   				; Reverse the vertical velocity of the ball
		ret
	negVelocityX:
		neg [Ball_VX]              		; Reverses the horizontal velocity of the ball
		ret
	gameOver:
		call terminateProcess
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

		
		;if it is 's' or 'S'  move left and 'd' or 'D' move right
		cmp al, 73h 		; 's'
		je movePaddleLeft
		cmp al, 53h			; 'S'
		je movePaddleLeft
		
		cmp al, 64h			; 'd'
		je movePaddleRight
		cmp al, 44h			; 'D'
		je movePaddleRight
		
		ret
		
		movePaddleLeft:
			mov eax, [Paddle_V]
			sub [Paddle_X], eax

			xor eax, eax
			cmp [Paddle_X], eax
			jl paddleRightOfBorder
			jmp exitPaddleMovement

			paddleRightOfBorder:
				mov [Paddle_X], eax
				jmp exitPaddleMovement

		movePaddleRight:
			mov eax, [Paddle_V]
			add [Paddle_X], eax

			mov eax, [Window_Width]				; has to change depending on how we draw paddle and testing
			sub eax, [Paddle_Width]
			cmp [Paddle_X], eax
			jg paddleLeftOfBorder
			jmp exitPaddleMovement

			paddleLeftOfBorder:
				mov [Paddle_X], eax
				jmp exitPaddleMovement

	exitPaddleMovement:

		ret

ENDP movePaddle





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
	;call drawBall, [Ball_X], [Ball_Y], [Ball_Size], [White]               			;draw the ball




	checkTime:                      			;time checking loop
		;mov ah, 01h
		;int 16h

		;mov ah, 00h
		;int 16h

		;cmp al, 27		;27 is ASCII code for 'ESC'
		;je exitGame

		mov ah,2Ch 								;get the system time
		int 21h    								;ch = hour cl = minute dh = second dl = 1/100 seconds

		cmp dl, [Last_Time]  					;is the current time equal to the previous one(Last_Time)?
		je checkTime    		    			;if it is the same, check again

		;If it reaches this point, it's because the time has passed (more than 1 100th of a second (clock resolution)

		mov [Last_Time], dl              		;update time

		call drawBall, [Ball_X], [Ball_Y], [Ball_Size], [Black]
		call moveBall               			;move the ball
		call drawBall, [Ball_X], [Ball_Y], [Ball_Size], [White]               			;draw the ball

		call drawPaddle, [Black]
		call movePaddle            				;move the paddles (check for pressing of keys)
		call drawPaddle, [White]          			;draw the paddles with the updated positions

		jmp checkTime               			;after everything checks time again

		;call all update functions

    ;call waitForSpecificKeystroke, 001Bh 		; keycode for ESC
	exitGame:
		call terminateProcess

ENDP main



; -------------------------------------------------------------------
DATASEG
	; Ball variables
	Ball_X dd 160
	Ball_Y dd 100
	; The speed is constant in magnitude but they are not constants as they vary in sign.	
	Ball_VX dd 05h               			;X (horizontal) velocity of the ball
	Ball_VY dd 02h           				;Y (vertical) velocity of the ball


	; Ball constants
	Ball_Size dd 3

	;Paddle variables
	Paddle_X dd 160

	; paddle constants
	Paddle_Y dd 180
	Paddle_Width dd 19h                  	;default paddle width (25px)
	Paddle_Heigtht dd 07h              		;default paddle height (7px)
	Paddle_V dd 0Fh               			;default paddle velocity (10 px/100th sec  ??? excesive speed)

	;Game Constatnt
	Last_Time db 0                        	; Variable used when checking if the time has changed
	Window_Width dd 140h					; Window_Width(320px in hex)
	Window_Heigth dd 0C8h					; Window_Heigth (200px in hex)
	Exit_Game db 0							; Exiting Boolean

	; colors
	Black dw 0
	White dw 15
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
