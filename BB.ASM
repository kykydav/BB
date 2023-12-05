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
DATASIZE_Bricks EQU 7200 ;bytes of data in file	
DATASIZE_FS EQU SCRWIDTH * SCRHEIGHT
DATASIZE_Powerup EQU 10 * 10

; Random generator
RAND_A = 1103515245
RAND_C = 12345
; -------------------------------------------------------------------
CODESEG
call readChunk
; Set the video mode
PROC setVideoMode
	ARG @@mode:word
	USES eax

	mov ax, [@@mode]
	int 10h

	ret

ENDP setVideoMode

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
	
	xor edx, edx
	mov ebx, [@@limit]
	div ebx
	
	mov eax, edx

    ret
ENDP rand

PROC drawRectangle
	ARG 	@@x0:dword, @@y0:dword, @@w:dword, @@h:dword, @@type:dword, @@col:byte   ; col = 15 is white
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
	
	cmp [@@type], 1			; 1 is not filled rectangle and 0 is filled rectangle
	je @@done
	
	movzx eax, [@@col]
	call fillRectangle, [@@x0], [@@y0], [@@w], [@@h], 0, 0, eax
	
	@@done:
		ret
		
ENDP drawRectangle

PROC fillRectangle
	ARG @@x_Pos:dword, @@y_Pos:dword, @@Width:dword, @@Height:dword, @@type:dword, @@dataptr:dword, @@col:byte
	USES eax, ebx, edx, esi, ecx
	
	push edi
	mov eax, [@@y_Pos]
	xor edx, edx
	mov ebx, SCRWIDTH
	imul ebx
	add eax, [@@x_Pos]
	mov edi, VMEMADR
	add edi, eax
	
	mov edx, [@@Height]
	mov esi, [@@dataptr]
	@@Check: 
		cmp [@@type], 0			; 0 means Rectangle and 1 means Sprite
		je @@drawRectangle
		
		@@drawSprite:
			mov ecx, [@@Width]
			rep movsb
			jmp @@drawloop
			
		@@drawRectangle:
			mov al, [@@col]
			mov ecx, [@@Width] 
			rep stosb
			
		@@drawloop:
			add edi, SCRWIDTH
			sub edi, [@@Width]
			
			dec edx
			cmp edx, 0
			jg @@Check
		
	pop edi
	ret

ENDP fillRectangle

PROC drawBall
	ARG @@col:dword
	LOCAL @@temp:dword
	USES eax, ebx, ecx, edx

	lea esi, [game_ball]			; Load effective adress of the game_ball array with the Ball struct into esi
	
	
	call scaleDown, [esi + Ball.Radius]    
	mov ecx, eax
	
	mov edx, [esi + Ball.Radius]
	add edx, [esi + Ball.Radius]
	call scaleDown, edx    
	mov edx, eax
	
	call scaleDown, [esi + Ball.y_Pos]		; Initialize the y position of the ball into ebx
	mov ebx, eax
	
	call scaleDown, [esi + Ball.x_Pos] 
	

	; Update the registers to draw the rest of the rectangles
	drawball:
		call drawRectangle, eax, ebx, ecx, edx, 0, [@@col]		; Call the drawRectangle procedure using the color as an argument
		push eax
		call scaleDown, [esi + Ball.Radius]
		mov [@@temp], eax
		pop eax
		cmp edx, [@@temp]	; Check to see if the ball is drawn
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
	
	call scaleDown, [edi + Brick.Width]    ; Width of the Paddle
	mov ecx, eax
	call scaleDown, [edi + Brick.Height]    ; Height of the Paddle
	mov edx, eax
	
	call scaleDown, [edi + Brick.y_Pos]    ; y-coordinate Paddle
	mov ebx, eax
	call scaleDown, [edi + Brick.x_Pos]    ; x-coordinate Paddle
	
	call drawRectangle, eax, ebx, ecx, edx, 0, [@@col]
	
	ret

ENDP drawPaddle

