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

INCLUDE "playwav.inc"

; compile-time constants (with macros)
VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height

DATASIZE_Arrow EQU 25 * 25 ;bytes of data in file	
DATASIZE_Bricks EQU 3000 ;bytes of data in file	
DATASIZE_FS EQU SCRWIDTH * SCRHEIGHT
DATASIZE_Ball EQU 24
DATASIZE_Powerup EQU 10 * 10

; Random generator
RAND_A = 1103515245
RAND_C = 12345
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

; Initializes the pseudo random generator
PROC rand_init
    USES    eax, ecx, edx

    mov     ah, 02ch        ; Get system time
    int     21h

    mov     ax, dx          ; Use time to generate seed in EAX
    shl     eax, 16
    mov     ax, cx

    mov     ah, 02ah        ; Get system date
    int     21h

    shl     ecx, 16         ; Mangle date into the seed in EAX
    mov     cx, dx
    xor     eax, ecx
    
    mov     [rand_seed], eax

    ret
ENDP rand_init

; Returns a pseudo random number
PROC rand
	ARG @@limit:dword
    USES    ebx, ecx, edx
	
	call rand_init
	
    mov     eax, [rand_seed]
    mov     ecx, RAND_A
    mul     ecx
    add     eax, RAND_C
    mov		ebx, eax
	shr		ebx, 16
	
	mul		ecx
	add     eax, RAND_C
	
	mov     [rand_seed], eax
	mov		ax, bx
	
	; Getting the rest value when dividing the random number with a chosen value
	xor edx, edx
	mov ebx, [@@limit]
	div ebx
	
	; Values between 0 and @@limit - 1
	mov eax, edx

    ret
ENDP rand

; Draws a rectangle on screen
PROC drawRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@type:dword, @@col:byte
	USES 	eax, ecx, edx
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
	
	cmp [@@type], 1			; 1 is not filled rectangle and 0 is filled rectangle
	je @@done
	
	movzx eax, [@@col]
	call fillRectangle, [@@x0], [@@y0], [@@w], [@@h], 0, 0, eax ; Filling the rectangle
	
	@@done:
		ret
		
ENDP drawRectangle

; Filling a rectangle or drawing a sprite
PROC fillRectangle
	ARG @@x_Pos:dword, @@y_Pos:dword, @@Width:dword, @@Height:dword, @@type:dword, @@dataptr:dword, @@col:byte
	USES eax, ebx, edx, esi, ecx
	
	; General part of the code to draw at a specific coordinate
	push edi
	mov eax, [@@y_Pos]
	xor edx, edx
	mov ebx, SCRWIDTH
	imul ebx
	add eax, [@@x_Pos]
	mov edi, VMEMADR
	add edi, eax
	
	; Drawing the rectangle or sprite row per row
	mov edx, [@@Height]
	mov esi, [@@dataptr]
	@@Check: 
		cmp [@@type], 0			; 0 means Rectangle and 1 means Sprite
		je @@drawRectangle
		
		; Draws the sprite
		@@drawSprite:
			mov ecx, [@@Width]
			rep movsb
			jmp @@drawloop
			
		; Draws the rectangle
		@@drawRectangle:
			mov al, [@@col]
			mov ecx, [@@Width] 
			rep stosb
			
		; Loop over each row to draw the full rectangle or sprite
		@@drawloop:
			add edi, SCRWIDTH
			sub edi, [@@Width]
			
			dec edx
			cmp edx, 0
			jg @@Check
		
	pop edi
	ret

ENDP fillRectangle

; Drawing the ball
PROC drawBall
	ARG @@col:dword
	LOCAL @@temp:dword
	USES eax, ebx, ecx, edx

	lea esi, [game_ball]			; Load effective adress of the game_ball array with the Ball struct into esi
	
	; Initialize width of the ball
	call scaleDown, [esi + Ball.Radius]		; Scale the ball radius down before drawing
	mov ecx, eax
	
	; Initialize height of the ball
	mov edx, [esi + Ball.Radius]
	add edx, [esi + Ball.Radius]
	call scaleDown, edx    
	mov edx, eax
	
	; Initialize coordinates of the ball
	call scaleDown, [esi + Ball.y_Pos]		; Initialize the y position of the ball into ebx
	mov ebx, eax
	call scaleDown, [esi + Ball.x_Pos] 		; Initialize the x position of the ball into eax
	
	; Update the registers to draw the rest of the rectangles
	@@drawball:
		call drawRectangle, eax, ebx, ecx, edx, 0, [@@col]		; Call the drawRectangle procedure using the color as an argument
		
		; Check to see if the ball is drawn
		push eax
		call scaleDown, [esi + Ball.Radius]
		mov [@@temp], eax
		pop eax
		cmp edx, [@@temp]	
		jle @@done			; Jump is lower or equal to @@done to end the procedure
		
		; Update the new values for the next rectangle to draw the ball
		sub eax, 1		
		add ebx, 1
		add ecx, 2
		sub edx, 2

		jmp @@drawball	; Jump to drawball until the ball is fully drawn

	@@done:
		ret

ENDP drawBall

; Drawing the Paddle
PROC drawPaddle
	ARG @@col:dword
	USES eax, ebx, ecx, edx
	
	call scaleDown, [edi + Brick.Width]    ; Initialize width of the Paddle into ecx
	mov ecx, eax
	call scaleDown, [edi + Brick.Height]   ; Initialize height of the Paddle into edx
	mov edx, eax
	
	call scaleDown, [edi + Brick.y_Pos]    ; Initialize y-coordinate Paddle into ebx
	mov ebx, eax
	call scaleDown, [edi + Brick.x_Pos]    ; Initialize x-coordinate Paddle into eax
	
	call drawRectangle, eax, ebx, ecx, edx, 0, [@@col]	; Drawing the Paddle
	
	ret

ENDP drawPaddle

