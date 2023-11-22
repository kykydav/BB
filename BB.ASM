; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	David Kyan, Petrosyan Artyom
; date:		17/11/2023
; program:	Brick Breaker game
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

DATASIZE_Arrow EQU 25 * 25 ;bytes of data in file	
DATASIZE_Bricks EQU 1200 ;bytes of data in file	
DATASIZE_FS EQU SCRWIDTH * SCRHEIGHT
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
	USES 	eax, ecx, edx ; note: MUL uses edx!
	push edi
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
	
	pop edi
	
	; movzx eax, [@@col]
	; call fillRectangle, [@@x0], [@@y0], [@@w], [@@h], eax
	ret
ENDP drawRectangle

PROC fillRectangle
	ARG @@x_Pos:dword, @@y_Pos:dword, @@Width:dword, @@Height:dword, @@col:byte
	USES eax, ebx, ecx, edx
	push edi
	mov eax, [@@y_Pos]
	xor edx, edx
	mov ebx, SCRWIDTH
	imul ebx
	add eax, [@@x_Pos]
	mov edi, VMEMADR
	add edi, eax
	
	mov ebx, [@@Height]
	fill_rows:
		mov al, [@@col]
		mov ecx, [@@Width] 
		rep stosb
		add edi, SCRWIDTH
		sub edi, [@@Width]
		
		dec ebx
		cmp ebx, 0
		jg fill_rows
		
	pop edi
	ret

ENDP fillRectangle

PROC drawBall
	ARG @@col:dword
	USES eax, ebx, ecx, edx

	lea esi, [game_ball]			; Load effective adress of the game_ball array with the Ball struct into esi
	
	mov eax, [esi + Ball.x_Pos]		; Initialize the x posiition of the ball into eax
	mov ebx, [esi + Ball.y_Pos]		; Initialize the y position of the ball into ebx
	mov ecx, [esi + Ball.Radius]
	mov edx, [esi + Ball.Radius]
	add edx, [esi + Ball.Radius]

	; Update the registers to draw the rest of the rectangles
	drawball:
		call drawRectangle, eax, ebx, ecx, edx, [@@col]		; Call the drawRectangle procedure using the color as an argument
		
		cmp edx, [esi + Ball.Radius]	; Check to see if the ball is drawn
		jle done						; Jump is lower or equal to done to end the procedure
		
		; Update the new values for the next rectangle to draw the ball
		sub eax, 1		
		add ebx, 1
		add ecx, 2
		sub edx, 2

		jmp drawball	; Jump to drawball until the ball is fully drawn

	done:
		ret

ENDP drawBall

PROC drawPaddle
	ARG @@col:dword
	USES eax, ebx, ecx, edx
	
	mov eax, [edi + Brick.x_Pos]    ; x-coordinate Paddle
	mov ebx, [edi + Brick.y_Pos]    ; y-coordinate Paddle
	mov ecx, [edi + Brick.Width]	; Width of the Paddle
	mov edx, [edi + Brick.Height]	; Height of the Paddle
	
	call drawRectangle, eax, ebx, ecx, edx, [@@col]
	
	ret

ENDP drawPaddle

