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

; Brick constants
Brick_Array_Rows EQU 2
Brick_Array_Columns EQU 40
Brick_Array_Total EQU Brick_Array_Rows * Brick_Array_Columns
	

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
	ARG @@col:word
	USES eax, ebx, ecx, edx

	mov eax, [Ball_X]
	mov ebx, [Ball_Y]
	mov ecx, [Ball_Size]
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

		call drawRectangle, [Paddle_X], [Paddle_Y], [Paddle_Width], [Paddle_Height], [@@col]

		ret

ENDP drawPaddle


PROC moveBall
	mov eax, [Ball_VX]
	add [Ball_X], eax			; Move in x Direction

	; Those collision teste need to be adjusted to the size of the ball
	mov eax, [Ball_Size]
	add eax, [Ball_Size]
	;add eax, [Ball_Size]
	cmp [Ball_X], eax
	jle negVelocityX			; If the ball hits left border, negate x velocity

	mov eax, [Window_Width]
	sub eax, [Ball_Size]
	sub eax, [Ball_Size]
	sub eax, [Ball_Size]

	cmp [Ball_X], eax
	jge negVelocityX			; If the ball hits right border, negate x velocity


	mov eax, [Ball_VY]
	add [Ball_Y], eax			; Move in y direction

	cmp [Ball_Y], 00h
	jle negVelocityY			; If the ball hits upper border, negate x velocity

	mov eax, [Window_Heigth]
	sub eax, [Ball_Size]
	
	cmp [Ball_Y], eax
	jge gameOver				; If the ball hits the lower border --> jump to gameOver

; Collision with bricks and paddle is done with AABB
	
	;condition 1 for collision	
	mov eax, [Ball_X]			
	add eax, [Ball_Size]		
	add eax, [Ball_Size]		;maxX1 >= minX2
	cmp eax, [Paddle_X]			;Ball_X + 2 * Ball_Size >= Paddle_X
	jl gridPanel  		;if there's no collision exit collision with paddle (jump if less)
	
	;condition 2 for collision
	mov eax, [Paddle_X]			
	add eax, [Paddle_Width]		;minX1 <= maxX2
	cmp [Ball_X], eax			;Ball_X <= Paddle_X + Paddle_Width
	jg gridPanel  		;if there's no collision exit collision with paddle (jump if greater)
	
	;condition 3 for collision
	mov eax, [Ball_Y]			
	add eax, [Ball_Size]		
	add eax, [Ball_Size]		;maxY1 >= minY2
	cmp eax, [Paddle_Y]			;Ball_Y + 2 * Ball_Size >= Paddle_Y
	jl gridPanel  			;if there's no collision exit collision with paddle (jump if less)
	
	;condition 4 for collision
	mov eax, [Paddle_Y]			
	add eax, [Paddle_Height]	;minY1 <= maxY2
	cmp [Ball_Y], eax			;Ball_Y <= Paddle_Y + Paddle_Height
	jg gridPanel  			;if there's no collision exit collision with paddle (jump if greater)
	
; Check where the ball hits the paddle
	
	mov eax, [Ball_Y]			
	add eax, [Ball_Size]		
	add eax, [Ball_Size]		;maxY1 >= minY2
	cmp eax, [Paddle_Y]			;Ball_Y + 2 * Ball_Size >= Paddle_Y
	jle negVelocityY    		; Jump if Ball's bottom edge < Paddle's top edge
	
; as you do not hit from above you certainly hit from a side so just negate x speed 	
	jmp negVelocityX		; not 100% sure its not worse but in theory should work 
	
	