; Refreshing the movement of the powerups
PROC movePowerup
	LOCAL @@BrickX:dword, @@BrickY:dword, @@BrickW:dword, @@BrickH:dword
	USES eax, edi
	
	; Load brick values into local variables for later use
	mov eax, [edi + Brick.x_Pos]
	mov [@@BrickX], eax
	mov eax, [edi + Brick.y_Pos]
	mov [@@BrickY], eax
	mov eax, [edi + Brick.Width]
	mov [@@BrickW], eax
	mov eax, [edi + Brick.Height]
	mov [@@BrickH], eax
	
	push edi
	push esi
	
	lea edi, [powerups]		; Load effective adress of the powerups struct array into edi
	
	xor esi, esi	; Use edi as counter
		
	@@updatePowerup:
		cmp [edi + esi + Powerup.Active], 0		; Check to see if the powerup is active
		je @@notactive							; Jump is powerup not active to @@notactive
		
		; Load powerup values into registers
		call scaleDown, [edi + esi + Powerup.Height]	
		mov edx, eax
		call scaleDown, [edi + esi + Powerup.y_Pos]
		mov ebx, eax
		call scaleDown, [edi + esi + Powerup.x_Pos]
		
		call fillRectangle, eax, ebx, edx, edx, 0, 0, [Black]		; Draw a black rectangle to coverup powerup before updating an redrawing
		
		; Updating the y coordinate to let the powerup "fall"
		mov ebx, [edi + esi + Powerup.y_Vel]
		add [edi + esi + Powerup.y_Pos], ebx
		
		; Scaling the y coorinate down to be able to draw
		push eax
		call scaleDown, [edi + esi + Powerup.y_Pos]
		mov ebx, eax
		pop eax
		
		; Reading the sprite file and drawing the sprite
		mov ecx, [edi + esi + Powerup.Dataread]
		call ReadFile, ecx, offset dataread_Powerup, DATASIZE_Powerup
		call fillRectangle, eax, ebx, edx, edx, 1, offset dataread_Powerup, 0
		
		mov ecx, [edi + esi + Powerup.Height]
		shr ecx, 1 
		
		; Checking Collision of the powerup with the paddle
		call collision, [edi + esi + Powerup.x_Pos], [edi + esi + Powerup.y_Pos], ecx, [@@BrickX], [@@BrickY], [@@BrickW], [@@BrickH], [edi + esi + Powerup.Active]
		cmp [Colliding], 0
		je @@checkBoundaries
		
		; If collision occurs, then setting the powerup to inactive and applying it for one minute
		mov [edi + esi + Powerup.Active], 0
		mov [edi + esi + Powerup.Applied], 1
		mov ecx, esi
		
		call applyPowerup, ecx, [edi + esi + Powerup.Up_Down]	; Updating the values of the paddle and the ball
		
		call fillRectangle, eax, ebx, edx, edx, 0, 0, [Black]			; Drawing black over the powerup to remove it visualy from the game whem collision occurs
		mov esi, ecx
		
		call activateTimer		; Activating the one minute timer

		; Check to see if the powerup didn't collide and just fell out of the frame
		@@checkBoundaries:
		call scaleDown, [edi + esi + Powerup.y_Pos]
		cmp eax, 200
		jle @@notactive
		
		mov [edi + esi + Powerup.Active], 0
		
		; Moving on to the next powerup
		@@notactive:
			add esi, [Powerup_Struct_Size]									; Increment esi with Powerup_Struct_Size to go to the next powerup
			call Multiply, [Powerup_Struct_Size], [Powerup_Amount]		; Multiplies Powerup_Struct_Size and Powerup_Amount to get the limit of the loop
			
			cmp esi, eax		; Compare the counter to the limit of the loop
			jl @@updatePowerup	; Jump if lower to @@updatePowerup
		
	@@done:
		pop esi
		pop edi
		ret
	
ENDP movePowerup

; Applies powerup by updating the values for the paddle and the ball
PROC applyPowerup
	ARG @@Powerup:dword, @@type:dword
	LOCAL @@speed:dword, @@damage:dword, @@sizepaddle:dword
	USES eax, ebx, ecx, edx, esi, edi
	
	lea edi, [powerups]		; Load effective adress of powerups into edi
	mov ecx, [@@Powerup]	; Initialize the powerup offset into ecx to only apply 1 powerup
	
	; Initialize the powerup effects into local variables
	mov ebx, [edi + ecx + Powerup.Speedmultiply]
	mov [@@speed], ebx
	mov ebx, [edi + ecx + Powerup.Damagemultiply]
	mov [@@damage], ebx
	mov ebx, [edi + ecx + Powerup.Sizemultiply]
	mov [@@sizepaddle], ebx
	
	lea esi, [game_ball]	; Load effective adress of game_ball into esi
	xor edx, edx			; Set edx to zero for the multiplications
	
	cmp [@@type], 0			; 0 for Powerdown and 1 for Powerup
	je @@Powerdown
	
	; Applying a Powerup
		
	@@balls_up:
		call Multiply, [esi + Ball.x_Vel], [@@speed]	; Multiply the x velocity with the powerup speed multiplicator
		mov [esi + Ball.x_Vel], eax
		
		call Multiply, [esi + Ball.y_Vel], [@@speed]	; Multiply the y velocity with the powerup speed multiplicator
		mov [esi + Ball.y_Vel], eax
		
		mov ebx, [@@damage]
		mov [esi + Ball.Damage], ebx					; Set the ball damage to the powerup damage multiplicator
	
	@@paddle_up:
		lea edi, [level_bricks]		; Load effective adress of level_bricks into edi
		
		call Multiply, [edi + Brick.Width], [@@sizepaddle]	; Multiply the paddle width with the powerup size multiplicator
		mov [edi + Brick.Width], eax
		
		ret

	; Applying a Powerdown
	@@Powerdown:
		@@balls_down:
			; Divide the x velocity with the powerup speed multiplicator
			mov eax, [esi + Ball.x_Vel]
			cdq
			idiv [@@speed]
			mov [esi + Ball.x_Vel], eax
			
			; Divide the y velocity with the powerup speed multiplicator
			mov eax, [esi + Ball.y_Vel]
			cdq
			idiv [@@speed]
			mov [esi + Ball.y_Vel], eax
		
		@@paddle_down:
			lea edi, [level_bricks]		; Load effective adress of level_bricks into edi
			
			; Initialize the values of the paddle to redraw smaller
			call scaleDown, [edi + Brick.Height]
			mov edx, eax
			call scaleDown, [edi + Brick.Width]
			mov ecx, eax
			call scaleDown, [edi + Brick.y_Pos]
			mov ebx, eax
			call scaleDown, [edi + Brick.x_Pos]
			
			call drawRectangle, eax, ebx, ecx, edx, 0, [Black]	; Draw over the paddle before drawing the smaller paddle
			
			; Divide the paddle width with the powerup size multiplicator
			mov eax, [edi + Brick.Width]
			cdq
			idiv [@@sizepaddle]
			mov [edi + Brick.Width], eax
			
			ret

ENDP applyPowerup