PROC moveBall
	; esi equals game_ball Array pointer
	; edi equals the level_bricks Array pointer
	USES eax, ebx, ecx, edx
	
	; lea esi, [game_ball]	; Load effective adress of game_ball struct array to esi
	
	
	; Move ball according to the speed
	mov eax, [esi + Ball.x_Vel]
	add [esi + Ball.x_Pos], eax			; Move in x Direction (x_Pos + x_Vel * timestep)
	
	mov eax, [esi + Ball.y_Vel]
	add [esi + Ball.y_Pos], eax			; Move in y direction (y_Pos + y_Vel * timestep)

	; Check if it hits a border 
	mov eax, [esi + Ball.Radius]
	add eax, [esi + Ball.Radius]		; Right border + Ball_Diameter
	cmp [esi + Ball.x_Pos], eax
	jle negVelocityX					; If the ball hits left border, negate x velocity

	mov eax, SCRWIDTH
	sub eax, [esi + Ball.Radius]
	sub eax, [esi + Ball.Radius]
	sub eax, [esi + Ball.Radius]
	; sub eax, [esi + Ball.Radius]
	
	cmp [esi + Ball.x_Pos], eax
	jge negVelocityX					; If the ball hits right border, negate x velocity

	cmp [esi + Ball.y_Pos], 1
	jle negVelocityY					; If the ball hits upper border, negate x velocity

	mov eax, SCRHEIGHT
	sub eax, [esi + Ball.Radius]
	
	cmp [esi + Ball.y_Pos], eax
	jge gameOver						; If the ball hits the lower border --> jump to gameOver

	
	
	; Split the screen in 2 (uneven) to isolate the paddle collision and the brick collision 
	; We do not do this in the collision function so that we can manually decide the collision type (used in paddle movement by example)
	cmp [esi + Ball.y_Pos], 174
	jle brickCol							;if greater paddle collision, if lower or equal brickcolission
	
	; Paddle collision	
	call collision, 1					
	cmp [Colliding], 0
	je endMoveBall
	jmp checkBorder							
	
	brickCol:
	call collision, 2			
	cmp [Colliding], 0
	je endMoveBall
	
	checkBorder:
	push edx							;Stores Brick_Height
	push ebx							;Stores Brick_Width
	
	cmp ecx, 0
	je paddle							; in case of paddle collision skip updatebrick
	
	call updateBrick					; If a brick was hit update life/color and
	
	paddle:
	;A and B are points in the intersect method (these represent the block border)
	mov eax, [edi + ecx + Brick.x_Pos]			; Ax (x coordinate of left block point)
	mov ebx, [edi + ecx + Brick.y_Pos]			; AY, BY (y coordinate of both block points)
	pop edx										
	add edx, eax								; Bx (x coordinate of Right block point) 
	
	; Check where the ball hits the top of the blok	
	;we assume that it is not possible to hit a side where the normal vector points in the direction of Vx
	; (so if VY < 0 then can't hit the top side) 	
	cmp [esi + Ball.y_Vel], 0
	jl cannotHitTop
	; cannot hit bottom:
		pop ecx				; otherwise there is a push too much and Instruction Pointer (IP) is not correct !!!!
		; check if the velocity line intersects with top if not it intersects with a side
				
		;push eax
		call intersect, eax, ebx, edx, 1, 1				; We check if the line trough the diagonal of the ball hits the top 
		cmp eax, 1
		je hitTop
		
		
		;pop eax
		cmp [esi + Ball.x_Vel], 0						;if not we need to check the sign of VX to determine what the following line is wich we need to verify (for more info look at the report
		jg posVX
		
		;negVX
		call intersect, eax, ebx, edx, 2, 2				; offsetX = 0 offsetY = 2 (right bottom of the ball)			
		cmp eax, 0
		je short hitSide
		jmp hitTop
		
		posVX:
		call intersect, eax, ebx, edx, 0, 2				; offsetX = 2 offsetY = 2 (left bottom of the ball)
		cmp eax, 0
		je hitSide
		
		hitTop:
		; From here on it intersects with top 
		;pop eax
		jmp negVelocityY
	
	cannotHitTop:

	; cannot hit top so check if hits bottom if not hits side
	; check if intersect with bottom if not it intersects with right
	; s1 = (Ball_Y-2*Ball_Size - (Block_Y + Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth -(Block_Y + Block_Heigth))*((Ball_X+Ball_Size - Block_X)
	; s2 = (Ball_Y - Ball_VY - (Block_Y+ Block_Heigth))*(Block_X+Block_Width - Block_X) - (Block_Y + Block_Heigth - (Block_Y + Block_Heigth))*((Ball_X - Ball_VX - Block_X)
	; If s1 > 0 and S1 == s2 --> no intersect
		pop ecx
		add ebx, ecx	
		;push eax
		
		call intersect, eax, ebx, edx, 1, 1				; We check if the line trough the diagonal of the ball hits the top 
		
		cmp eax, 1
		je hitBottom
		
		;pop eax
		cmp [esi + Ball.x_Vel], 0								;if not we need to check the sign of VX to determine what the following line is wich we need to verify (for more info look at the report
		jl negVX
		;posVX
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
		;pop eax
		jmp negVelocityY
	
	hitSide:
		cmp [esi + Ball.x_Vel], 0
		jl hitRight										; The differentiation is not needed
		;hitLeft
		jmp negVelocityX
		hitRight:
		jmp negVelocityX
		; From here on it intersects with top 
		
	;ret ; useless	
	negVelocityY:
		neg [esi + Ball.y_Vel]   		; Reverse the vertical velocity of the ball
		ret
	
	negVelocityX:
		neg [esi + Ball.x_Vel]           ; Reverses the horizontal velocity of the ball
		ret
	
	endMoveBall:
		ret							; Needed otherwise go trough the rest of the procedure
	
	gameOver:
		call terminateProcess			; pop pop is needed if not terminate in future
	
	return:
		ret
ENDP moveBall

PROC collision
	ARG @@type: byte
	USES eax
	; Everytime collision is checked first put colliding to 0 so that we can use the variable to see if there is already collision (see movePaddle)
	;mov [Colliding], 0			Not needed as if ther is no collision it will be put to 0
	
	;Brick Collision	
	cmp [@@type], 2
	je brickCollision
						
	;paddleCollision:
		xor ecx, ecx			; Set the value for ecx to 1 so that the collisionCheck only loops once ; is it not 0 the column in matrix
		mov ebx, [edi + Brick.Width]
		mov edx, [edi + Brick.Height]
		
		jmp collisionCheck		; Jump to collisionCheck to check the collision with the paddle
		
	brickCollision:
	
		; split in 10 columns and check wher the ball is situated
		; determine wich column should be checked
		mov eax, [esi + Ball.x_Pos]
		add eax, [esi + Ball.Radius]	; calculate the x-coordinate of the center of the ball
		sub eax, 5						; 5 px offset from both sides of the frame (grid with is 310 in stead of 320)
		mov ebx, 31						; 31 px per column
		xor edx, edx
		div ebx                 		; stores the column (0 based index), where Ball_X is in, in eax and in edx the rest
		
		push eax						; store column index in stack
		
		mov eax, [esi + Ball.y_Pos]
		add eax, [esi + Ball.Radius]	; calculate the y-coordinate of the center of the ball
		sub eax, 5						; 5 px offset from both sides of the frame (grid with is 169 in stead of 200)
		mov ebx, 13						; 13 px per row
		xor edx, edx
		div ebx							; stores the row (0 based index), where Ball_Y is in, in eax and in edx the rest
			
		;the goal here is to transform the row and colums information in 
		;1 index (ecx) to acces the desired element in level_bricks Array 	
		mov ecx, 10
		imul ecx				; multiply row index (eax) * 10 (10 elements per row)
		mov ecx, eax			
		
		pop eax
		mov ebx, eax					; restores column index in ebx
		
		add ecx, ebx			; add column index (ebx) 
		add ecx, 1				
		
		mov eax, ecx
		xor edx, edx
		
		push ebx
		
		mov ebx, 28
		imul ebx
		
		pop ebx
		
		mov ecx, eax
		
		mov ebx, [edi + ecx + Brick.Width]
		mov edx, [edi + ecx + Brick.Height]
		;jmp collisionCheck
		
	collisionCheck:
		; Collision with bricks and paddle is done with AABB (see more in the report)
		;condition 1 for collision	
		mov eax, [esi + Ball.x_Pos]			
		add eax, [esi + Ball.Radius]		
		add eax, [esi + Ball.Radius]									;maxX1 >= minX2
		cmp eax, [edi + ecx + Brick.x_Pos]	;Ball_X + 2 * Ball_Size >= block_X
		jl noCollision  										;if there's no collision exit collision with block (jump if less)
		
		;condition 2 for collision
		mov eax, [edi + ecx + Brick.x_Pos]	;initialize block_X in eax
		add eax, ebx											;minX1 <= maxX2
		cmp [esi + Ball.x_Pos], eax										;Ball_X <= block_X + block_Width									
		jg noCollision  										;if there's no collision exit collision with block (jump if greater)
		
		;condition 3 for collision
		mov eax, [esi + Ball.y_Pos]			
		add eax, [esi + Ball.Radius]		
		add eax, [esi + Ball.Radius]									;maxY1 >= minY2
		cmp eax, [edi + ecx + Brick.y_Pos]	;Ball_Y + 2 * Ball_Size >= block_Y
		jl noCollision  										;if there's no collision exit collision with block (jump if less)
		
		;condition 4 for collision
		mov eax, [edi + ecx + Brick.y_Pos]	;initialize block_Y in eax		
		add eax, edx											;minY1 <= maxY2
		cmp [esi + Ball.y_Pos], eax										;Ball_Y <= block_Y + block_Height								
		jg noCollision  										;if there's no collision exit collision with block (jump if greater)
		
		mov eax, [edi + ecx + Brick.Active]								
		
		cmp eax, 0												; Check the visibility (if the brick is already dead then there is no collision)
		
		je noCollision
		mov [Colliding], 1										; Store the state in the collision bool
		ret
		noCollision:
		mov [Colliding], 0
		ret
ENDP collision
;---------------------------------------------------------------------
;	The following 2 procedures are written based on the algorithm described in https://stackoverflow.com/questions/3838329/how-can-i-check-if-two-segments-intersect
;	The Algotithm goes roughly like this: Check for the 2 line segments separatly the orientation of the points of the other segment relative to the base segment.
;	If both those point have the same orientation there definitly is no intersection. so we have two conditions to check (one with each segment as base segment)
; 	As the ball cant have a vertical velocity = 0 (we only check for intersection with horizontal borders) and 
;	we take, to make the velocity vector, the ball position at "virtual time" t-2 and t+2 so that it is surely completely past the border and completely before the border,
;	we don't have to check for colinearity 
;	
;	For more detail on the implementation of this method we refer to the report
;---------------------------------------------------------------------

PROC ccw
	ARG 	@@X0:dword, @@Y0:dword, @@X1:dword, @@Y1:dword, @@X2:dword, @@Y2:dword
	; Base Segment [(X0,Y0),(X1,Y1)] , Comparing point
	USES	ebx, ecx, edx    ; not eax otherwise it will return the original value but not the value intended to be returned
	
	
	; This function checks if 3 points are oriented clockwise or not. 
	
	mov eax, [@@Y2]
	sub eax, [@@Y0]
	
	mov ebx, [@@X1]
	sub ebx, [@@X0]
	
	imul eax, ebx						;(Y2-Y0)*(X1-X0)
	push eax
	
	mov eax, [@@Y1]
	sub eax, [@@Y0]
	
	mov ebx, [@@X2]
	sub ebx, [@@X0]
	
	imul eax, ebx						;(Y1-Y0)*(X2-X0)
	pop ebx 
	
	sub ebx, eax 						;(Y2-Y0)*(X1-X0) - (Y1-Y0)*(X2-X0)
	
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
	USES ebx, ecx, edx
			; A = index 0 , B = index 1, C = index 2, D = index 3
	
	; This function uses the the (anti-)clockwise method to determine if there is intersection 
	; Y0 is used here for point B but as it is for block it will be the same as for point A (remember we only check for intersect with horizontal lines) 
	

	
	mov ebx, [esi + Ball.x_Vel]
	mov eax, 2
	imul ebx, eax																
	mov eax, [esi + Ball.x_Pos]
	sub eax, ebx																; Position of the ball at time - 2
	
	mov ebx, [@@offsetX]
	imul ebx, [esi + Ball.Radius]												; offset to put te line trough the wanted point of the ball (corner- or middlepoint)
	
	add eax, ebx
	
	mov ecx, [esi + Ball.y_Vel]
	mov ebx, 2
	imul ecx, ebx
	mov ebx, [esi + Ball.y_Pos]
	sub ebx, ecx 																
	mov ecx, [@@offsetY]
	imul ecx, [esi + Ball.Radius]
	
	add ebx, ecx																; Ball position at time + 2 
																				;we do this so that if the line should intersect it intersect fully (sometimes only a small portion of the ball could intersect)
	push eax
	push ebx																	; when pushing the value in the stack, it is not erased
	call ccw, [@@X0], [@@Y0], [@@X1], [@@Y0], eax, ebx							; check clockwise for the block horizontal border (top/bottom) and ball at position t+2 
	push eax
	
	mov ebx, [esi + Ball.x_Vel]
	mov eax, 2
	imul ebx, eax
	mov ecx, [esi + Ball.x_Pos]
	add ecx, ebx
	mov ebx, [@@offsetX]
	imul ebx, [esi + Ball.Radius]
	add ecx, ebx																; Position of the ball at time + 2
	
	mov eax, [esi + Ball.y_Vel]
	mov ebx, 2
	imul eax, ebx
	mov edx, [esi + Ball.y_Pos]		
	add edx, eax 																					
	mov ebx, [@@offsetY]
	imul ebx, [esi + Ball.Radius]
	add edx, ebx
	
	call ccw, [@@X0], [@@Y0], [@@X1], [@@Y0], ecx, edx
	pop ebx 																	; pop eax from the first ccw into ebx
	cmp eax, ebx																; if they have both the same orientation it does not intersect
	
	je noIntersectPop
	
	pop ebx
	pop eax
	push eax
		
	call ccw, [@@X0], [@@Y0], eax, ebx, ecx, edx	
	push eax
	mov eax, [esp + 4]
	
	call ccw, [@@X1], [@@Y0], eax, ebx, ecx, edx
	pop ebx																
	cmp eax, ebx
	je noIntersect
	
	; Intersect
	pop eax
	mov eax, 1h
	ret
	
	noIntersectPop:
	pop eax													; unpopped value(s)
	noIntersect:
	pop eax
	mov eax, 0h
	ret
	
ENDP intersect

PROC updateBrick
	; ecx, esi and edi already defined before function call
	; ecx equals the brick index
	; esi equals game_ball Array pointer
	; edi equals level_bricks Array pointer
	USES eax, ebx, edx, ecx

	; Brick update	
	mov eax, [edi + ecx + Brick.x_Pos]		; Initialize the x-coordinate of the brick into eax
	mov ebx, [edi + ecx + Brick.y_Pos]		; Initialize the y-coordinate of the brick into ebx
	sub [edi + ecx + Brick.Color], 1		; Subtract 1 from the color index of the bricks to show damage
	mov edx, [edi + ecx + Brick.Color]		; Initialize the color of the brick into dx
			
	cmp edx, 0		; Check to if the brick has a black color
	jg draw			; If the color index is greater than 0, that means that the brick is not black, jump to draw
	
	mov [edi + ecx + Brick.Active], 0				; Set the Brick interactability to zero, so the brick is not interactable
	
	draw: 
		call drawRectangle, eax, ebx, [edi + ecx + Brick.Width], [edi + ecx + Brick.Height], edx		; Drawning the brick in the new color

	ret

ENDP updateBrick

;Compute movement of the paddles
PROC movePaddle					
	; ARG @@Brick_Array:dword	
	USES eax, ebx, ecx, edx
	; Paddle movement
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
		mov eax, [edi + Brick.x_Vel]
		sub [edi + Brick.x_Pos], eax
		
		xor eax, eax						; faster than mov eax,0
		cmp [edi + Brick.x_Pos], eax
		jl paddleRightOfBorder
		jmp checkPaddleCollisionLeft

		paddleRightOfBorder:
			mov [edi + Brick.x_Pos], eax
			jmp checkPaddleCollisionLeft

	movePaddleRight:
		mov eax, [edi + Brick.x_Vel]
		add [edi + Brick.x_Pos], eax

		mov eax, SCRWIDTH				; has to change depending on how we draw paddle and testing
		sub eax, [edi + Brick.Width]
		cmp [edi + Brick.x_Pos], eax
		jg paddleLeftOfBorder
		jmp short checkPaddleCollisionRigth

		paddleLeftOfBorder:
			mov [edi + Brick.x_Pos], eax
			jmp short checkPaddleCollisionRigth

	; The paddle movement is horizontal so if there is collision her it must be sideways (but in the algorithm used for knowing what side it hit it cannot be determined)
	; We check this collision to restrict the overlapping of the paddle over the ball as the paddle could jump over the ball making weired movement patterns
	; Note that we need to know if there is already collision otherwise we will always teleport to the sides of the paddle. 
	
	checkPaddleCollisionLeft:						; if we move the paddle to the left there will be collision from the left or none at all
	cmp [Colliding], 1								; check if the ball is already colliding (before paddle movement) , if yes dont do a thing then 
	je exitPaddleMovement
	call collision, 1								; check if the ball is colliding now (since the paddle movement)
	cmp [Colliding], 0
	je short exitPaddleMovement							; if not exit
	call drawBall, [Black]							;remove the ball
	mov ebx, [edi + Brick.x_Pos]					
	sub ebx, [esi + Ball.Radius]
	sub ebx, [esi + Ball.Radius]
	
	mov [esi + Ball.x_Pos], ebx						;move the ball to Paddle_X - 2*Ball_Size (Remember Ball_Size = radius of the ball)
	call drawBall, [White]      					;draw the ball
	jmp short exitPaddleMovement
	cmp [esi + Ball.x_Vel], 0						; check if the ball velocity needs to be changed
	jl exitPaddleMovement
	neg [esi + Ball.x_Vel]
	jmp exitPaddleMovement
	
	checkPaddleCollisionRigth:						; if we move the paddle to the rigth there will be collision from the rigth or none at all
	cmp [Colliding], 1								; check if the ball is already colliding (before paddle movement) , if yes dont do a thing then 
	je exitPaddleMovement
	call collision, 1								; check if the ball is colliding now (since the paddle movement)
	cmp [Colliding], 0
	je exitPaddleMovement							; if not exit
	
	call drawBall, [Black]							; remove the ball	
	mov ebx, [edi + Brick.x_Pos]					
	add ebx, [edi + Brick.Width]
	mov [esi + Ball.x_Pos], ebx						;move the ball to Paddle_X + Paddle_Width
	call drawBall, [White]      					;draw the ball
	cmp [esi + Ball.x_Vel], 0						; check if the ball velocity needs to be changed
	jg exitPaddleMovement
	neg [esi + Ball.x_Vel]
	exitPaddleMovement:
	ret

ENDP movePaddle

; Draws the differen levels of the bricks
PROC drawBricks
    USES eax, ebx, ecx, edx
    
	xor ecx, ecx
    
    brickloop:
		mov eax, [edi + ecx + Brick.x_Pos]    ; x-coordinate
        mov ebx, [edi + ecx + Brick.y_Pos]    ; y-coordinate 
		mov edx, [edi + ecx + Brick.Color]	  ; color
		
        call drawRectangle, eax, ebx, [edi + ecx + Brick.Width], [edi + ecx + Brick.Height], edx
        
		add ecx, 28		; Add amount of bytes in Brick struct to move to next brick in level_bricks
		
		mov eax, 28
		xor edx, edx
		mov ebx, 41
		mul ebx
		
        cmp ecx, eax	; Check to see if all the Bricks are drawn
        jl brickloop
	
    ret

ENDP drawBricks

; PROC GUI
	; Not all levels are created, this is a temporary procedure
	; USES eax, edx
	
	; call setVideoMode, 03h
	
	; mov ah, 09h
	
	; mov edx, offset Levels		; Initialize the offset of the Levels string to edx
	; int 21h						; Print the string
	
	; mov edx, offset Endless		; Initialize the offset of the Endless string to edx
	; int 21h						; Print the string
	
	; mov edx, offset Exit		; Initialize the offset of the Exit string to edx
	; int 21h						; Print the string

	; press_check:
		; mov ah, 01h
		; int 16h
		; jz press_check

		; mov ah, 00h
		; int 16h


		; cmp al, 97				; 97 is ASCII code for 'a'
		; je levels				; Jump if equal to level
		
		; cmp al, 65				; 65 is ASCII code for 'A'
		; je levels				; Jump if equal to level
		
		
		; cmp al, 98				; 98 is ASCII code for 'b'
		; je endless				; Jump if equal to endless
		
		; cmp al, 66				; 66 is ASCII code for 'B'
		; je endless				; Jump if equal to endless
		
		
		; cmp al, 27				; 27 is ASCII code for 'ESC'
		; je exit					; Jump if equal to exit
		
		; jmp press_check

	; levels:
		; call setVideoMode, 03h
		
		; mov ah, 09h
		
		; mov edx, offset LevA		; Initialize the offset of the Level 1 string to edx
		; int 21h						; Print the string
		
		; mov edx, offset LevB		; Initialize the offset of the Level 2 string to edx
		; int 21h						; Print the string
		
		; mov edx, offset LevC		; Initialize the offset of the Level 3 string to edx
		; int 21h						; Print the string
		
		; level_selected:
			; mov ah, 01h
			; int 16h
			; jz level_selected

			; mov ah, 00h
			; int 16h
		
			; cmp al, 97				; 97 is ASCII code for 'a'
			; je lev1					; Jump if equal to level
			
			; cmp al, 65				; 65 is ASCII code for 'A'
			; je lev1					; Jump if equal to level 
			
			
			; cmp al, 98				; 98 is ASCII code for 'b'
			; je lev2					; Jump if equal to endless
			
			; cmp al, 66				; 66 is ASCII code for 'B'
			; je lev2					; Jump if equal to endless

			
			; cmp al, 99				; 99 is ASCII code for 'c'
			; je lev3					; Jump if equal to endless
			
			; cmp al, 67				; 67 is ASCII code for 'C'
			; je lev3					; Jump if equal to endless
			
			; jmp level_selected
		
		; lev1:
			
			; call ReadFile, offset level_file, offset dataread, DATASIZE, 41
			
			; call setVideoMode, 13h
		
			; ret
			
		; lev2:
			; call terminateProcess
			; ret
			
		; lev3:
			; call terminateProcess
			; ret
	
	; endless:
		; call terminateProcess
		; ret
	
	; exit:
		; call terminateProcess
		; ret

; ENDP GUI

PROC gui
	USES eax
	
	cmp [Skip_GUI], 0
	je short @@press_check
	
	ret
	
	@@press_check:
		mov ah, 01h
		int 16h
		jz @@press_check

		mov ah, 00h
		int 16h
		
		call ReadFile, offset Arrow, offset dataread_Arrow, DATASIZE_Arrow

		cmp al, 114				; 114 is ASCII code for 'r'
		je @@gui_1				; Jump if equal to level
		
		cmp al, 82				; 82 is ASCII code for 'R'
		je @@gui_1				; Jump if equal to level
		
		
		cmp al, 102				; 102 is ASCII code for 'f'
		je gui_2				; Jump if equal to endless
		
		cmp al, 70				; 70 is ASCII code for 'F'
		je gui_2				; Jump if equal to endless
		
		cmp al, 13				; 13 is ASCII code for 'Enter'
		je @@enter_pressed			; Jump if equal to exit
		
		ret
		jmp @@press_check
		
	@@gui_1:
		call fillRectangle, 192, 137, 25, 25, 0
		call drawSprite, offset dataread_Arrow, 192, 104, 25, 25
		
		mov ebx, 1	; Play index
		
		ret
		
	gui_2: 
		call fillRectangle, 192, 104, 25, 25, 0
		call drawSprite, offset dataread_Arrow, 192, 137, 25, 25
	
		mov ebx, 2	; Exit index
		
		ret

	@@enter_pressed:
		call checkSprite
		mov [Skip_GUI], 1
		
		ret		

ENDP gui

PROC checkSprite
	USES ebx
	
	cmp ebx, 1
	je level_initialize
	
	cmp ebx, 2
	je exit_game
	
	ret
	
	level_initialize:
		call ReadFile, offset level_file, offset dataread_Level, DATASIZE_Bricks
		call initializeLevel, offset dataread_Level, 41
		
		ret
		
	exit_game:
		call terminateProcess
		
		ret
		
ENDP checkSprite

PROC ReadFile
	ARG	 @@filepathptr:dword, @@dataptr:dword, @@noofbytes:dword
	USES eax, ebx, ecx, edx
	
	; open file, get filehandle in AX
	mov al, 0 ; read only
	mov edx, [@@filepathptr]
	mov ah, 3dh
	int 21h
	
	mov  edx, offset openErrorMsg
	jc @@print_error ; carry flag is set if error occurs

	; read file data 
	mov bx, ax ; move filehandle to bx
	mov ecx, [@@noofbytes]
	mov edx, [@@dataptr]
	mov ah, 3fh
	int 21h

	mov  edx, offset readErrorMsg
	jc @@print_error	; carry flag is set if error occurs
	
	; close file
	mov ah, 3Eh
	int 21h
	
	mov  edx, offset closeErrorMsg
	jc @@print_error	; carry flag is set if error occurs

	ret

	@@print_error:
		call setVideoMode, 03h
		mov  ah, 09h
		int  21h
	
		mov	ah,00h
		int	16h
		call terminateProcess	
ENDP ReadFile

PROC initializeLevel
	ARG @@dataptr:dword, @@Brick_Amount:dword
	USES eax, ebx, ecx, esi
	; print to screen test data
	mov esi, [@@dataptr]		; Initialize datapointer value into esi to read the right values of the file
	lea edi, [level_bricks]		; Load effective adress of the level_bricks array which contain the Brick structs of the level

	
	; Calculate the amount of Bricks that need to be read from the file
	xor edx, edx				; Set edx:eax to eax for multiplication
	mov eax, 28					; Initalize amount of bytes in the Brick struct to eax
	mov ebx, [@@Brick_Amount]	; Initalize amount of Bricks in the level to ebx
	imul ebx					; Signed multiplication of the amount of Bricks to the amount of bytes to calculate the maximum amount of bytes to be read from the file
	mov ecx, eax				; Store eax in ecx because eax will be overwritten
	
	xor ebx, ebx				; Set ebx to zero to count correctly trough the level_bricks array
	
	looptest:
		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.x_Pos], eax		; Assign the x_Pos value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.y_Pos], eax		; Assign the y_Pos value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.x_Vel], eax		; Assign the x_Vel value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.Width], eax		; Assign the Width value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.Height], eax		; Assign the Height value from the file into the Brick struct
		
		lodsd									; Loads a word (2 byte) value into ax
		mov [edi + ebx + Brick.Color], eax		; Assign the Color value from the file into the Brick struct
		
		lodsd									; Loads a byte (1 byte) value into al
		mov [edi + ebx + Brick.Active], eax		; Assign the Active value from the file into the Brick struct
		
		add ebx, 28		; Add amount of bytes in Brick struct to continue to the next Brick
		cmp ebx, ecx	; Check to see if all the Bricks needed for the level are created
		jl looptest	
	
	call fillBackground, 0
	call drawBricks
	
	ret

ENDP initializeLevel

PROC drawSprite
	ARG	 @@dataptr: dword, @@x_Pos:dword, @@y_Pos:dword, @@Width:dword, @@Height:dword
	USES esi,ecx
	
	push edi
	mov eax, [@@y_Pos]	; y-coordinate
	mov ebx, [@@x_Pos]	; x-coordinate
	mov ecx, SCRWIDTH
	xor edx, edx
	imul ecx
	
	mov edi, eax
	add edi, ebx
	add edi, VMEMADR
	
	mov edx, [@@Height]
	mov esi, [@@dataptr]
	drawspriteloop:
		
		mov ecx, [@@Width]
		rep movsb

		add edi, SCRWIDTH
		sub edi, [@@Width]
		
		dec edx
		cmp edx, 0
		jg drawspriteloop
	
	pop edi
	ret	
ENDP drawSprite

; ; Fill the background (for mode 13h)
PROC fillBackground
	ARG @@color:byte
	USES ecx, eax
	
	push edi
	mov edi, VMEMADR
	mov ecx, DATASIZE_FS
	mov al, [@@color]
	
	rep stosb
	
	pop edi
	ret

ENDP fillBackground

; This printing procedure is used to debug the code, it is put into comment when not used
; PROC printUnsignedInteger
	; ARG @@number:word
	; USES eax, ebx, ecx, edx
	
	; movzx eax, [@@number]
	; xor ecx, ecx
	
	; decloop:
		; xor edx, edx
		; mov ebx, 10
		; div ebx
		
		; push edx
		; inc ecx
		
	; test eax, eax
	; jnz decloop
	
	; printloop:
		; pop edx
		; mov ah, 02h
		; add dl, '0'
		; int 21h
		
	; dec ecx
	; test ecx, ecx
	; jnz printloop
	
	; mov dl, 0
	
	; ret
	
; ENDP printUnsignedInteger

; Wait for a specific keystroke.
PROC waitForSpecificKeystroke
	USES eax
	press_check3:
		mov ah, 01h
		int 16h
		jz press_check3

		mov ah, 00h
		int 16h

		cmp al, 27		;27 is ASCII code for 'ESC'
		jne press_check3

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

STRUC Brick
		x_Pos dd ?		; x-position
		y_Pos dd ?		; y-position
		x_Vel dd ? 		; x_Velocity
		Width dd ?		; Brick width
		Height dd ?		; Brick height
		Color dd ?		; color
		Active dd ?		; interactability
	; total 28 bytes per Brick
	ENDS Brick
	
	STRUC Ball
		x_Pos dd ?		; x-position
		y_Pos dd ?		; y-position
		x_Vel dd ?		; x-velocity
		y_Vel dd ?		; y-velocity
		Radius dd ?		; Ball radius
		; Color dw ?		; Ball Color
	; total 22 bytes per Ball
	ENDS Ball
	
	; STRUC Sprites
		; Width dd ?		; Sprite Width
		; Height dd ?		; Sprite Height
		; DATASIZE dd ?	; DATASIZE
		; Dataoffset dd ?	; Data offset
	; total 16 bytes per Sprite
	; ENDS Sprites

PROC main
    sti
    cld

    push ds
    pop es
	
	
	call setVideoMode, 13h
	
	call ReadFile, offset GUI, offset dataread_GUI, DATASIZE_FS
	call fillBackground, 0
	call drawSprite, offset dataread_GUI, 0, 0, 320, 200
	
	; call ReadFile, offset GUI, offset dataread_Sp, DATASIZE_Arrow
	; call fillBackground, 0
	; call drawSprite, offset dataread_Arrow, 0, 0

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
		
		call gui
		
		cmp [Skip_GUI], 0
		je checkTime
		
		; call setVideoMode, 13h
		call drawBall, [Black]		;remove the ball
		call moveBall               ;move the ball
		call drawBall, [White]      ;draw the ball
		
		
		; call setVideoMode, 13h
		call drawPaddle, [Black] 	;remove the paddle			
		call movePaddle		        ;move the paddles (check for pressing of keys)
		call drawPaddle, [White]   	;draw the paddles with the updated positions
		
		jmp checkTime	;after everything checks time again

		;call all update functions

    call waitForSpecificKeystroke, 001Bh 		; keycode for ESC
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
	
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'

	;Game Constatnt
	Last_Time db 0                        	; Variable used when checking if the time has changed
	Exit_Game db 0							; Exiting Boolean
	Colliding db 0							; Colliding Boolean
	Skip_GUI db 0
	; colors
	Black dd 0
	White dd 15
	
	d_ratio dd 0
	d_hor dd 0
	d_vert dd 0
	
	level_file db "level1.bin", 0
	GUI db "GUI.bin", 0
	Arrow db "Arrow.bin", 0
	; GUI_1 db "GUI_1.bin", 0
	; GUI_2 db "GUI_2.bin", 0
	
	dataread_GUI db DATASIZE_FS dup (?)
	dataread_Arrow db DATASIZE_Arrow dup (?)
	dataread_Level db DATASIZE_Bricks dup (?)
	
	; gui_array Sprites 2 dup (<0, 0, 0, 0>)
	level_bricks Brick 41 dup (<0, 0, 0, 0, 0, 0, 0>)
	game_ball Ball <157, 97, 4, -3, 3>
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main