PROC movePowerup
	LOCAL @@BrickX:dword, @@BrickY:dword, @@BrickW:dword, @@BrickH:dword
	USES eax, edi
	push edi
	push esi
	
	lea edi, [powerups]
	
	xor esi, esi
		
	@@updatePowerup:
		cmp [edi + esi + Powerup.Active], 0
		je @@stillactive
		
		mov edx, [edi + esi + Powerup.Height]
		; mov edx, eax
		mov ecx, [edi + esi + Powerup.Width]
		; mov ecx, eax
		call scaleDown, [edi + esi + Powerup.y_Pos]
		mov ebx, eax
		call scaleDown, [edi + esi + Powerup.x_Pos]
		; mov eax, [edi + esi + Powerup.x_Pos]
		; mov ebx, [edi + esi + Powerup.y_Pos]
		; mov ecx, [edi + esi + Powerup.Width]
		; mov edx, [edi + esi + Powerup.Height]
		
		call fillRectangle, eax, ebx, ecx, edx, 0, 0, 0
		
		; mov eax, [@@index]
		mov ebx, [edi + esi + Powerup.y_Vel]
		add [edi + esi + Powerup.y_Pos], ebx
		
		; mov eax, [edi + esi + Powerup.x_Pos]
		push eax
		call scaleDown, [edi + esi + Powerup.y_Pos]
		mov ebx, eax
		pop eax
		; mov ecx, [edi + esi + Powerup.Width]
		; mov edx, [edi + esi + Powerup.Height]
		
		push ecx
		mov ecx, [edi + esi + Powerup.Dataread]
		call ReadFile, ecx, offset dataread_Powerup, DATASIZE_Powerup
		pop ecx
		call fillRectangle, eax, ebx, ecx, edx, 1, offset dataread_Powerup, 0
		
		; mov edx, [edi + esi + Powerup.Active]
		
		; pop esi
		; pop edi
		; push eax
		; push ebx
		; push ecx
		; push edx
		
		; call scaleDown, [edi + Brick.x_Pos]
		; mov [@@BrickX], eax
		; call scaleDown, [edi + Brick.y_Pos]
		; mov [@@BrickY], eax
		; call scaleDown, [edi + Brick.Width]
		; mov [@@BrickW], eax
		; call scaleDown, [edi + Brick.Height]
		; mov [@@BrickH], eax
		
		; mov eax, [edi + Brick.x_Pos]
		; mov ebx, [edi + Brick.y_Pos]
		; mov ecx, [edi + Brick.Width]
		; mov edx, [edi + Brick.Height]
		
		
		; mov [@@BrickY], ebx
		; mov [@@BrickW], ecx
		; mov [@@BrickH], edx
		
		; pop edx
		; pop ecx
		; pop ebx
		; pop eax
		
		; call collision, eax, ebx, ecx, [@@BrickX], [@@BrickY], [@@BrickW], [@@BrickH], edx
		
		; push edi
		; push esi
		
		; lea edi, [powerups]
		
		; cmp [edi + esi + Powerup.y_Pos], 640
		; jle @@stillactive
		
		; cmp [Colliding], 1
		; jne @@stillactive
		
		
		; mov [edi + esi + Powerup.Active], 0
		
		; call fillRectangle, eax, ebx, ecx, edx, 0, 0, 0
		; mov ebx, 0
		; div ebx
		call scaleDown, [edi + esi + Powerup.y_Pos]
		cmp eax, 200
		jle @@stillactive
		
		
		; cmp [edi + esi + Powerup.Active], 0
		; je @@stillactive
		
		mov [edi + esi + Powerup.Active], 0
		
		; call applyPowerup, esi, 1
			
		
		@@stillactive:
			add esi, [Powerup_Struct_Size]
			
			mov eax, [Powerup_Struct_Size]
			mov ebx, [Powerup_Amount]
			xor edx, edx
			imul ebx
			
			cmp esi, eax
			jl @@updatePowerup
		
	@@done:
		pop esi
		pop edi
		ret
	
ENDP movePowerup

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
	
	;Check with border of the block is hit
	push edx							;Stores Brick_Height
	push ebx							;Stores Brick_Width
	
	cmp ecx, 0
	je paddle							; in case of paddle collision skip updatebrick
	call updateBrick, 0, ecx					; If a brick was hit update life/color and
	
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
		mov [Skip_GUI], 0
		
		call ReadFile, offset GUI, offset dataread_GUI, DATASIZE_FS
		call fillBackground, 0
		call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
		
		ret
		; call terminateProcess			; pop pop is needed if not terminate in future
	
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
	USES eax
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