; Resetting the Powerups after the timer
PROC resetPowerup
	USES eax, ebx, ecx, edx
	
	cmp [timer_active], 0	; Check to see if timer is active, if not, skip the procedure
	jne @@Checktime
	
	ret
	
	; Checks time for timer
	@@Checktime:
		xor edx, edx
		lea edi, [powerups]		; Load effective adress of powerups to edi
		@@Poweruploop:
			cmp [edi + edx + Powerup.Applied], 1	; Check if the powerup is applied, if not skip timer check
			jne @@next

			; Timer check
			call checkTimer, 1, edx
			cmp eax, 1
			je @@Powerupinactive
			
			; Continue to next powerup
			@@next:
				add edx, [Powerup_Struct_Size]
				call Multiply, [Powerup_Struct_Size], [Powerup_Amount]
				
				cmp edx, eax
				jl @@Poweruploop
				
			ret
		
		; If timer passes, ball and paddle reset to standard values
		@@Powerupinactive:
		mov [timer_active], 0
		
		lea esi, [game_ball]		; Load effective adress of game_ball to esi
		mov [esi + Ball.Damage], 1	; Reset ball damage	
		
		lea edi, [level_bricks]		; Load effective adress of level_bricks

		; Reset the paddle to original values and redraw
		call scaleDown, [edi + Brick.Height]
		mov edx, eax
		call scaleDown, [edi + Brick.Width]
		mov ecx, eax
		call scaleDown, [edi + Brick.y_Pos]
		mov ebx, eax
		call scaleDown, [edi + Brick.x_Pos]
		
		call drawRectangle, eax, ebx, ecx, edx, 0, [Black]
		call scaleUp, 25
		mov [edi + Brick.Width], eax
		
		jmp @@Poweruploop

ENDP resetPowerup

; Refreshing the movement of the ball
PROC moveBall
	LOCAL @@temp:dword, @@temp1:dword, @@brickIndex: dword
	; esi equals game_ball Array pointer
	; edi equals the level_bricks Array pointer
	USES eax, ebx, ecx, edx
	
	; lea esi, [game_ball]	; Load effective adress of game_ball struct array to esi
	
	; Move ball according to the speed
	mov eax, [esi + Ball.x_Pos]
	add eax, [esi + Ball.x_Vel]
	mov [esi + Ball.x_Pos], eax			; Move in x Direction (x_Pos + x_Vel * timestep) (Remember we are working with a fraction (1/Speed_Constant) of pixel for the game speed)
	
	mov eax, [esi + Ball.y_Pos]
	add eax, [esi + Ball.y_Vel]
	mov [esi + Ball.y_Pos], eax			; Move in y direction (y_Pos + y_Vel * timestep)

	; Check if it hits a border 
	mov eax, [esi + Ball.Radius]
	add eax, [esi + Ball.Radius]		; Right border + Ball_Diameter
	add eax, [esi + Ball.Radius]		; Right border + Ball_Diameter	
	cmp [esi + Ball.x_Pos], eax
	jle negVelocityX					; If the ball hits left border, negate x velocity

	mov eax, SCRWIDTH
	call scaleUp, eax
	sub eax, [esi + Ball.Radius]
	sub eax, [esi + Ball.Radius]
	sub eax, [esi + Ball.Radius]
	; sub eax, [esi + Ball.Radius]
	
	cmp [esi + Ball.x_Pos], eax
	jge negVelocityX					; If the ball hits right border, negate x velocity

	cmp [esi + Ball.y_Pos], 1
	jle negVelocityY					; If the ball hits upper border, negate x velocity

	mov eax, SCRHEIGHT
	call scaleUp, eax
	sub eax, [esi + Ball.Radius]
	
	cmp [esi + Ball.y_Pos], eax
	jge gameOver						; If the ball hits the lower border --> jump to gameOver

	mov ecx, [Brick_Struct_Size]
	neg ecx
	
	@@collisionCheck:
		add ecx, [Brick_Struct_Size]							; ecx = 0 is paddle so we need it if we dont decrease the last element is ecx = 1
		mov ebx, [edi + ecx + Brick.Width]
		mov edx, [edi + ecx + Brick.Height]
		call collision,[esi + Ball.x_Pos],[esi + Ball.y_Pos],[esi + Ball.Radius],[edi + ecx + Brick.x_Pos],[edi + ecx + Brick.y_Pos],[edi + ecx + Brick.Width], [edi + ecx + Brick.Height], [edi + ecx + Brick.Active]
		cmp [Colliding],1
		je @@collision
		
		mov eax, [Brick_Struct_Size]
		xor edx, edx
		imul [Level_Size]
		cmp ecx, eax
		jle @@collisionCheck
		cmp [Colliding], 0
		je endMoveBall
	@@collision:
	mov [Colliding], 0
	;Check with border of the block is hit
	push edx							;Stores Brick_Height
	push ebx							;Stores Brick_Width
	
	cmp ecx, 0
	je paddle							; in case of paddle collision skip updatebrick
	call updateBrick, 0, ecx			; If a brick was hit update life/color and
	
	paddle:
	;A and B are points in the intersect method (these represent the block border)
	mov eax, [edi + ecx + Brick.x_Pos]			; Ax (x coordinate of left block point)
	mov ebx, [edi + ecx + Brick.y_Pos]			; AY, BY (y coordinate of both block points)
	pop edx										
	add edx, eax								; Bx (x coordinate of Right block point) 
	mov [@@brickIndex], ecx
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
		
		cmp [@@brickIndex], 0
		je short gradient	
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
	gradient:
		call arcsine
		mov [@@temp], 2
		fidiv [dword ptr @@temp]					;FPU STACK: 1/2 * arcsin(y)			
		fcos										; cos(1/2 * arcsin(y))
		mov eax, [Ball_Base_Vy]
		mov [@@temp], eax
		fild [dword ptr @@temp]         			; Store and pop last element from stack into the double word at the memory location pointed to by eax
		fmul st(0),st(1)           					; FPU STACK: Vy_base * cos(1/2 * arcsin(y))
		fabs
		fistp [dword ptr @@temp]	
		mov eax, [@@temp]
		mov [esi + Ball.y_Vel], eax     			
		
		call arcsine
		mov [@@temp], 2
		fidiv [dword ptr @@temp]					;FPU STACK: 1/2 * arcsin(y)			
		fsin										; cos(1/2 * arcsin(y))
		mov eax, [Ball_Base_Vx]
		mov [@@temp], eax
		fild [dword ptr @@temp]         			; Store and pop last element from stack into the double word at the memory location pointed to by eax
		fmul st(0),st(1)           					; FPU STACK: Vy_base * cos(1/2 * arcsin(y))
		fistp [dword ptr @@temp]	
		mov eax, [@@temp]
		mov [esi + Ball.x_Vel], eax     			
		
		; xor ebx, ebx
		; div ebx
		
	negVelocityY:
		neg [esi + Ball.y_Vel]   		; Reverse the vertical velocity of the ball
		ret
	
	negVelocityX:
		neg [esi + Ball.x_Vel]           ; Reverses the horizontal velocity of the ball
		ret
	
	endMoveBall:
		ret							; Needed otherwise go trough the rest of the procedure
	
	gameOver:
		call backToMenu
		
		ret
		; call terminateProcess			
	
	return:
		ret
ENDP moveBall

