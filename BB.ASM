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
Brick_Array_Columns EQU 41
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
		USES eax, ebx, ecx
		
		mov ecx, 0
		
		mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]    ; x-coordinate Paddle
        mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]    ; y-coordinate Paddle
		
		call drawRectangle, eax, ebx, [Paddle_Width], [Paddle_Height], [@@col]

		ret

ENDP drawPaddle


PROC moveBall
	USES eax, ebx, ecx, edx
	mov eax, [Ball_VX]
	add [Ball_X], eax			; Move in x Direction

	; Those collision teste need to be adjusted to the size of the ball
	mov eax, [Ball_Size]
	add eax, [Ball_Size]
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

; Brick Collision	
; split in 10 columns
	gridPanel:
		; determine wich column should be checked
		mov eax, [Ball_X]
		add eax, [Ball_Size]	; calculate the x-coordinate of the center of the ball
		sub eax, 5				; 5 px offset from both sides of the frame (grid with is 310 in stead of 320)
		mov ebx, 1Fh			; 31 px per column tting
		xor edx, edx
		div ebx                 ; stores the column (0 based index), where Ball_X is in, in eax and in edx the rest
		
		push eax				; store column index in stack
		
		mov eax, [Ball_Y]
		add eax, [Ball_Size]	; calculate the y-coordinate of the center of the ball
		sub eax, 5				; 5 px offset from both sides of the frame (grid with is 169 in stead of 200)
		mov ebx, 0Dh			; 13 px per column
		xor edx, edx
		div ebx					; stores the row (0 based index), where Ball_Y is in, in eax and in edx the rest

		pop ebx	

		cmp [Ball_Y], 174
		jle brickCollision
		
						; restores column index in ebx
		