PROC updateBrick
	ARG @@type:dword, @@hitbrick:dword
	LOCAL @@temp1: dword , @@temp2: dword
	; ecx, esi and edi already defined before function call
	; ecx equals the brick index
	; esi equals game_ball Array pointer
	; edi equals level_bricks Array pointer
	USES eax, ebx, edx, ecx
	mov ecx, [Brick_Struct_Size]
	cmp [@@type], 1		; Update moving bricks
	je short @@Brick_update
		
	mov ecx, [@@hitbrick]
	; xor edx, edx
	; mul [Brick_Struct_Size]
	; mov ecx, eax
	
	; neg [edi + ecx + Brick.x_Vel]
	
	mov eax, [esi + Ball.Damage]
	sub [edi + ecx + Brick.Color], eax		; Subtract 1 from the color index of the bricks to show damage
	
	cmp [edi + ecx + Brick.Color], 0
	jg @@Brick_update
	
	call rand_init
	call rand, 3
	
	cmp eax, 1
	jne @@Brick_update
	
	@@random:
		call rand, [Powerup_Amount]
		; call rand, 6
		mov ebx, [Powerup_Struct_Size]
		xor edx, edx
		imul ebx			
		mov edx, eax
		
		push esi
		
		lea esi, [powerups]
	
		cmp [esi + edx + Powerup.Active], 1
		je @@random
	; cmp [esi + edx + Powerup.y_Pos], 200
	; pop esi
	; jg @@Brick_update
	; push esi
	
	mov [esi + edx + Powerup.Active], 1

	; call scaleDown, [edi + ecx + Brick.y_Pos]
	; mov ebx, eax
	; call scaleDown, [edi + ecx + Brick.x_Pos]
	mov eax, [edi + ecx + Brick.x_Pos]
	mov ebx, [edi + ecx + Brick.y_Pos]
	
	mov [esi + edx + Powerup.x_Pos], eax
	mov [esi + edx + Powerup.y_Pos], ebx
	
	pop esi
	
	@@Brick_update:	
		
		mov edx, 0
		
		
		call scaleDown, [edi + ecx + Brick.Width]
		mov [@@temp1], eax
		
		call scaleDown, [edi + ecx + Brick.Height]
		mov [@@temp2], eax
		
        call scaleDown, [edi + ecx + Brick.y_Pos]    ; Initialize the y-coordinate of the brick into ebx
		mov ebx, eax
		call scaleDown, [edi + ecx + Brick.x_Pos]    ; Initialize the x-coordinate of the brick into eax
		
		mov edx, 0									  ; color black to erase
		
        call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, edx
		
		mov eax, [edi + ecx + Brick.x_Vel]
		add [edi + ecx + Brick.x_Pos], eax
		
		mov eax, [edi + ecx + Brick.y_Vel]
		add [edi + ecx + Brick.y_Pos], eax
		
		; call moveObject, [edi + ecx + Brick.x_Pos], [edi + ecx + Brick.y_Pos], [edi + ecx + Brick.x_Vel], [edi + ecx + Brick.y_Vel]
	
		mov eax, [edi + ecx + Brick.x_Pos]		; Initialize the x-coordinate of the brick into eax
		mov ebx, [edi + ecx + Brick.y_Pos]		; Initialize the y-coordinate of the brick into ebx
		
		@@CheckTreshhold:
			mov edx, [edi + ecx + Brick.Hor_limR]
			sub edx, [edi + ecx + Brick.Width]
			cmp eax, edx
			jge short @@neg_VelX
			
			mov edx, [edi + ecx + Brick.Hor_limL]
			cmp eax, edx
			jle short @@neg_VelX
			
			mov edx, [edi + ecx + Brick.Ver_limT]
			cmp ebx, edx
			jle short @@neg_VelY
			
			mov edx, [edi + ecx + Brick.Ver_limB]
			sub edx, [edi + ecx + Brick.Height]
			cmp ebx, edx
			jge short @@neg_VelY
			
		@@Drawing:
			mov edx, [edi + ecx + Brick.Color]		; Initialize the color of the brick into dx	
			
			cmp edx, 0		; Check to if the brick has a black color
			jg @@draw			; If the color index is greater than 0, that means that the brick is not black, jump to draw
			
			mov [edi + ecx + Brick.Active], 0				; Set the Brick interactability to zero, so the brick is not interactable
			
			@@draw: 
				call scaleDown, [edi + ecx + Brick.Width]
				mov [@@temp1], eax
		
				call scaleDown, [edi + ecx + Brick.Height]
				mov [@@temp2], eax
		
				call scaleDown, [edi + ecx + Brick.y_Pos]    ; Initialize the y-coordinate of the brick into ebx
				mov ebx, eax
				call scaleDown, [edi + ecx + Brick.x_Pos]    ; Initialize the x-coordinate of the brick into eax
				
				call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, edx		; Drawning the brick in the new color
			
			jmp @@next
			
		@@neg_VelX:
			neg [edi + ecx + Brick.x_Vel]
			jmp @@Drawing
			
		@@neg_VelY:
			neg [edi + ecx + Brick.y_Vel]
			jmp @@Drawing
		
		@@next:
			add ecx, [Brick_Struct_Size]
			
			mov eax, [Brick_Struct_Size]
			xor edx, edx
			imul ecx, [Level_Size]
			
			cmp ecx, eax
			jle @@Brick_update
		
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