;------------------------------------------------------------------------------------------
;The goal of the folowing procedures is to make a "gradiënt" that does a continuous refraction angle(x) function
;The aproach is explained in detail in the report but basically the argument of the arcsine will be y = (X-pad_X - pad_width/2) / (pad_width/2) so that the angle with the vertical is 0 with the ball hitting the middle and maximal when hitting the side
;the arcsine(y) is then divided by 2 so that the maximal angle = 45°
;After that we use this angle to scale the VY and VX accordingly vx = sin(y/2) vx(base) vy = cos(y/2) vy(base)
;Following code will use the fpu
;Note the use of dword ptr to ensure that the instruction is correctly interpreting the memory operand as a 32-bit (doubleword) value.
;------------------------------------------------------------------------------------------

;Can handle signed x's
PROC gradientdistance
	LOCAL @@temp:dword
	mov eax, [esi + Ball.x_Pos]
	;mov [@@temp], [esi + Ball.x_Pos]
	add eax, [esi + Ball.Radius]
	mov [@@temp], eax
	fild [dword ptr @@temp]						;FPU STACK: X
	
	mov eax, [edi + Brick.Width]
	mov [@@temp], eax
	fild [dword ptr @@temp]						;FPU STACK: Brick.width|X
	mov [@@temp], 2
	fidiv [dword ptr @@temp]					;FPU STACK: Brick.width/2|X
	
	mov eax, [edi + Brick.x_Pos]
	mov [@@temp], eax
	fild [dword ptr @@temp]						;FPU STACK: Brick.x_Pos|Brick.width/2|X
	fadd										;FPU STACK: Brick.x_Pos+Brick.width/2|X 
												
	fsub										;FPU STACK: X-Paddle_X - Paddle_width/2
	
	mov eax, [edi + Brick.Width] 		
	mov [@@temp], eax
	fild [dword ptr @@temp]						;FPU STACK: Paddle_width|X-Paddle_X - Paddle_width/2
	mov [@@temp], 2
	fidiv [dword ptr @@temp]					;FPU STACK: Paddle_width/2|X-pad_X - pad_width/2
	fdiv										;FPU STACK: (X-pad_X - pad_width/2) / (pad_width/2)
	
	ret

ENDP gradientdistance

PROC pow
	ARG  @@N: dword
	LOCAL @@temp:dword
	;USES ecx
	mov ecx, [dword ptr @@N]               ; Move @@N to the exponent
	dec ecx
	call gradientdistance									; FPU STACK: X    
	power:
		call gradientdistance				; push the argument (y) on fpu stack
        fmul st(0),st(1)           		; FPU STACK: X^(n) (1 < n < N)  Multiply st(0) by X
        loop power
	
    ;fistp [dword ptr @@temp]         ; Store and pop last element from stack into the double word at the memory location pointed to by eax
	;mov eax, [@@temp]
	ret									;The procedure returns on the stack
ENDP pow	


PROC arcsine
	LOCAL @@temp:dword, @@temp1:dword
	call gradientdistance 
	call pow, 3					;FPU STACK: x^3
	;mov  [@@temp], eax
	;fild [dword ptr @@temp]				;FPU STACK: x^3
	
	
	mov [@@temp], 6
	fidiv [dword @@temp]				;FPU STACK: (1/6)*x^3
	
	call gradientdistance 
	call pow, 5					;FPU STACK: x^5|(1/6)*x^3
	;mov  [@@temp], eax
	;fild [dword ptr @@temp]				;FPU STACK: x^5|(1/6)*x^3
	mov [@@temp], 3
	;fild [dword ptr @@temp]				;FPU STACK: 3|x^5|(1/6)*x^3
	fimul [dword ptr @@temp]					;FPU STACK: 3*x^5|(1/6)*x^3
	mov [@@temp], 40
	fidiv [dword @@temp]				;FPU STACK: (3/40)x^5|(1/6)*x^3
	
	
	;fild [@@X]							;FPU STACK: x|(3/40)x^5|(1/6)*x^3
	call gradientdistance 
	fadd
	fadd								;FPU STACK: x + (3/40)x^5 + (1/6)*x^3
	
	
	;mov [@@temp], 100
	;fild [dword ptr @@temp]				;FPU STACK: 3|x^5|(1/6)*x^3
	;fimul [dword ptr @@temp]
	
	; fistp [dword ptr @@temp]         	; Store and pop last element from stack into the double word at the memory location pointed to by eax
	; mov eax, [@@temp]
	; xor ecx, ecx
	; div ecx
	
	ret
ENDP arcsine


PROC collision
	ARG 	@@X1:dword, @@Y1:dword, @@Size1:dword, @@X2:dword, @@Y2:dword, @@Width2:dword, @@Height2:dword, @@Active:dword 
	USES eax, ebx, ecx, edx
	; Everytime collision is checked first put colliding to 0 so that we can use the variable to see if there is already collision (see movePaddle)
	;mov [Colliding], 0			Not needed as if ther is no collision it will be put to 0

											
	
	mov ebx, [@@Width2]
	mov edx, [@@Height2]
	; Collision with bricks and paddle is done with AABB (see more in the report)
	;condition 1 for collision	
	mov eax, [@@X1]			
	add eax, [@@Size1]		
	add eax, [@@Size1]									;maxX1 >= minX2
	cmp eax, [@@X2]	;Ball_X + 2 * Ball_Size >= block_X
	jl brickNotColliding  										;if there's no collision exit collision with block (jump if less)
	
	;condition 2 for collision
	mov eax, [@@X2]	;initialize block_X in eax
	add eax, ebx											;minX1 <= maxX2
	cmp [@@X1], eax										;Ball_X <= block_X + block_Width									
	jg brickNotColliding  										;if there's no collision exit collision with block (jump if greater)
	
	;condition 3 for collision
	mov eax, [@@Y1]			
	add eax, [@@Size1]		
	add eax, [@@Size1]											;maxY1 >= minY2
	cmp eax, [@@Y2]												;Ball_Y + 2 * Ball_Size >= block_Y
	jl brickNotColliding  										;if there's no collision exit collision with block (jump if less)
	
	;condition 4 for collision
	mov eax, [@@Y2]	;initialize block_Y in eax		
	add eax, edx											;minY1 <= maxY2
	cmp [@@Y1], eax										;Ball_Y <= block_Y + block_Height								
	jg brickNotColliding  										;if there's no collision exit collision with block (jump if greater)
	
	mov eax, [@@Active]								
	cmp eax, 0												; Check the visibility (if the brick is already dead then there is no collision)
	je brickNotColliding
	
	;Colliding
	mov [Colliding], 1										; Store the state in the collision bool
	ret
	
	brickNotColliding:
	;noCollision:
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