; Brick Collision	
; split in 10 columns
	gridPanel:
		mov ecx, 0
		; determine wich column should be checked
		mov eax, [Ball_X]
		mov cx, 20h				; 32 px per column
		xor bx, bx
		div cx                   ; stores the column(0 based index), where Ball_X is in, in AX and in DX the rest (if 
		cmp dx, 16h				; if there are at least 22 px over. or less 7 then you have to respectively check the column after and the column before 
		jl indexColumn						; put another extre index to check
		inc dx
		push dx
		dec dx
		inc ecx
		indexColumn:
		push dx
		inc ecx
		;cmp dx, 07h				; actually don't think we need this because Ball_X is already the minimal x of the ball


		mov eax, [Ball_Y]
		mov cx, 15				; 15 px per row
		xor bx, bx
		div cx                   ; stores the row (0 based index), where Ball_Y is in, in AX and in DX the res
		cmp dx, 16h				; if there are at least 10 px over. or less 7 then you have to respectively check the column after and the column before
		jl indexRow						; put another extre index to check
		inc dx
		push dx
		dec dx
		inc ecx
		indexRow:
		push dx
		inc ecx

	checkBrickCollision:
		;condition 1 for collision	
		mov eax, [Ball_X]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]		;maxX1 >= minX2
		cmp eax, [Paddle_X]			;Ball_X + 2 * Ball_Size >= Paddle_X
		jl gridPanel  		;if there's no collision exit collision with paddle (jump if less)
		
		;condition 2 for collision
		mov eax, [Paddle_X]			
		add eax, [Paddle_Width]		;minX1 <= maxX2
		cmp [Ball_X], eax			;Ball_X <= Paddle_X + Paddle_Width
		jg gridPanel  		;if there's no collision exit collision with paddle (jump if greater)
		
		;condition 3 for collision
		mov eax, [Ball_Y]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]		;maxY1 >= minY2
		cmp eax, [Paddle_Y]			;Ball_Y + 2 * Ball_Size >= Paddle_Y
		jl gridPanel  			;if there's no collision exit collision with paddle (jump if less)
		
		;condition 4 for collision
		mov eax, [Paddle_Y]			
		add eax, [Paddle_Height]	;minY1 <= maxY2
		cmp [Ball_Y], eax			;Ball_Y <= Paddle_Y + Paddle_Height
		jg gridPanel  			;if there's no collision exit collision with paddle (jump if greater)
	
		
		
		
		
		
		loop checkBrickCollision
	
	
	
	;mov eax, [Ball_X]
	;cmp eax, A0h			; screenwidth/2 
	;jge rightScreen
	;cmp eax, 43h			; +- screenwidth/4 (43h=67) (splits such as it splits the blocks in collumns)
	;jge colums345
	;cmp eax, 24h
	
	endMoveBall:
	ret							; Needed otherwise go trough the rest of the procedure
	; is this needed as we have only one line --> Yes easier and actually you would have 2 lines the ret is important
	negVelocityY:
		neg [Ball_VY]   		; Reverse the vertical velocity of the ball
		ret
	negVelocityX:
		neg [Ball_VX]           ; Reverses the horizontal velocity of the ball
		ret
	gameOver:
		call terminateProcess
ENDP moveBall


PROC movePaddle					;Compute movement of the paddles

;       Paddle movement
	checkPaddleMovement:
		mov ah, 01h
		int 16h
		jz exitPaddleMovement 	;jz -> Jump If Zero | so if no key jump to exit

		;check which key is being pressed (AL = ASCII character)
		mov ah, 00h
		int 16h

		
		;if it is 's' or 'S'  move left and 'd' or 'D' move right
		cmp al, 73h 			; 's'
		je movePaddleLeft
		cmp al, 53h				; 'S'
		je movePaddleLeft
		
		cmp al, 64h				; 'd'
		je movePaddleRight
		cmp al, 44h				; 'D'
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

; Draws the differen levels of the bricks
PROC drawBricks
	; Arguments needed to make it more general for different arrays
    USES eax, ebx, ecx, edx
    
    mov esi, OFFSET Brick_Array
	mov edi, OFFSET Brick_Array_Color
	mov ecx, 0
    
    brickloop:
		
        mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]    ; x-coordinate
        mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]    ; y-coordinate 
        mov dx, [edi + ecx * 2]     							; color
        
        call drawRectangle, eax, ebx, [Brick_Width], [Brick_Height], dx
        
		inc ecx
		
        cmp ecx, Brick_Array_Columns   ;could also put initial value of ecx at Brick_Array_Total and dec ecx and loop brick loop is the same maybe easier to compute?
        jl brickloop
        
    ret

ENDP drawBricks



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
	;call drawBall, [Ball_X], [Ball_Y], [Ball_Size], [White]               			;draw the ball

		
	call drawBricks
	
	
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

		call drawBall, [Black]		;remove the ball
		call moveBall               								;move the ball
		call drawBall, [White]     ;draw the ball

		call drawPaddle, [Black]	;remove the paddle			
		call movePaddle            	;move the paddles (check for pressing of keys)
		call drawPaddle, [White]    ;draw the paddles with the updated positions

		jmp checkTime	;after everything checks time again

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
	Ball_VX dd 05h               			;X (horizontal) velocity of the ball (5px)
	Ball_VY dd 02h           				;Y (vertical) velocity of the ball (2px)

	; Ball constants
	Ball_Size dd 3

	;Paddle variables
	Paddle_X dd 160

	; paddle constants
	Paddle_Y dd 180
	Paddle_Width dd 28h                  	;default paddle width (25px)
	Paddle_Height dd 07h              		;default paddle height (7px)
	Paddle_V dd 0Fh               			;default paddle velocity (10 px/100th sec  ??? excesive speed)

	;Game Constatnt
	Last_Time db 0                        	; Variable used when checking if the time has changed
	Window_Width dd 140h					; Window_Width(320px in hex)
	Window_Heigth dd 0C8h					; Window_Heigth (200px in hex)
	Exit_Game db 0							; Exiting Boolean

	; colors
	Black dw 0
	White dw 15
	
	;Bricks
	
	Brick_Array 		dd 8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287	;x-coordinate bricks
						dd 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 						21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 			34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 			47, 47, 47, 47, 47, 47, 47, 47, 47, 47			;y-coordinate bricks
				
	Brick_Array_Color	dw 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,				2, 2, 2, 2, 2, 2, 2, 2, 2, 2,						3, 3, 3, 3, 3, 3, 3, 3, 3, 3,						4, 4, 4, 4, 4, 4, 4, 4, 4, 4					;health and color
	
	Brick_Width dd 25
	Brick_Height dd 7
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