ENDP movePaddle

; Draws the differen levels of the bricks
PROC drawBricks
	ARG @@Brick_Amount:dword
	LOCAL @@temp1: dword , @@temp2: dword
    USES eax, ebx, ecx, edx
    
	xor ecx, ecx
    
    brickloop:
		
		call scaleDown, [edi + ecx + Brick.Width]
		;mov eax, [edi + ecx + Brick.Width]
		mov [@@temp1], eax
		
		call scaleDown, [edi + ecx + Brick.Height]
		mov [@@temp2], eax
		
        call scaleDown, [edi + ecx + Brick.y_Pos]    ; y-coordinate 
		mov ebx, eax
		call scaleDown, [edi + ecx + Brick.x_Pos]    ; x-coordinate
		
		mov edx, [edi + ecx + Brick.Color]	  ; color
		
        call drawRectangle, eax, ebx, [@@temp1], [@@temp2], 0, edx
        
		add ecx, [Brick_Struct_Size]		; Add amount of bytes in Brick struct to move to next brick in level_bricks
		
		mov eax, [Brick_Struct_Size]
		xor edx, edx
		mov ebx, [@@Brick_Amount]
		mul ebx
		
        cmp ecx, eax	; Check to see if all the Bricks are drawn
        jl brickloop
	
    ret

ENDP drawBricks

PROC applyPowerup
	ARG @@Powerup:dword, @@type:dword
	LOCAL @@speed:dword, @@damage:dword, @@sizepaddle:dword
	USES eax, ebx, ecx, edx
	
	lea eax, [powerups]
	mov ebx, [Powerup_Struct_Size]
	xor edx, edx
	mov ecx, [@@Powerup]
	imul ecx, ebx
	
	
	cmp [@@type], 1			; 0 for Powerup and 1 for Powerdown
	je @@Powerdown
	
	mov ebx, [eax + ecx + powerups.Speedmultiply]
	mov [@@speed], ebx
	mov ebx, [eax + ecx + powerups.Damagemultiply]
	mov [@@damage], ebx
	; mov amount, [eax + ecx + Powerups.Ball_amount]
	mov ebx, [eax + ecx + powerups.Sizemultiply]
	mov [@@sizepaddle], ebx
	
	xor ebx, ebx
	xor edx, edx
	@@balls_up:
		imul [esi + ebx + Ball.x_Vel], [@@speed]
		imul [esi + ebx + Ball.y_Vel], [@@speed]
		imul [esi + ebx + Ball.Damage], [@@damage]
		ret
		; add ebx, [Ball_Struct_Size]
		
		; mov eax, [Ball_Amount]
		; mov ecx, [Ball_Struct_Size]
		; xor edx, edx
		; imul ecx
		
		; cmp ebx, ecx
		; jle @@balls_up
	
	@@paddle_up:
		imul [edi + Brick.Width], [@@sizepaddle]
		ret
	
	@@Powerdown:
	
		@@balls_down:
			mov eax, [esi + Ball.x_Vel]
			mov ecx, [@@speed]
			div ecx
			mov [esi + Ball.x_Vel], eax
			
			mov eax, [esi + Ball.y_Vel]
			div ecx
			mov [esi + Ball.y_Vel], eax
			ret
	; add ebx, [Ball_Struct_Size]
		
		; mov eax, [Ball_Amount]
		; mov ecx, [Ball_Struct_Size]
		; xor edx, edx
		; imul ecx
		
		; cmp ebx, ecx
		; jle @@balls_down
	
		@@paddle_down:
			mov eax, [edi + Brick.Width]
			mov ecx, [@@sizepaddle]
			div ecx
			mov [edi + Brick.Width], eax
			ret