; Updating moving bricks and when bricks get hit
PROC updateBrick
	ARG @@type:dword, @@hitbrick:dword
	LOCAL @@temp1: dword , @@temp2: dword
	USES eax, ebx, edx, ecx
	
	mov ecx, [Brick_Struct_Size]	; Initialize Brick_Struct_Size into ecx as a counter
	lea esi, [game_ball]			; Load effective adress of game_ball into esi
	lea edi, [level_bricks]			; Load effective adress of level_bricks into edi
	
	cmp [@@type], 1				; 0 equals hit brick 1 equals moving bricks
	je @@Brick_update	
		
	mov ecx, [@@hitbrick]	; Initialize @@hitbrick into ecx to only update the brick that is hit
	
	mov eax, [esi + Ball.Damage]
	sub [edi + ecx + Brick.Color], eax		; Subtract Damage from the color index of the bricks to show damage
	
	cmp [edi + ecx + Brick.Color], 0	; Check to see it the brick broke or not
	jg short @@Brick_update					; Jump is the brick is not broken
	
	mov [edi + ecx + Brick.Color], 0
	mov [edi + ecx + Brick.x_Vel], 0
	mov [edi + ecx + Brick.y_Vel], 0
	
	; Initialize and generate pseudo random number
	call rand_init
	call rand, 3
	
	cmp eax, 0			; Check to see if there will be a powerup or not 1/3 chance to get a powerup when breaking a brick
	jne @@Brick_update	; jump if not equal to 0 and there is no powerup
	
	; Generate pseudo random number to randomize which powerup falls
	push esi
	@@random:
		call rand, [Powerup_Amount]
		
		call Multiply, eax, [Powerup_Struct_Size]		
		mov edx, eax
		
		lea esi, [powerups]		; Load effective adress of powerups into esi
	
		cmp [esi + edx + Powerup.Active], 1		; Check to see if the random powerup is already active
		je @@random								; Jump if equal (active) to @@random to regenerate a pseudo random number
	
	mov [esi + edx + Powerup.Active], 1
	
	; Load brick coordinates into powerup coordinates to initialize the powerup
	mov eax, [edi + ecx + Brick.x_Pos]
	mov ebx, [edi + ecx + Brick.y_Pos]
	
	mov [esi + edx + Powerup.x_Pos], eax
	mov [esi + edx + Powerup.y_Pos], ebx
	
	pop esi
	
	; Update bricks
	@@Brick_update:	
		; Initialize brick values into local variabels and registers to draw
		call scaleDown, [edi + ecx + Brick.Width]	; Initialize the width of the brick into @@temp1
		mov [@@temp1], eax
		
		call scaleDown, [edi + ecx + Brick.Height]	; Initialize the height of the brick into @@temp2
		mov [@@temp2], eax
		
        call scaleDown, [edi + ecx + Brick.y_Pos]   ; Initialize the y coordinate of the brick into ebx
		mov ebx, eax
		call scaleDown, [edi + ecx + Brick.x_Pos]   ; Initialize the x coordinate of the brick into eax
		
        call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, [Black]	; Draw black rectangle to coverup brick
		
		; Updating the coordinates of the brick to move the brick
		mov eax, [edi + ecx + Brick.x_Vel]
		add [edi + ecx + Brick.x_Pos], eax
		
		mov eax, [edi + ecx + Brick.y_Vel]
		add [edi + ecx + Brick.y_Pos], eax
	
		mov eax, [edi + ecx + Brick.x_Pos]		; Initialize the x-coordinate of the brick into eax
		mov ebx, [edi + ecx + Brick.y_Pos]		; Initialize the y-coordinate of the brick into ebx
		
		; Checks the treshholds of the moving brick and if boundy hit negate velocity
		@@CheckTreshhold:
			mov edx, [edi + ecx + Brick.Hor_limR]
			sub edx, [edi + ecx + Brick.Width]
			cmp eax, edx
			jg short @@neg_VelX
			
			mov edx, [edi + ecx + Brick.Hor_limL]
			cmp eax, edx
			jl short @@neg_VelX
			
			mov edx, [edi + ecx + Brick.Ver_limT]
			cmp ebx, edx
			jl short @@neg_VelY
			
			mov edx, [edi + ecx + Brick.Ver_limB]
			sub edx, [edi + ecx + Brick.Height]
			cmp ebx, edx
			jg short @@neg_VelY
			
		; Draw the updated bricks
		@@Drawing:
			mov edx, [edi + ecx + Brick.Color]		; Initialize the color of the brick into dx	
			
			cmp edx, 0		; Check to if the brick has a black color
			jg @@draw		; If the color index is greater than 0, that means that the brick is not black, jump to draw
			
			mov [edi + ecx + Brick.Active], 0				; Set the Brick interactability to zero, so the brick is not interactable
			
			@@draw: 
				; Initialize brick coordinates into registers
				call scaleDown, [edi + ecx + Brick.y_Pos]   ; Initialize the y-coordinate of the brick into ebx
				mov ebx, eax
				call scaleDown, [edi + ecx + Brick.x_Pos]   ; Initialize the x-coordinate of the brick into eax
				
				call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, edx		; Drawning the brick in the new color or new position
			
			jmp @@next
			
		@@neg_VelX:
			neg [edi + ecx + Brick.x_Vel]	; negate the x velocity
			jmp @@Drawing
			
		@@neg_VelY:
			neg [edi + ecx + Brick.y_Vel]	; negate the y velocity
			jmp @@Drawing
		
		@@next:
			add ecx, [Brick_Struct_Size]

			call Multiply, [Brick_Struct_Size], [Level_Size]	; Multiply Brick_Struct_Size and Level_Size
			cmp ecx, eax
			jl @@Brick_update
		
	ret

ENDP updateBrick

; Compute movement of the paddles
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

		cmp al, 65h
		je @@exit
				
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
		call scaleUp, [edi + Brick.x_Vel]
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
		call scaleUp, [edi + Brick.x_Vel]
		add [edi + Brick.x_Pos], eax

		mov eax, SCRWIDTH				; has to change depending on how we draw paddle and testing
		call scaleUp, eax
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
	;call collision, 1								; check if the ball is colliding now (since the paddle movement)
	call collision,[esi + Ball.x_Pos],[esi + Ball.y_Pos],[esi + Ball.Radius],[edi + Brick.x_Pos],[edi + Brick.y_Pos],[edi + Brick.Width], [edi + Brick.Height], [edi + Brick.Active]
	cmp [Colliding], 0
	je exitPaddleMovement							; if not exit
	call drawBall, [Black]							;remove the ball
	mov ebx, [edi + Brick.x_Pos]					
	sub ebx, [esi + Ball.Radius]
	sub ebx, [esi + Ball.Radius]
	
	mov [esi + Ball.x_Pos], ebx						;move the ball to Paddle_X - 2*Ball_Size (Remember Ball_Size = radius of the ball)
	call drawBall, [White]      					;draw the ball
	jmp short exitPaddleMovement
		
	checkPaddleCollisionRigth:						; if we move the paddle to the rigth there will be collision from the rigth or none at all
	cmp [Colliding], 1								; check if the ball is already colliding (before paddle movement) , if yes dont do a thing then 
	je short exitPaddleMovement
	;call collision, 1								; check if the ball is colliding now (since the paddle movement)
	call collision,[esi + Ball.x_Pos],[esi + Ball.y_Pos],[esi + Ball.Radius],[edi + Brick.x_Pos],[edi + Brick.y_Pos],[edi + Brick.Width], [edi + Brick.Height], [edi + Brick.Active]

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
	@@exit:
	call backToMenu
	ret
