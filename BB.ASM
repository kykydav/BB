; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Kyan, Petrosyan Artyom
; date:		19/10/2023
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
; @@ is not needed and then you can even use just the name in the procedure
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
		ARG @@Brick_Array:dword, @@col:word
		USES eax, ebx, ecx
		
		mov esi, [@@Brick_Array]
		xor ecx, ecx
		
		mov eax, [esi]    ; x-coordinate Paddle
        mov ebx, [esi + Brick_Array_Columns * 4]    ; y-coordinate Paddle
		
		call drawRectangle, eax, ebx, [Paddle_Width], [Paddle_Height], [@@col]

		ret

ENDP drawPaddle


PROC moveBall
	USES eax, ebx, ecx, edx
	mov esi, Brick_Array			; Initialize the Brick_Array offset into esi

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

	
; split in 10 columns and check wher the ball is situated
	

	cmp [Ball_Y], 174
	jle brickCol
	
	mov ebx, 0
	mov eax, 0
	call collision, ebx, eax, 1		;if greater paddle colisision
	cmp eax, 0
	je endMoveBall
	jmp checkSide
	
	
	brickCol:
	
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

	pop ebx					; restores column index in ebx

	
	
	call collision, ebx, eax,  2			; if lower or equal brickcolission
	cmp eax, 0
	je endMoveBall
	checkSide:
	; de twee volgende lijnen laten het crashen
	
	push edx							;Stores Brick_Height
	push ebx							;Stores Brick_Width
	
	cmp ecx, 0
	je paddle
	
	call updateBrick, offset Brick_Array, offset Brick_Array_Color, offset Brick_Visibility, ecx
	
	paddle:
	; Check where the ball hits the top of the blok
	
	; mov eax, [Ball_Size]
	; mov ebx, 02h		
	; xor edx, edx
	; div ebx 				;Store in eax Ball_Size
	
	;we assume that it is not possible to hit a side that point in the direction of V
	; (so if VY < 0 then can't hit the top side) 	
	mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]			; Ax
	mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]			; AY, BY
	pop edx
	add edx, eax
	
	cmp [Ball_VY], 0
	jl cannotHitTop
		pop ecx				; otherwise there is an push too much !!!!
		; cannot hit bottom 
		; check if intersect with top if not it intersects with side
		; s1 = (Ball_Y+2*Ball_Size - Block_Y)*(Block_X+Block_Width - Block_X) - (Block_Y -Block_Y)*((Ball_X+Ball_Size - Block_X)
		; s2 = (Ball_Y - Ball_VY - Block_Y)*(Block_X+Block_Width - Block_X) - (Block_Y -Block_Y)*((Ball_X - Ball_VX - Block_X)
		; If s1 > 0 and S1 == s2 --> no intersect
		
	
		call intersect, eax, ebx, edx, 1, 1				; We check if the line trough the diagonal of the ball hits the top 
		cmp eax, 1
		je hitTop
		cmp [Ball_VX], 0								;if not we need to check the sign of VX to determine what the following line is wich we need to verify (for more info look at the report
		jg posVX
		call intersect, eax, ebx, edx, 2, 2				; offsetX = 0 offsetY = 2 (right bottom of the ball)			
		cmp eax, 0
		je hitSide
		jmp hitTop
		posVX:
		call intersect, eax, ebx, edx, 0, 2				; offsetX = 2 offsetY = 2 (left bottom of the ball)
		cmp eax, 0
		je hitSide
		hitTop:
		; From here on it intersects with top 
		jmp negVelocityY
	
	cannotHitTop:
	; cannot hit top so check if hits bottom if not hits side
	; check if intersect with bottom if not it intersects with right
	; s1 = (Ball_Y-2*Ball_Size - (Block_Y + Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth -(Block_Y + Block_Heigth))*((Ball_X+Ball_Size - Block_X)
	; s2 = (Ball_Y - Ball_VY - (Block_Y+ Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth - (Block_Y + Block_Heigth))*((Ball_X - Ball_VX - Block_X)
	; If s1 > 0 and S1 == s2 --> no intersect
		pop ecx
		add ebx, ecx	
		call intersect, eax, ebx, edx, 1, 1				; We check if the line trough the diagonal of the ball hits the top 
		cmp eax, 1
		je hitBottom
		cmp [Ball_VX], 0								;if not we need to check the sign of VX to determine what the following line is wich we need to verify (for more info look at the report
		jg negVX
		call intersect, eax, ebx, edx, 0, 0				; offsetX = 0 offsetY = 0 (left top of the ball)			
		cmp eax, 0
		je hitSide
		jmp hitBottom
		negVX:
		call intersect, eax, ebx, edx, 2, 0				; offsetX = 2 offsetY = 0 (right top of the ball)
		cmp eax, 0
		je hitSide
		hitBottom:
		; From here on it intersects with top 
		jmp negVelocityY
	
	hitSide:
		cmp [Ball_VX], 0
		jl hitRight										; The differentiation is not needed
		;hitLeft
		jmp negVelocityX
		hitRight:
		jmp negVelocityX
		; From here on it intersects with top 
		
	;ret ; useless
	; is this needed as we have only one line --> Yes easier and actually you would have 2 lines the ret is important
		
	negVelocityY:
		neg [Ball_VY]   		; Reverse the vertical velocity of the ball
		ret
	negVelocityX:
		neg [Ball_VX]           ; Reverses the horizontal velocity of the ball
		ret
	endMoveBall:
		ret							; Needed otherwise go trough the rest of the procedure
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

PROC collision
	ARG @@column: dword, @@row:dword, @@type: byte
mov esi, offset Brick_Array
mov edi, offset Brick_Visibility

;Brick Collision	
	cmp [@@type], 2
	je brickCollision
						
		
; Collision with bricks and paddle is done with AABB
	
	;paddleColision:
		xor ecx, ecx			; Set the value for ecx to 1 so that the collisionCheck only loops once ; is it not 0 the column in matrix
		mov ebx, [Paddle_Width]
		mov edx, [Paddle_Height]
		
		jmp collisionCheck		; Jump to collisionCheck to check the collision with the paddle
		
	brickCollision:
		mov eax, [@@row]
		mov ebx, [@@column]
		
		mov ecx, 10
		imul ecx
		mov ecx, eax
		add ecx, ebx
		add ecx, 1
		mov ebx, [Brick_Width]
		mov edx, [Brick_Height]
		
		;jmp collisionCheck
		
	collisionCheck:
		
		;condition 1 for collision	
		mov eax, [Ball_X]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]									;maxX1 >= minX2
		cmp eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]	;Ball_X + 2 * Ball_Size >= block_X
		jl noCollision  										;if there's no collision exit collision with block (jump if less)
		
		;condition 2 for collision
		mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]	;initialize block_X in eax
		add eax, ebx											;minX1 <= maxX2
		cmp [Ball_X], eax										;Ball_X <= block_X + block_Width
		 												
		jg noCollision  										;if there's no collision exit collision with block (jump if greater)
		
		;condition 3 for collision
		mov eax, [Ball_Y]			
		add eax, [Ball_Size]		
		add eax, [Ball_Size]									;maxY1 >= minY2
		cmp eax, [esi + (1 * Brick_Array_Columns + ecx) * 4]	;Ball_Y + 2 * Ball_Size >= block_Y
		jl noCollision  										;if there's no collision exit collision with block (jump if less)
		
		;condition 4 for collision
		mov eax, [esi + (1 * Brick_Array_Columns + ecx) * 4]	;initialize block_Y in eax		
		add eax, edx											;minY1 <= maxY2
		cmp [Ball_Y], eax										;Ball_Y <= block_Y + block_Height
		 												
		jg noCollision  										;if there's no collision exit collision with block (jump if greater)
		
		mov eax, [edi + ecx * 4]								; visibility (paddle already dead
		cmp eax, 0
		je noCollision
		mov eax, 1
		ret
		noCollision:
		mov eax, 0
		ret
ENDP collision

PROC ccw
	ARG 	@@X0:dword, @@Y0:dword, @@X1:dword, @@Y1:dword, @@X2:dword, @@Y2:dword
	USES	eax, ebx, ecx, edx    ; not eax otherwise it will return the original value but not the value intended to be returned
	
	mov eax, [@@Y2]
	sub eax, [@@Y0]
	mov ebx, [@@X1]
	sub ebx, [@@X0]
	imul eax, ebx
	push eax
	
	mov eax, [@@Y1]
	sub eax, [@@Y0]
	mov ebx, [@@X2]
	sub ebx, [@@X0]
	imul eax, ebx
	pop ebx 
	
	sub ebx, eax 
	
	cmp ebx, 0
	jg true
	mov eax, 0h
	ret
	true:
	mov eax, 1h
	ret
ENDP ccw

PROC intersect
	ARG 	@@X0:dword, @@Y0:dword, @@X1:dword, @@offsetX: dword, @@offsetY: dword
	USES eax, ebx, ecx, edx
			; A = index 0 , B = index 1, C = index 2, D = index 3
	; Y0 is used her for point B but as it is for block it will be the same as for point B (remember we only check for intersect with horizontal lines) 
	;following lines are debug 
	;mov ebx, [@@X0]
	;mov ecx, [@@X1]
	;mov edx, [@@Y0]
	;mov eax,0
	;div eax
	
	mov ebx, [Ball_VX]
	mov eax, 8
	imul ebx, eax
	mov eax, [Ball_X]
	sub eax, ebx
	mov ebx, [@@offsetX]
	imul ebx, [Ball_Size]
	add eax, ebx
	
	mov ecx, [Ball_VY]
	mov ebx, 8
	imul ecx, ebx
	mov ebx, [Ball_Y]
	sub ebx, ecx 							;C ball position at time - 1
	mov ecx, [@@offsetY]
	imul ecx, [Ball_Size]
	add ebx, ecx																; C ball position at time + 1 we do this so that if the line should intersect it intersect fully (sometimes only a small portion of the ball could intersect
	
	call ccw, [@@X0] [@@Y0], [@@X1], [@@Y0], eax, ebx
	push eax
	
	push ebx
	
	mov ebx, [Ball_VX]
	mov eax, 8
	imul ebx, eax
	mov ecx, [Ball_X]
	add ecx, ebx
	mov ebx, [@@offsetX]
	imul ebx, [Ball_Size]
	add ecx, ebx
	
	mov eax, [Ball_VY]
	mov ebx, 8
	imul eax, ebx
	mov edx, [Ball_Y]
	add edx, eax 							;C ball position at time - 1
														; C ball position at time + 1 we do this so that if the line should intersect it intersect fully (sometimes only a small portion of the ball could intersect
	mov ebx, [@@offsetY]
	imul ebx, [Ball_Size]
	add edx, ebx
	
	pop ebx
	
	call ccw, [@@X0] [@@Y0], [@@X1], [@@Y0], ecx, edx
	push eax
	
	push ebx
	mov ebx, [Ball_VX]
	mov eax, 8
	imul ebx, eax
	mov eax, [Ball_X]
	sub eax, ebx
	mov ebx, [@@offsetX]
	imul ebx, [Ball_Size]
	add eax, ebx
	pop ebx
	
	call ccw, [@@X0] [@@Y0], eax, ebx, ecx, edx	
	push eax
	
	
	push ebx
	
	mov ebx, [Ball_VX]
	mov eax, 8
	imul ebx, eax
	mov eax, [Ball_X]
	sub eax, ebx
	imul ebx, [Ball_Size]
	add eax, ebx
	pop ebx
	pop ebx
														; C ball position at time + 1 we do this so that if the line should intersect it intersect fully (sometimes only a small portion of the ball could intersect
	
	
	call ccw, [@@X1], [@@Y0], eax, ebx, ecx, edx
	
	pop ebx																
	
	
	cmp eax, ebx
	
	je noIntersectPop
	
	pop eax
	pop ebx
	cmp eax, ebx
	je noIntersect
	mov eax, 1h
	ret
	noIntersectPop:
	pop eax
	pop ebx
	noIntersect:
	mov eax, 0h
	ret
	
ENDP intersect

PROC updateBrick
	ARG @@Brick_Array:dword, @@Brick_Array_Color:dword, @@Brick_Visibility:dword, @@index:dword
	USES eax, ebx, ecx, edx, esi, edi
	
	mov ecx, [@@index]		; Moving the index of the brick that needs to be updated
	cmp ecx, 0				; Check to see if the paddle is hit to skip the update procedure
	jne update				; If ecx is not equal to zero, then jump to update
	
	ret
	
	; Brick update
	update:
		mov esi, [@@Brick_Array]			; Initialize the Brick_Array offset into esi
		mov edi, [@@Brick_Array_Color]		; Initialize the Brick_Array_Color offset into edi
		
		
		mov eax, [esi + (0 * Brick_Array_Columns + ecx) * 4]		; Initialize the x-coordinate of the brick into eax
		mov ebx, [esi + (1 * Brick_Array_Columns + ecx) * 4]		; Initialize the y-coordinate of the brick into ebx
		sub [edi + ecx * 2], 1										; Subtract 1 from the color index of the bricks to show damage
		mov dx, [edi + ecx * 2]										; Initialize the color of the brick into dx
				
		cmp dx, 0		; Check to if the brick has a black color
		jg draw			; If the color index is greater than 0, that means that the brick is not black, jump to draw
		
		mov esi, [@@Brick_Visibility]		; Initialize the Brick_Visibility offset into esi
		mov [esi + ecx * 4], 0				; Set the brick visibility to zero, so the brick is not interactable
		
		draw: 
			call drawRectangle, eax, ebx, [Brick_Width], [Brick_Height], dx		; Drawning the brick in the new color

		ret

ENDP updateBrick

PROC movePaddle					;Compute movement of the paddles
	ARG @@Brick_Array:dword	
	
	mov esi, [@@Brick_Array]
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
	ARG @@Brick_Array:dword, @@Brick_Array_Color:dword
    USES eax, ebx, ecx, edx, edi
    
	mov esi, [@@Brick_Array]
	mov edi, [@@Brick_Array_Color]
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

PROC GUI
	USES eax, edx
	
	call setVideoMode, 03h
	
	mov ah, 09h
	
	mov edx, offset Levels		; Initialize the offset of the Levels string to edx
	int 21h						; Print the string
	
	mov edx, offset Endless		; Initialize the offset of the Endless string to edx
	int 21h						; Print the string
	
	mov edx, offset Exit		; Initialize the offset of the Exit string to edx
	int 21h						; Print the string

	press_check:
		mov ah, 01h
		int 16h
		jz press_check

		mov ah, 00h
		int 16h


		cmp al, 97				; 97 is ASCII code for 'a'
		je levels				; Jump if equal to level
		
		cmp al, 65				; 65 is ASCII code for 'A'
		je levels				; Jump if equal to level
		
		
		cmp al, 98				; 98 is ASCII code for 'b'
		je endless				; Jump if equal to endless
		
		cmp al, 66				; 66 is ASCII code for 'B'
		je endless				; Jump if equal to endless
		
		
		cmp al, 27				; 27 is ASCII code for 'ESC'
		je exit					; Jump if equal to exit
		
		jmp press_check

	levels:
		call setVideoMode, 03h
		
		mov ah, 09h
		
		mov edx, offset LevA		; Initialize the offset of the Level 1 string to edx
		int 21h						; Print the string
		
		mov edx, offset LevB		; Initialize the offset of the Level 2 string to edx
		int 21h						; Print the string
		
		mov edx, offset LevC		; Initialize the offset of the Level 3 string to edx
		int 21h						; Print the string
		
		level_selected:
			mov ah, 01h
			int 16h
			jz level_selected

			mov ah, 00h
			int 16h
		
			cmp al, 97				; 97 is ASCII code for 'a'
			je lev1					; Jump if equal to level
			
			cmp al, 65				; 65 is ASCII code for 'A'
			je lev1					; Jump if equal to level 
			
			
			cmp al, 98				; 98 is ASCII code for 'b'
			je lev2					; Jump if equal to endless
			
			cmp al, 66				; 66 is ASCII code for 'B'
			je lev2					; Jump if equal to endless

			
			cmp al, 99				; 99 is ASCII code for 'c'
			je lev3					; Jump if equal to endless
			
			cmp al, 67				; 67 is ASCII code for 'C'
			je lev3					; Jump if equal to endless
			
			jmp level_selected
		
		lev1:
			mov esi, offset Brick_Array
			mov edi, offset Brick_Array_Color
			
			call setVideoMode, 13h
		
			ret
			
		lev2:
			call terminateProcess
			ret
			
		lev3:
			call terminateProcess
			ret
	
	endless:
		call terminateProcess
		ret
	
	exit:
		call terminateProcess
		ret

ENDP GUI

; Wait for a specific keystroke.
; PROC waitForSpecificKeystroke
	; USES eax
	; press_check:
		; mov ah, 01h
		; int 16h
		; jz press_check

		; mov ah, 00h
		; int 16h

		; cmp al, 27		;27 is ASCII code for 'ESC'
		; jne press_check

	; mov ax, 03h
	; int 10h

	; ret

; ENDP waitForSpecificKeystroke




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

    ; call setVideoMode, 13h

	call GUI

    ; Use the variables from DATASEG as arguments
		
	; call drawBricks, offset Brick_Array, offset Brick_Array_Color	; Width and Height as arguments
	
	call drawBricks, esi, edi

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

		; call drawPaddle, offset Brick_Array, [Black] 	;remove the paddle			
		; call movePaddle, offset Brick_Array            	;move the paddles (check for pressing of keys)
		; call drawPaddle, offset Brick_Array, [White]     ;draw the paddles with the updated positions
		
		call drawPaddle, esi, [Black] 	;remove the paddle			
		call movePaddle, esi            	;move the paddles (check for pressing of keys)
		call drawPaddle, esi, [White]     ;draw the paddles with the updated positions
		
		
		
		jmp checkTime	;after everything checks time again

		;call all update functions

    ;call waitForSpecificKeystroke, 001Bh 		; keycode for ESC
	exitGame:
		call terminateProcess



ENDP main



; -------------------------------------------------------------------
DATASEG
	; GUI strings
	Levels db "Levels      Press A", 10, 10, '$'
	Endless db "Endless     Press B", 10, 10, '$'
	Exit db "Exit        Press ESC", '$'
	
	; GUI Levels selection
	LevA db "Level 1      Press A", 10, 10, '$'
	LevB db "Level 2      Press B", 10, 10, '$'
	LevC db "Level 3      Press C", '$'

	; Ball variables
	Ball_X dd 160
	Ball_Y dd 100
	; The speed is constant in magnitude but they are not constants as they vary in sign.	
	Ball_VX dd 05h               			;X (horizontal) velocity of the ball (5px)
	Ball_VY dd -03           				;Y (vertical) velocity of the ball (2px)

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
				
	Brick_Array_Color	dw 15, 		15, 15, 15, 15, 15, 15, 15, 15, 15, 15,				2, 2, 2, 2, 2, 2, 2, 2, 2, 2,						3, 3, 3, 3, 3, 3, 3, 3, 3, 3,						1, 1, 1, 1, 1, 1, 1, 1, 1, 1					;health and color
	
	Brick_Visibility	dd 1,		1, 1, 1, 1, 1, 1, 1, 1, 1, 1,						1, 1, 1, 1, 1, 1, 1, 1, 1, 1,						1, 1, 1, 1, 1, 1, 1, 1, 1, 1,						1, 1, 1, 1, 1, 1, 1, 1, 1, 1					;interactablility of the bricks (1 = interactable and 0 = not interactable)
	
	Brick_Width dd 25
	Brick_Height dd 7
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