ENDP applyPowerup

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
	USES eax, ecx
	
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
		
		cmp ebx, 3
		je @@levelselect
		
		cmp al, 114				; 114 is ASCII code for 'r'
		je @@gui_1				; Jump if equal to level
		
		cmp al, 82				; 82 is ASCII code for 'R'
		je @@gui_1				; Jump if equal to level
		
		cmp al, 102				; 102 is ASCII code for 'f'
		je short @@gui_2				; Jump if equal to endless
		
		cmp al, 70				; 70 is ASCII code for 'F'
		je @@gui_2				; Jump if equal to endless
		
		@@levelselect:	
			cmp al, 13				; 13 is ASCII code for 'Enter'
			je @@enter_pressed		; Jump if equal to exit
			
			cmp ebx, 3
			jne @@continue
			
			cmp al, 115
			je @@left
			
			cmp al, 83
			je @@left
			
			cmp al, 100
			je @@right
			
			cmp al, 68
			je @@right
		
		@@continue:
			ret
			jmp @@press_check
		
	@@gui_1:
		call fillRectangle, 192, 137, 25, 25, 0, 0, 0
		call fillRectangle, 192, 104, 25, 25, 1, offset dataread_Arrow, 0
		
		mov ebx, 1	; Play index
		
		ret
		
	@@gui_2: 
		call fillRectangle, 192, 104, 25, 25, 0, 0, 0
		call fillRectangle, 192, 137, 25, 25, 1, offset dataread_Arrow, 0
	
		mov ebx, 2	; Exit index
		
		ret

	@@enter_pressed:
		call checkSprite
		
		cmp ebx, 3
		je @@press_check
		
		mov [Skip_GUI], 1
		
		ret		
		
	@@left:
		mov ecx, 0
		cmp [index], 0
		jle @@borderleft
		
		mov eax, 100
		xor edx, edx
		imul [index]
		add eax, 13
		call drawRectangle, eax, 61, 94, 60, 1, 15

		@@continueleft:
			dec [index]
			mov ecx, 2
			cmp [index], 0
			jge @@displaysprite
		
		inc [index]
		@@borderleft:
			ret
		
	@@right:
		mov ecx, 1
		cmp [index], 2
		jge @@borderright
		
		mov eax, 100
		xor edx, edx
		imul [index]
		add eax, 13
		call drawRectangle, eax, 61, 94, 60, 1, 15
		
		@@continueright:
			inc [index]
			mov ecx, 2
			cmp [index], 2
			jle @@displaysprite
			
			dec [index]
			
		@@borderright:
			ret
		
		@@displaysprite:
			mov eax, 100
			xor edx, edx
			imul [index]
			add eax, 13
			
			cmp ecx, 2
			je @@drawselected
			
			call drawRectangle, eax, 61, 94, 60, 1, 15
			
			cmp ecx, 0
			je @@continueleft
			
			cmp ecx, 1
			je @@continueright
			
			ret
			
			@@drawselected:
				call drawRectangle, eax, 61, 94, 60, 1, 2
				
				ret

ENDP gui