ENDP movePaddle

; Reinitialize the GUI
PROC backToMenu
	mov [Skip_GUI], 0
	
	; Initialize the first page of the GUI
	call ReadFile, offset GUI, offset dataread_GUI, DATASIZE_FS
	call fillBackground, 0
	call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
	ret

ENDP backToMenu

; Draws the differen levels of the bricks
PROC drawBricks
	; ARG @@Brick_Amount:dword
	LOCAL @@temp1: dword , @@temp2: dword
    USES eax, ebx, ecx, edx
    
	xor ecx, ecx
    
    brickloop:
		
		call scaleDown, [edi + ecx + Brick.Width]	; Initialize the width of the brick into @@temp1
		mov [@@temp1], eax
		
		call scaleDown, [edi + ecx + Brick.Height]	; Initialize the height of the brick into @@temp2
		mov [@@temp2], eax
		
        call scaleDown, [edi + ecx + Brick.y_Pos]   ; Initialize the y coordinate into ebx
		mov ebx, eax
		call scaleDown, [edi + ecx + Brick.x_Pos]   ; Initialize the x coordinate into eax
		
		mov edx, [edi + ecx + Brick.Color]	  		; Initialize the Color into edx
		
        call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, edx
        
		add ecx, [Brick_Struct_Size]				; Add amount of bytes in Brick struct to move to next brick in level_bricks
		
		call Multiply, [Brick_Struct_Size], [Level_Size]	; Multiply Brick_Struct_Size and Level_Size to check if all bricks are drawn
		
        cmp ecx, eax	; Check to see if all the Bricks are drawn
        jl brickloop
	
    ret

ENDP drawBricks

; Interactable GUI
PROC gui
	USES eax, ecx
	
	; Check to see if level is active or not 
	cmp [Skip_GUI], 0
	je short @@press_check
	
	ret
	
	; Check which button is pressed
	@@press_check:
		mov ah, 01h
		int 16h
		jz @@press_check

		mov ah, 00h
		int 16h
		
		call ReadFile, offset Arrow, offset dataread_Arrow, DATASIZE_Arrow
		
		cmp ebx, 3			; Check to see if the levelselect page is active
		je @@levelselect
		
		cmp al, 'r'				; 114 is ASCII code for 'r'
		je @@gui_1				; Jump if equal to level
		
		cmp al, 'R'				; 82 is ASCII code for 'R'
		je @@gui_1				; Jump if equal to level
		
		cmp al, 'f'				; 102 is ASCII code for 'f'
		je short @@gui_2		; Jump if equal to endless
		
		cmp al, 'F'				; 70 is ASCII code for 'F'
		je @@gui_2				; Jump if equal to endless
		
		@@levelselect:	
		
			cmp al, 13				; 13 is ASCII code for 'Enter'
			je @@enter_pressed		; Jump if equal to exit
			
			cmp ebx, 3			; Check to see if the levelselect page is active
			jne @@continue

			cmp al, 's'
			je @@left
			
			cmp al, 'S'
			je @@left
			
			cmp al, 'd'
			je @@right
			
			cmp al, 'D'
			je @@right
		
		@@continue:
			ret
			jmp @@press_check
		
	; Play button is selected
	@@gui_1:
		call fillRectangle, 192, 137, 25, 25, 0, 0, [Black]
		call fillRectangle, 192, 104, 25, 25, 1, offset dataread_Arrow, 0
		
		mov ebx, 1	; Play index
		
		ret
		
	; Exit button is selected
	@@gui_2: 
		call fillRectangle, 192, 104, 25, 25, 0, 0, [Black]
		call fillRectangle, 192, 137, 25, 25, 1, offset dataread_Arrow, 0
	
		mov ebx, 2	; Exit index
		
		ret
	
	; Check which action needs to be performed when pressing enter
	@@enter_pressed:
		call checkSprite
		
		cmp ebx, 3
		je @@press_check
		
		ret		
		
	; Move the level selector to the left
	@@left:
		mov ecx, 0
		cmp [index], 0
		jle @@borderleft
		
		call Multiply, 100, [index]
		add eax, 13
		call drawRectangle, eax, 61, 94, 60, 1, [White]		; Redraw a white rectangle over the selector to cover it up

		; Update index
		@@continueleft:
			dec [index]
			mov ecx, 2
			cmp [index], 0
			jge @@displayselector
		
		inc [index]
		
		@@borderleft:
			ret
		
	; Move the level selector to the right
	@@right:
		mov ecx, 1
		cmp [index], 2
		jge @@borderright
		
		call Multiply, 100, [index]
		add eax, 13
		call drawRectangle, eax, 61, 94, 60, 1, [White]		; Redraw a white rectangle over the selector to cover it up
		
		; Update index
		@@continueright:
			inc [index]
			mov ecx, 2
			cmp [index], 2
			jle @@displayselector
			
			dec [index]
			
		@@borderright:
			ret
	
	; Display the green selector
	@@displayselector:
		call Multiply, 100, [index]
		add eax, 13
		
		cmp ecx, 2
		je @@drawselected
		
		cmp ecx, 0
		je @@continueleft
		
		cmp ecx, 1
		je @@continueright
		
		ret
		
		; Draw green rectangle around level as selector
		@@drawselected:
			call drawRectangle, eax, 61, 94, 60, 1, 2
			
			ret

ENDP gui

PROC checkSprite
	
	; Multiple checks to check which action needs to be performed
	cmp ebx, 1
	je @@levelspage
	
	cmp ebx, 2
	je @@exit_game
	
	cmp ebx, 3
	je @@level_initialize
	
	ret
	
	; Read and initialize the levelselect page
	@@levelspage:
		call ReadFile, offset level_page, offset dataread_GUI, DATASIZE_FS
		call fillRectangle, 0, 0, 320, 200, 0, 0, [Black]
		call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
		call drawRectangle, 13, 61, 94, 60, 1, 2
		
		mov ebx, 3
		
		ret
	
	; Initialize the different levels
	@@level_initialize:
		xor ebx, ebx
		
		; Initialize powerups and ball
		call initializePowerup
		call initializeBall
		
		mov [Skip_GUI], 1	; Disable GUI
		
		cmp [index], 0
		je @@level1
		
		cmp [index], 1
		je @@level2
		
		cmp [index], 2
		je @@level3
		
		ret
		
		; Initialize level 1
		@@level1:
			call ReadFile, offset level1, offset dataread_Level, DATASIZE_Bricks
			call initializeLevel, offset dataread_Level, 41

			ret
		
		; Initialize level 2
		@@level2:
			call ReadFile, offset level2, offset dataread_Level, DATASIZE_Bricks
			call initializeLevel, offset dataread_Level, 37
			
			ret
		
		; Initialize level 3
		@@level3:
			call ReadFile, offset level3, offset dataread_Level, DATASIZE_Bricks
			call initializeLevel, offset dataread_Level, 52

			ret
		
	@@exit_game:
		call terminateProcess
		
		ret
		