; Collision with bricks and paddle is done with AABB
	
	paddleColision:
		xor ecx, ecx			; Set the value for ecx to 1 so that the collisionCheck only loops once 
		mov ebx, [Paddle_Width]
		mov edx, [Paddle_Height]
		
		jmp collisionCheck		; Jump to collisionCheck to check the collision with the paddle
		
	brickCollision:
		mov ecx, 10
		imul ecx
		mov ecx, eax
		add ecx, ebx
		add ecx, 1
		mov ebx, [Brick_Width]
		mov edx, [Brick_Height]
		
		jmp collisionCheck
		
	collisionCheck:
		
		;condition 1 for collision	
		mov eax, [Ball_X]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]									;maxX1 >= minX2
		cmp eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]	;Ball_X + 2 * Ball_Size >= block_X
		jl endMoveBall  										;if there's no collision exit collision with block (jump if less)
		
		;condition 2 for collision
		mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]	;initialize block_X in eax
		add eax, ebx											;minX1 <= maxX2
		cmp [Ball_X], eax										;Ball_X <= block_X + block_Width
		 												
		jg endMoveBall  										;if there's no collision exit collision with block (jump if greater)
		
		;condition 3 for collision
		mov eax, [Ball_Y]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]									;maxY1 >= minY2
		cmp eax, [esi + (1 * Brick_Array_Columns + ecx) * 4]	;Ball_Y + 2 * Ball_Size >= block_Y
		jl endMoveBall  										;if there's no collision exit collision with block (jump if less)
		
		;condition 4 for collision
		mov eax, [esi + (1 * Brick_Array_Columns + ecx) * 4]	;initialize block_Y in eax		
		add eax, edx											;minY1 <= maxY2
		cmp [Ball_Y], eax										;Ball_Y <= block_Y + block_Height
		 												
		jg endMoveBall  										;if there's no collision exit collision with block (jump if greater)
		
		
		; de twee volgende lijnen laten het crashen
		push edx							;Stores Brick_Height
		push ebx							;Stores Brick_Width
		
		
		; Check where the ball hits the top of the blok
		
		
		; mov eax, [Ball_Size]
		; mov ebx, 02h		
		; xor edx, edx
		; div ebx 				;Store in eax Ball_Size/2
		
		;we assume that it is not possible to hit a side that point in the direction of V
		; (so if VY < 0 then can't hit the top side) 	
		cmp [Ball_VY], 0
		jl cannotHitTop
			; cannot hit bottom 
			; check if intersect with top if not it intersects with side
			; s1 = (Ball_Y+2*Ball_Size - Block_Y)*(Block_X+Block_Width - Block_X) - (Block_Y -Block_Y)*((Ball_X+Ball_Size - Block_X)
			; s2 = (Ball_Y - Ball_VY - Block_Y)*(Block_X+Block_Width - Block_X) - (Block_Y -Block_Y)*((Ball_X - Ball_VX - Block_X)
			; If s1 > 0 and S1 == s2 --> no intersect
			
			;s1
			mov edx, [Ball_Y]
			add edx, [Ball_Size]
			add edx, [Ball_Size]									;add 2 times size (radius) to make sure the coordinates are complitely passed the linesegment
			mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]
			sub edx, ebx
			mov ebx, [esp]
			imul edx, ebx 
			cmp eax, 0
			jg hitSide
			;s2
			mov ecx, [Ball_Y]
			sub ecx, [Ball_VY]								;add 2 times size (radius) to make sure the coordinates are complitely passed the linesegment
			mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]
			sub ecx, ebx
			mov ebx, [esp]
			imul ecx, ebx 
			cmp eax, edx
			je hitSide
			; From here on it intersects with top 
			jmp negVelocityYBox
		
		cannotHitTop:
		; cannot hit top so check if hits bottom if not hits side
		; check if intersect with bottom if not it intersects with right
		; s1 = (Ball_Y+2*Ball_Size - (Block_Y + Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth -(Block_Y + Block_Heigth))*((Ball_X+Ball_Size - Block_X)
		; s2 = (Ball_Y - Ball_VY - (Block_Y+ Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth - (Block_Y + Block_Heigth))*((Ball_X - Ball_VX - Block_X)
		; If s1 > 0 and S1 == s2 --> no intersect
		
			;s1
			mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]
			mov edx, [esp]
			add ebx, edx
			mov edx, [Ball_Y]
			add edx, [Ball_Size]
			add edx, [Ball_Size]									;add 2 times size (radius) to make sure the coordinates are complitely passed the linesegment
			sub edx, ebx
			mov ebx, [esp]
			imul edx, ebx 
			cmp edx, 0
			jg hitSide
			
			
			;s2
			mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]
			mov edx, [esp-4]
			add ebx, ecx											;registers to store the top 2 layers of the stack
			mov ecx, [Ball_Y]
			sub ecx, [Ball_VY]								;add 2 times size (radius) to make sure the coordinates are complitely passed the linesegment
			sub ecx, ebx
			mov ebx, [esp]
			imul ecx, ebx 
			
			cmp edx, ecx
			je hitSide
			jmp negVelocityYBox
			
		hitSide:
			cmp [Ball_VX], 0
			jl hitRight										; The differentiation is not needed
			;hitLeft
			jmp negVelocityXBox
			hitRight:
			jmp negVelocityXBox
			; From here on it intersects with top 
			
		jmp return ; useless
	; is this needed as we have only one line --> Yes easier and actually you would have 2 lines the ret is important
	negVelocityYBox:
	pop eax
	pop eax
	jmp negVelocityY
	negVelocityXBox:
	pop eax
	pop eax
	jmp negVelocityX
	
	negVelocityY:
		neg [Ball_VY]   		; Reverse the vertical velocity of the ball
		jmp return
	negVelocityX:
		neg [Ball_VX]           ; Reverses the horizontal velocity of the ball
		jmp return
	endMoveBall:
		jmp return							; Needed otherwise go trough the rest of the procedure
	gameOver:
		call terminateProcess			; pop pop is needed if not terminate in future
	return:
	;popAll:
	;cmp esp, ebp
	;je return2
	;pop eax
	;jmp popAll
	;return2:
	ret
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
			sub [esi], eax
			
			xor eax, eax
			cmp [esi], eax
			jl paddleRightOfBorder
			jmp exitPaddleMovement

			paddleRightOfBorder:
				mov [esi], eax
				jmp exitPaddleMovement

		movePaddleRight:
			mov eax, [Paddle_V]
			add [esi], eax

			mov eax, [Window_Width]				; has to change depending on how we draw paddle and testing
			sub eax, [Paddle_Width]
			cmp [esi], eax
			jg paddleLeftOfBorder
			jmp exitPaddleMovement

			paddleLeftOfBorder:
				mov [esi], eax
				jmp exitPaddleMovement

	exitPaddleMovement:

		ret

ENDP movePaddle

; Draws the differen levels of the bricks
PROC drawBricks
    USES eax, ebx, ecx, edx, edi
    
	mov edi, OFFSET Brick_Array_Color
	mov ecx, 1
    
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
	
	mov esi, offset Brick_Array
		
	call drawBricks, 25, 7	; Width and Height as arguments

	checkTime:                      			;time checking loop
		; mov ah, 01h
		; int 16h

		; mov ah, 00h
		; int 16h

		; cmp al, 27		;27 is ASCII code for 'ESC'
		; je exitGame

		mov ah,2Ch 								;get the system time
		int 21h    								;ch = hour cl = minute dh = second dl = 1/100 seconds

		cmp dl, [Last_Time]  					;is the current time equal to the previous one(Last_Time)?
		je checkTime    		    			;if it is the same, check again

		;If it reaches this point, it's because the time has passed (more than 1 100th of a second (clock resolution))

		mov [Last_Time], dl              		;update time

		call drawBall, [Black]		;remove the ball
		call moveBall               ;move the ball
		call drawBall, [White]      ;draw the ball

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
	Ball_VY dd -02           				;Y (vertical) velocity of the ball (2px)

	; Ball constants
	Ball_Size dd 3

	;Paddle variables
	; Paddle_X dd 160

	; paddle constants
	; Paddle_Y dd 180
	Paddle_Width dd 25                  	;default paddle width (25px)
	Paddle_Height dd 7              		;default paddle height (7px)
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
	
	d_ratio dd 0
	d_hor dd 0
	d_vert dd 0
	
	Brick_Array 		dd 160, 	8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287, 		8, 39, 70, 101, 132, 163, 194, 225, 256, 287	;x-coordinate bricks (first column is for Paddle_X)
						dd 180, 	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 						21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 			34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 			47, 47, 47, 47, 47, 47, 47, 47, 47, 47			;y-coordinate bricks (first column is for Paddle_Y)
				
	Brick_Array_Color	dw 15, 		15, 15, 15, 15, 15, 15, 15, 15, 15, 15,				2, 2, 2, 2, 2, 2, 2, 2, 2, 2,						3, 3, 3, 3, 3, 3, 3, 3, 3, 3,						4, 4, 4, 4, 4, 4, 4, 4, 4, 4					;health and color
	
	Brick_Width dd 25
	Brick_Height dd 7
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