PROC checkSprite
	
	cmp ebx, 1
	je @@levelspage
	
	cmp ebx, 2
	je @@exit_game
	
	cmp ebx, 3
	je @@level_initialize
	
	ret
	
	@@levelspage:
		call ReadFile, offset level_page, offset dataread_GUI, DATASIZE_FS
		call fillRectangle, 0, 0, 320, 200, 0, 0, 0
		call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
		
		mov ebx, 3
		
		ret
	
	@@level_initialize:
		xor ebx, ebx
		
		cmp [index], 0
		je @@level1
		
		cmp [index], 1
		je @@level2
		
		ret
		
		@@level1:
			call ReadFile, offset level1, offset dataread_Level, DATASIZE_Bricks
			call initializeLevel, offset dataread_Level, 41
			call initializePowerup, [Powerup_Amount]
			
			ret
		
		@@level2:
			call ReadFile, offset level2, offset dataread_Level, DATASIZE_Bricks
			call initializeLevel, offset dataread_Level, 2
			call initializePowerup, [Powerup_Amount]
			
			ret
		
	@@exit_game:
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
	
	mov eax, [@@Brick_Amount]
	mov [Level_Size], eax
	
	; print to screen test data
	mov esi, [@@dataptr]		; Initialize datapointer value into esi to read the right values of the file
	lea edi, [level_bricks]		; Load effective adress of the level_bricks array which contain the Brick structs of the level
	
	; Calculate the amount of Bricks that need to be read from the file
	xor edx, edx				; Set edx:eax to eax for multiplication
	mov eax, [Brick_Struct_Size]					; Initalize amount of bytes in the Brick struct to eax
	mov ebx, [@@Brick_Amount]	; Initalize amount of Bricks in the level to ebx
	imul ebx					; Signed multiplication of the amount of Bricks to the amount of bytes to calculate the maximum amount of bytes to be read from the file
	mov ecx, eax				; Store eax in ecx because eax will be overwritten
	
	xor ebx, ebx				; Set ebx to zero to count correctly trough the level_bricks array
	
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
		
		lodsd									; Loads a word (2 byte) value into ax
		mov [edi + ebx + Brick.Color], eax		; Assign the Color value from the file into the Brick struct
		
		lodsd									; Loads a byte (1 byte) value into al
		mov [edi + ebx + Brick.Active], eax		; Assign the Active value from the file into the Brick struct
		
		add ebx, [Brick_Struct_Size]		; Add amount of bytes in Brick struct to continue to the next Brick
		cmp ebx, ecx	; Check to see if all the Bricks needed for the level are created
		jl looptest	
	
	call fillBackground, 0
	call drawBricks, [@@Brick_Amount]
	
	mov eax, [edi + Brick.Width]
	shl eax,2
	mov [edi + Brick.Width], eax
	
	;When initializing level also adjust ball to scale maybe hardcode this once we tested right
	lea esi, [game_ball]
	call scaleUp, [esi + Ball.x_Pos]
	mov [esi + Ball.x_Pos],eax
	
	call scaleUp, [esi + Ball.y_Pos]
	mov [esi + Ball.y_Pos],eax
	
	call scaleUp, [esi + Ball.Radius]    
	mov [esi + Ball.Radius], eax
	
	ret

ENDP initializeLevel

PROC initializePowerup
	ARG @@Powerup_Amount:dword
	USES eax, edi
	push edi
	
	lea edi, [powerups]
	xor ecx, ecx
	
	call ReadFile, offset powerups_file, offset dataread_Powerup, DATASIZE_Powerup
	
	@@initialize:
		; call ReadFile, offset instabr, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset instabr
		mov [edi + ecx + Powerup.Dataread], ebx			
		add ecx, [Powerup_Struct_Size]
		
		; call ReadFile, offset bigpad, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset bigpad
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
	
		; call ReadFile, offset morebal, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset morebal
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
		
		; call ReadFile, offset fastbal, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset fastbal
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
		
		; call ReadFile, offset smallpad, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset smallpad
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
		
		; call ReadFile, offset slowbal, offset dataread_Powerup, DATASIZE_Powerup
		mov ebx, offset slowbal
		mov [edi + ecx + Powerup.Dataread], ebx
		add ecx, [Powerup_Struct_Size]
		
		mov eax, [Powerup_Struct_Size]
		xor edx, edx
		mov ebx, [@@Powerup_Amount]
		imul ebx
		
		cmp ecx, eax
		jle @@initialize
		
		xor ecx, ecx
	@@loadvalues:
		lodsd
		mov [edi + ecx + Powerup.Speedmultiply], eax
		lodsd
		mov [edi + ecx + Powerup.Damagemultiply], eax 
		lodsd
		mov [edi + ecx + Powerup.Ball_amount], eax
		lodsd
		mov [edi + ecx + Powerup.Sizemultiply], eax
		
		add ecx, [Powerup_Struct_Size]
		
		mov eax, [Powerup_Struct_Size]
		xor edx, edx
		mov ebx, [@@Powerup_Amount]
		imul ebx
		
		cmp ecx, eax
		jl @@loadvalues
		
	pop edi
	ret
ENDP initializePowerup

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