ENDP checkSprite

; Reading the files
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

; Initialization of the bricks and paddle
PROC initializeLevel
	ARG @@dataptr:dword, @@Brick_Amount:dword
	USES eax, ebx, ecx, esi
	
	mov eax, [@@Brick_Amount]
	mov [Level_Size], eax
	
	mov esi, [@@dataptr]		; Initialize datapointer value into esi to read the right values of the file
	lea edi, [level_bricks]		; Load effective adress of the level_bricks array which contain the Brick structs of the level
	
	call Multiply, [Brick_Struct_Size], [Level_Size]	; Calculate the amount of Bricks that need to be read from the file
	mov ecx, eax										; Store eax in ecx because eax will be overwritten
	xor ebx, ebx										; Set ebx to zero to count correctly trough the level_bricks array

	looptest:
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.x_Pos], eax		; Assign the x_Pos value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.y_Pos], eax		; Assign the y_Pos value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.x_Vel], eax		; Assign the x_Vel value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.y_Vel], eax		; Assign the y_Vel value from the file into the Brick struct

		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Width], eax		; Assign the Width value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Height], eax		; Assign the Height value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Hor_limL], eax	; Assign the moving horizontal left treshhold value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Hor_limR], eax	; Assign the moving horizontal right treshhold value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Ver_limB], eax	; Assign the moving vertical bottom treshhold value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		call scaleUp, eax
		mov [edi + ebx + Brick.Ver_limT], eax	; Assign the moving vertical top treshhold value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.Color], eax		; Assign the Color value from the file into the Brick struct
		
		lodsd									; Loads a dword (4 byte) value into eax
		mov [edi + ebx + Brick.Active], eax		; Assign the Active value from the file into the Brick struct
		
		add ebx, [Brick_Struct_Size]			; Add amount of bytes in Brick struct to continue to the next Brick
		cmp ebx, ecx							; Check to see if all the Bricks needed for the level are created
		jl looptest	
	
	call fillBackground, 0
	call drawBricks
	
	ret

ENDP initializeLevel

; Initialize the ball
PROC initializeBall
	USES eax, ebx, ecx, edx
	
	; Read from the ball file
	call ReadFile, offset ball, offset dataread_Ball, DATASIZE_Ball
	
	mov esi, offset dataread_Ball
	lea edi, [game_ball]
	
	lodsd							; Loads a dword (4 byte) value into eax
	call scaleUp, eax
	mov [edi + Ball.x_Pos], eax		; Assign the ball x coordinate
	
	lodsd							; Loads a dword (4 byte) value into eax
	call scaleUp, eax
	mov [edi + Ball.y_Pos], eax		; Assign the ball y coordinate
	
	lodsd							; Loads a dword (4 byte) value into eax
	mov [edi + Ball.x_Vel], eax		; Assign the ball x velocity
	
	lodsd							; Loads a dword (4 byte) value into eax
	mov [edi + Ball.y_Vel], eax		; Assign the ball y velocity
	
	lodsd							; Loads a dword (4 byte) value into eax
	call scaleUp, eax
	mov [edi + Ball.Radius], eax	; Assign the ball radius
	
	lodsd							; Loads a dword (4 byte) value into eax
	mov [edi + Ball.Damage], eax	; Assign the ball damage
	
	ret

ENDP initializeBall

; Initialize powerups
PROC initializePowerup
	USES eax, ebx, ecx, edx, edi
	
	mov esi, offset dataread_Powerup
	lea edi, [powerups]					; Load effective adress of powerups into edi
	xor ecx, ecx
	
	; Initialize the powerup sprite file offsets into the structs
	@@initialize:
		mov ebx, offset instabr
		mov [edi + ecx + Powerup.Dataread], ebx			
		add ecx, [Powerup_Struct_Size]
		
		mov ebx, offset bigpad
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]

		mov ebx, offset fastbal
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]

		mov ebx, offset smallpad
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
	
		mov ebx, offset slowbal
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
		
		call Multiply, [Powerup_Struct_Size], [Powerup_Amount]	; Multiply Powerup_Struct_Size and Powerup_Amount to get the limit of the loop
		
		cmp ecx, eax
		jle @@initialize
	
	lea edi, [powerups]		; Load effective adress of powerups into edi
	
	xor ebx, ebx
	xor ecx, ecx
	@@loadvalues:
		call ReadFile, offset powerups_file, offset dataread_Powerup, DATASIZE_Powerup
		mov esi, offset dataread_Powerup
		xor edx, edx
		
		@@Powerups:
			lodsd											; Loads a dword (4 byte) value into eax
			mov [edi + ecx + Powerup.x_Pos], eax
			mov [edi + ecx + Powerup.y_Pos], eax
			mov [edi + ecx + Powerup.Active], eax
			
			lodsd											; Loads a dword (4 byte) value into eax
			mov [edi + ecx + Powerup.Up_Down], eax			; Assign if powerup or powerdown
			lodsd											; Loads a dword (4 byte) value into eax
			mov [edi + ecx + Powerup.Speedmultiply], eax	; Assign speed multiplicator
			lodsd											; Loads a dword (4 byte) value into eax
			mov [edi + ecx + Powerup.Damagemultiply], eax	; Assign damage multiplicator
			lodsd											; Loads a dword (4 byte) value into eax
			mov [edi + ecx + Powerup.Sizemultiply], eax		; Assign size multiplicator
			
			add ecx, [Powerup_Struct_Size]
			inc edx
			
			cmp edx, 5		; Compare edx to 5 to initialize the 5 powerups
			jl @@Powerups
			
		inc ebx
		
		cmp ebx, 3			; Compare ebx to 6 to initialize the 5 powerups 3 times
		jl @@loadvalues
	
	ret
ENDP initializePowerup

; Multiply procedure
PROC Multiply
	ARG @@factor1:dword, @@factor2:dword
	USES ebx, edx 
	
	mov eax, [@@factor1]
	mov ebx, [@@factor2]
	xor edx, edx
	imul ebx
	
	ret

ENDP Multiply