; PROC drawSprite
	; ARG	 @@dataptr: dword, @@x_Pos:dword, @@y_Pos:dword, @@Width:dword, @@Height:dword
	; USES esi,ecx
	
	; push edi
	; mov eax, [@@y_Pos]	; y-coordinate
	; mov ebx, [@@x_Pos]	; x-coordinate
	; mov ecx, SCRWIDTH
	; xor edx, edx
	; imul ecx
	
	; mov edi, eax
	; add edi, ebx
	; add edi, VMEMADR
	
	; mov edx, [@@Height]
	; mov esi, [@@dataptr]
	; drawspriteloop:
		
		; mov ecx, [@@Width]
		; rep movsb

		; add edi, SCRWIDTH
		; sub edi, [@@Width]
		
		; dec edx
		; cmp edx, 0
		; jg drawspriteloop
	
	; pop edi
	; ret	
; ENDP drawSprite

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
	Speedmultiply dd ?	; ball speed multiplyer
	Damagemultiply dd ? ; ball damage multiplyer
	Ball_amount dd ?	; amount of balls
	Sizemultiply dd ?	; paddle size multiplyer
	Dataread dd ? 		; Dataread of sprite
	Active dd ?			; Activity of powerup
; total 44 bytes per Powerup/Powerdown
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
	
	
	call setVideoMode, 13h
	
	call ReadFile, offset GUI, offset dataread_GUI, DATASIZE_FS
	call fillBackground, 0
	call fillRectangle, 0, 0, 320, 200, 1, offset dataread_GUI, 0
	
	; call ReadFile, offset GUI, offset dataread_Sp, DATASIZE_Arrow
	; call fillBackground, 0
	; call drawSprite, offset dataread_Arrow, 0, 0

	@@update:                      			;time checking loop
		; mov ah, 01h
		; int 16h

		; mov ah, 00h
		; int 16h

		; cmp al, 27		;27 is ASCII code for 'ESC'
		; je exitGame

		mov ah,2Ch 								;get the system time
		int 21h    								;ch = hour cl = minute dh = second dl = 1/100 seconds

		call gui
		
		cmp [Skip_GUI], 0
		je wait_frame
		
		; call setVideoMode, 13h
		call drawBall, [Black]		;remove the ball
		call moveBall               ;move the ball
		
		cmp [Skip_GUI], 0
		je wait_frame
		
		call drawBall, [White]      ;draw the ball
		
		call updateBrick, 1, 0
		call movePowerup
		
		; call setVideoMode, 13h
		call drawPaddle, [Black] 	;remove the paddle			
		call movePaddle		        ;move the paddles (check for pressing of keys)
		call drawPaddle, [White]   	;draw the paddles with the updated positions
		
		wait_frame:
		call wait_VBLANK, 1
		jmp @@update				;after everything update again

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
	;Speed_Constant dd 9                        	; Variable used for making game slower if speed is smaller than this then it will be same as speed =0 because the division is rounded to 0
	Scaling_Factor dd 4
	Exit_Game db 0							; Exiting Boolean
	Colliding db 0							; Colliding Boolean
	Skip_GUI db 0
	; colors
	Black dd 0
	White dd 15
	
	index dd 0
	rand_seed  dd ?
	
	d_ratio dd 0
	d_hor dd 0
	d_vert dd 0
	
	; Struct size
	Brick_Struct_Size dd 48
	Powerup_Struct_Size dd 44
	
	;Level size
	Level_Size dd 0
	Powerup_Amount dd 30
	
	level1 db "level1.bin", 0
	level2 db "level2.bin", 0
	GUI db "GUI.bin", 0
	Arrow db "Arrow.bin", 0
	level_page	db "Levelgui.bin", 0
	
	powerups_file db "Powerups.bin", 0
	smallpad db "smallpad.bin", 0
	bigpad db "bigpad.bin", 0
	morebal db "morebal.bin", 0
	fastbal db "fastbal.bin", 0
	slowbal db "slowbal.bin", 0
	instabr db "instabr.bin", 0
	
	dataread_GUI db DATASIZE_FS dup (?)
	dataread_Arrow db DATASIZE_Arrow dup (?)
	dataread_Level db DATASIZE_Bricks dup (?)
	dataread_Powerup db DATASIZE_Powerup dup (?)
	
	; gui_array Sprites 2 dup (<0, 0, 0, 0>)
	level_bricks Brick 150 dup (<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>)
	Ball_Base_Vx dd 24
	Ball_Base_Vy dd -16
	game_ball Ball <157, 97, 16, -12, 3, 4>
	powerups Powerup 30 dup (<0, 0, 10, 10, 10, 0, 0, 0, 0, 0, 0>)
	
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main