; Scale up
PROC scaleUp
	ARG @@X:dword
	USES ecx
	mov ecx, [Scaling_Factor]
	mov eax, [@@X]
	@@scaleup:
		shl eax, 1
		loop @@scaleup
	ret	; eax
ENDP scaleUp

; Scale down
PROC scaleDown
	ARG @@X:dword
	USES ecx
	mov ecx, [Scaling_Factor]
	mov eax, [@@X]
	@@scaledown:
		shr eax, 1
		loop @@scaledown
	ret	; eax
ENDP scaleDown

; Get system time for the timer
PROC GetSystemTime
	mov ah, 2Ch        ; MS-DOS interrupt to get system time
	int 21h

	movzx eax, cl

	ret
ENDP GetSystemTime

; Activating the timer
PROC activateTimer
	mov [timer_flag], 0

	call GetSystemTime
	mov [start_timer], eax
	mov [timer_active], 1

	ret
ENDP activateTimer

; Check the time for the timer
PROC checkTimer
	ARG @@amount:dword, @@Powerup:dword
	USES ebx, ecx
	
	lea edi, [powerups]
	mov ecx, [@@Powerup]
	
	call GetSystemTime
	sub eax, [start_timer]							; Get the elapsed time from when the timer was activated
	mov [edi + ecx + Powerup.Elapsed_Time], eax

	mov ebx, [@@amount]
	cmp [edi + ecx + Powerup.Elapsed_Time], ebx		; Check the limit for the time (eq 1 minute)
	jge @@timerExpired

	jmp @@exit

	@@timerExpired:
		mov [timer_flag], 1
		mov eax, 1

	@@exit:
		ret
ENDP checkTimer

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
	y_Vel dd ?		; y_Velocity 
	Width dd ?		; Brick width
	Height dd ?		; Brick height
	Hor_limL dd ?	; Horizontal moving treshold left
	Hor_limR dd ?	; Horizontal moving treshold right
	Ver_limB dd ?	; Vertical moving treshold bottom
	Ver_limT dd ?	; Vertical moving treshold top
	Color dd ?		; color
	Active dd ?		; interactability
	; total 48 bytes per Brick
ENDS Brick
	
STRUC Ball
	x_Pos dd ?		; x-position
	y_Pos dd ?		; y-position
	x_Vel dd ?		; x-velocity
	y_Vel dd ?		; y-velocity
	Radius dd ?		; Ball radius
	Damage dd ?		; Ball damage
; total 24 bytes per Ball
ENDS Ball
	
STRUC Powerup
	x_Pos dd ?			; x-position
	y_Pos dd ?			; y-position
	y_Vel dd ?			; y-velcoity
	Width dd ?			; width
	Height dd ?			; height
	Up_Down dd ?		; Powerup or Powerdown
	Speedmultiply dd ?	; ball speed multiplyer
	Damagemultiply dd ? ; ball damage multiplyer
	Sizemultiply dd ?	; paddle size multiplyer
	Dataread dd ? 		; Dataread of sprite
	Active dd ?			; Activity of powerup
	Applied dd ?		; If powerup applied or not
	Elapsed_Time dd ?	; Powerup active time
; total 52 bytes per Powerup/Powerdown
ENDS Powerup

; wait for @@framecount frames
proc wait_VBLANK
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
endp wait_VBLANK


PROC main
    sti
    cld

    push ds
    pop es
	
	call setVideoMode, 13h		; Initialize video mode 13h
	
	; Read and display the first page of the GUI
	call ReadFile, offset GUI, offset dataread_GUI, DATASIZE_FS
	call fillBackground, [Black]
	call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
	
	@@update:                      			
		call resetPowerup		;time checking and powerup reset
			
		@@Powerupactive:
			lea edi, [level_bricks]		; Load effective adress of level_bricks into edi
			call gui
			
			cmp [Skip_GUI], 0			; Skip GUI if 1
			je wait_frame
			
			call updateBrick, 1, 0		; Update moving bricks
			call movePowerup			; Move the powerups
		
			call drawBall, [Black]		; Remove the ball
			call moveBall               ; Move the ball
			
			call drawPaddle, [Black] 	; Remove the paddle			
			call movePaddle		        ; Move the paddles (check for pressing of keys)
			
			cmp [Skip_GUI], 0			; Skip GUI if 1
			je wait_frame
			
			call drawBall, [White]   	; Draw the ball
			call drawPaddle, [White]   	; Draw the paddles with the updated positions
		
		wait_frame:
		call wait_VBLANK, 1
		jmp @@update				; After everything update again

    call waitForSpecificKeystroke, 001Bh 		; keycode for ESC
	@@exitGame:
		call terminateProcess

ENDP main
; -------------------------------------------------------------------
DATASEG
	; Error messages
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'

	; Game Constatnt
	Scaling_Factor dd 4
	Ball_Base_Vx dd 24
	Ball_Base_Vy dd -16
	
	; Colors
	Black dd 0
	White dd 15
	
	; Indexes
	index dd 0
	Skip_GUI db 0
	rand_seed  dd ?
	timer_flag dd 0
	start_timer dd 0
	elapsed_time dd 0
	current_time dd 0
	timer_active dd 0
	
	; Booleans
	Exit_Game db 0							
	Colliding db 0							
	
	; ...
	d_ratio dd 0
	d_hor dd 0
	d_vert dd 0
	
	; Struct size
	Brick_Struct_Size dd 48
	Powerup_Struct_Size dd 52
	
	; Level size
	Level_Size dd 0
	Powerup_Amount dd 15
	
	; Level files
	level1 db "level1.bin", 0
	level2 db "level2.bin", 0
	level3 db "level3.bin", 0
	ball db "Ball.bin", 0
	powerups_file db "Powerups.bin", 0
	
	; GUI files
	GUI db "GUI.bin", 0
	Arrow db "Arrow.bin", 0
	level_page	db "Levelgui.bin", 0
	
	; Powerup files
	smallpad db "smallpad.bin", 0
	bigpad db "bigpad.bin", 0
	fastbal db "fastbal.bin", 0
	slowbal db "slowbal.bin", 0
	instabr db "instabr.bin", 0
	
	; Uninitialized datareads
	dataread_GUI db DATASIZE_FS dup (?)
	dataread_Arrow db DATASIZE_Arrow dup (?)
	dataread_Level db DATASIZE_Bricks dup (?)
	dataread_Ball db DATASIZE_Ball dup (?)
	dataread_Powerup db DATASIZE_Powerup dup (?)
	
	; Struct arrays
	level_bricks Brick 60 dup (<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>)
	game_ball Ball 1 dup (<0, 0, 0, 0, 0, 0>)
	powerups Powerup 15 dup (<0, 0, 10, 160, 160, 1, 1, 1, 1, 0, 0, 0, 0>)
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main