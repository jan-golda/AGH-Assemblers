;=======================================;
;=============== STALE =================;
;=======================================;
KEY_ESC					equ 011Bh
KEY_CTRL_X				equ 2D18h
KEY_ARROW_UP			equ	4800h
KEY_ARROW_DOWN			equ	5000h
KEY_W					equ	1177h
KEY_S					equ	1F73h

BALL_COLOR				equ	07h

PADDLE_WIDTH			equ 5
PADDLE_SIZE				equ 20
PADDLE_SPEED			equ 5
PADDLE_1_COLOR			equ 07h
PADDLE_2_COLOR			equ 07h

MIN_SLEEP_TIME			equ 10000

;=======================================;
;=========== SEGMENT DANYCH ============;
;=======================================;
DATA segment
	
	; speed
	SLEEP_TIME			dw	?
	
	;paletki
	PADDLE_1_POS		dw	?
	PADDLE_2_POS		dw	?
	
	; pilka
	BALL_POS_X			dw	?
	BALL_POS_Y			dw	?
	BALL_SPEED_X		dw	?
	BALL_SPEED_Y		dw	?
	
	; wyniki
	SCORE_1				db	0
	SCORE_2				db	0
	
DATA ends

;=======================================;
;=============== MAKRA =================;
;=======================================;
; wypisuje stringa z danego miejsca w data
print macro xx
	mov dx, offset xx		; ustawienie offsetu na danego stringa
	mov ah, 09h				; (09 - wypisanie stringa)
	int 21h
endm

;=======================================;
;============ SEGMENT KODU =============;
;=======================================;
CODE segment
	start:
		; inicjalizacja
		call initStack
		call initSegments
		
	game:
		call setGraphicMode
		call setData
		
		; glowna petla
		gameLoop:
			call sleep
			call input
			call update
			call clearScreen
			call renderScore
			call renderPaddle1
			call renderPaddle2
			call renderBall
			
			jmp gameLoop
		
		
	;============ INICJALIZACJA =============;
	
	; inicjalizacja stosu
	initStack:
		mov ax, seg stakcTop
		mov ss, ax
		mov sp, offset stakcTop
		ret
	
	; ustawienie ds jako segmentu data
	initSegments:
		mov	ax, ds
		mov	es, ax
		mov	ax, seg SLEEP_TIME
		mov	ds, ax
		ret
	
	; ustawia video mode to 320x200 256 color graphics
	setGraphicMode:
		push ax
		
		mov ah, 00h				; (00 - set video mode)
		mov al, 13h				; 320x200 256 color graphics
		int 10h
		
		pop ax
		ret
	
	; ustawia video mode to 320x200 256 color graphics
	setDefaultMode:
		push ax
		
		mov ah, 00h				; (00 - set video mode)
		mov al, 03h				; 80x25 16 shades of gray text
		int 10h
		
		pop ax
		ret
	
	; ustawia poczatkowe wartosci
	setData:
		mov ds:[SLEEP_TIME],	20000
		mov ds:[PADDLE_1_POS],	90
		mov ds:[PADDLE_2_POS],	90
		mov ds:[BALL_POS_X],	160
		mov ds:[BALL_POS_Y],	100
		
		; losujemy kierunek kierunek
		mov ah, 2Ch				; (00 - get time)
		int 21h
		
		cmp dl, 50
		jl 	setDataNegX
		jge setDataPosX
		
		setDataNegX:
		mov ds:[BALL_SPEED_X],	-1
		cmp dl, 25
		jl 	setDataNegY
		jge setDataPosY
		
		setDataPosX:
		mov ds:[BALL_SPEED_X],	1
		cmp dl, 75
		jl 	setDataNegY
		jge setDataPosY
		
		setDataNegY:
		mov ds:[BALL_SPEED_Y],	-1
		ret
		
		setDataPosY:
		mov ds:[BALL_SPEED_Y],	1
		ret
		
	;=========== OBSLUGA WEJSCIA ============;
	
	; obsluguje polecenia graczy
	input:
		; sprawdza czy jest cos w buforze wejsciowym
		mov ah, 01h				; (01 - get keyboard status)
		int 16h
		jnz readInput
		ret
	
	; wczytuje z bufora wejsciowego
	readInput:
		mov ah, 00h				; (00 - wait for keystroke and read)
		int 16h
		
		; porownanie z ctrl+x (wyjscie z programu)
		cmp ax, KEY_CTRL_X
		je closeProgram
		
		; porownanie z escape (wyjscie z programu)
		cmp ax, KEY_ESC
		je closeProgram
		
		; porownanie ze strzalka w gore
		cmp ax, KEY_ARROW_UP
		je movePaddle2Up
		
		; porownanie ze strzalka w dol
		cmp ax, KEY_ARROW_DOWN
		je movePaddle2Down
		
		; porownanie z W
		cmp ax, KEY_W
		je movePaddle1Up
		
		; porownanie z S
		cmp ax, KEY_S
		je movePaddle1Down
		
		ret
		
	;============== LOGIKA GRY ==============;
	
	update:
		call speedUp
		call colisionDetect
		call moveBall
		ret
		
	speedUp:
		cmp word ptr ds:[SLEEP_TIME], MIN_SLEEP_TIME
		jle speedUpNope
		sub word ptr ds:[SLEEP_TIME], 10
		speedUpNope:
		ret
		
	colisionDetect:
		; sprawdza czy nie zdeza sie z gora planszy
		cmp word ptr ds:[BALL_POS_Y], 2
		jle colisionWithTop
		
		; sprawdza czy nie zdeza sie z dolem planszy
		cmp word ptr ds:[BALL_POS_Y], 197
		jge colisionWithBottom
		
		; sprawdza czy nie zdeza sie z lewa krawedzia planszy
		cmp word ptr ds:[BALL_POS_X], 2
		jle colisionWithLeft
		
		; sprawdza czy nie zdeza sie z prawa krawedzia planszy
		cmp word ptr ds:[BALL_POS_X], 317
		jge colisionWithRight
		
		; sprawdza czy nie zdeza sie z paletkami
		call colisionDetectPaddle1
		call colisionDetectPaddle2
		
		ret
		
	colisionWithLeft:
		inc byte ptr ds:[SCORE_2]
		jmp game
		
	colisionWithRight:
		inc byte ptr ds:[SCORE_1]
		jmp game
		
	colisionWithTop:
		mov word ptr ds:[BALL_SPEED_Y], 1
		ret
		
	colisionWithBottom:
		mov word ptr ds:[BALL_SPEED_Y], -1
		ret
		
	colisionDetectPaddle1:
		; pozycja po x
		cmp word ptr ds:[BALL_POS_X], 7
		jg colisionDetectPaddle1Nope
		
		; pozycja po y, od gory
		mov ax, word ptr ds:[PADDLE_1_POS]
		cmp word ptr ds:[BALL_POS_Y], ax
		jl colisionDetectPaddle1Nope
		
		; pozycja po y, od dolu
		add ax, PADDLE_SIZE
		cmp word ptr ds:[BALL_POS_Y], ax
		jg colisionDetectPaddle1Nope
		
		; odbicie
		jmp colisionWithPaddle1
		
		colisionDetectPaddle1Nope:
		ret
		
	colisionDetectPaddle2:
		; pozycja po x
		cmp word ptr ds:[BALL_POS_X], 313
		jl colisionDetectPaddle2Nope
		
		; pozycja po y, od gory
		mov ax, word ptr ds:[PADDLE_2_POS]
		cmp word ptr ds:[BALL_POS_Y], ax
		jl colisionDetectPaddle2Nope
		
		; pozycja po y, od dolu
		add ax, PADDLE_SIZE
		cmp word ptr ds:[BALL_POS_Y], ax
		jg colisionDetectPaddle2Nope
		
		; odbicie
		jmp colisionWithPaddle2
		
		colisionDetectPaddle2Nope:
		ret
		
	colisionWithPaddle1:
		mov word ptr ds:[BALL_SPEED_X], 1
		ret
		
	colisionWithPaddle2:
		mov word ptr ds:[BALL_SPEED_X], -1
		ret
	
	moveBall:
		mov ax, word ptr ds:[BALL_POS_X]
		add ax, word ptr ds:[BALL_SPEED_X]
		mov word ptr ds:[BALL_POS_X], ax
		
		mov ax, word ptr ds:[BALL_POS_Y]
		add ax, word ptr ds:[BALL_SPEED_Y]
		mov word ptr ds:[BALL_POS_Y], ax
		
		ret
	
	movePaddle1Up:
		sub word ptr ds:[PADDLE_1_POS], PADDLE_SPEED
		call fixPaddle1
		ret
	
	movePaddle1Down:
		add word ptr ds:[PADDLE_1_POS], PADDLE_SPEED
		call fixPaddle1
		ret
	
	movePaddle2Up:
		sub word ptr ds:[PADDLE_2_POS], PADDLE_SPEED
		call fixPaddle2
		ret
	
	movePaddle2Down:
		add word ptr ds:[PADDLE_2_POS], PADDLE_SPEED
		call fixPaddle2
		ret
		
	fixPaddle1:
		; sprawdza czy przypadniem nie mniejsze od zera
		cmp word ptr ds:[PADDLE_1_POS], 0
		jl fixPaddle1Fix1
		
		; sprawdza czy przypadniem nie wychodzi za plansze
		mov ax, 200
		sub ax, PADDLE_SIZE
		cmp word ptr ds:[PADDLE_1_POS], ax
		jg fixPaddle1Fix2
		
		; jezeli zadne z powyzszych ok
		ret
		
		fixPaddle1Fix1:
			mov word ptr ds:[PADDLE_1_POS], 0
			ret
		
		fixPaddle1Fix2:
			mov word ptr ds:[PADDLE_1_POS], ax
			ret
		
	fixPaddle2:
		; sprawdza czy przypadniem nie mniejsze od zera
		cmp word ptr ds:[PADDLE_2_POS], 0
		jl fixPaddle2Fix1
		
		; sprawdza czy przypadniem nie wychodzi za plansze
		mov ax, 200
		sub ax, PADDLE_SIZE
		cmp word ptr ds:[PADDLE_2_POS], ax
		jg fixPaddle2Fix2
		
		; jezeli zadne z powyzszych ok
		ret
		
		fixPaddle2Fix1:
			mov word ptr ds:[PADDLE_2_POS], 0
			ret
		
		fixPaddle2Fix2:
			mov word ptr ds:[PADDLE_2_POS], ax
			ret
		
	;========== FUNKCJE GRAFICZNE ===========;
		
	; czysci wyswietlacz
	clearScreen:
		push ax
		push bx
		push cx
		push dx
		
		mov ah, 06h				; (06 - scroll)
		mov al, 00h				; clear screen
		xor cx, cx				; lewy gorny rog
		xor bx, bx				; attribute on blank lines
		xor dx, 63999			; prawy gorny rog
		int 10h
		
		pop dx
		pop cx
		pop bx
		pop ax
		ret
		
	; wyswietla wynik
	renderScore:
		push ax
		push bx
		push cx
		push dx
	
		; ustawia kursor dla 1
		mov dh, 1				; row
		mov dl, 19				; column
		mov ah, 02h				; (02 - set cursor position)
		mov bh, 0				; page number
		int 10h
		
		; wyswietla wynik dla 1
		mov ah, 09h
		mov al, byte ptr ds:[SCORE_1]
		add al, '0'
		mov bh, 0
		mov bl, 08h
		mov cx, 1
		int 10h

		; ustawia kursor dla 2
		mov dh, 1				; row
		mov dl, 21				; column
		mov ah, 02h				; (02 - set cursor position)
		mov bh, 0				; page number
		int 10h
		
		; wyswietla wynik dla 2
		mov ah, 09h
		mov al, byte ptr ds:[SCORE_2]
		add al, '0'
		mov bh, 0
		mov bl, 08h
		mov cx, 1
		int 10h
		
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	
	; wyswietla paletke 1
	renderPaddle1:
		mov ah, 0Ch				; (0C - ustawia pixel)
		mov al, PADDLE_1_COLOR	; color
		mov bh, 0				; strona
		
		; wiersz rowny polozeniu paletki
		mov dx, word ptr ds:[PADDLE_1_POS]
		; koniec paletki
		mov di, dx
		add di, PADDLE_SIZE
		
		; petla wyswietlajaca
		renderPaddle1LoopRow:
			; kolumna
			mov cx, 0
			renderPaddle1LoopCol:
				int 10h
				
				inc cx
				cmp cx, PADDLE_WIDTH
				jl renderPaddle1LoopCol
			
			
			inc dx
			cmp dx, di
			jl renderPaddle1LoopRow
		
		ret
	
	; wyswietla paletke 2
	renderPaddle2:
		mov ah, 0Ch				; (0C - ustawia pixel)
		mov al, PADDLE_2_COLOR	; color
		mov bh, 0				; strona
		
		; wiersz rowny polozeniu paletki
		mov dx, word ptr ds:[PADDLE_2_POS]
		; koniec paletki
		mov di, dx
		add di, PADDLE_SIZE
		
		; petla wyswietlajaca
		renderPaddle2LoopRow:
			; kolumna
			mov cx, 320
			sub cx, PADDLE_WIDTH
			renderPaddle2LoopCol:
				int 10h
				
				inc cx
				cmp cx, 320
				jl renderPaddle2LoopCol
			
			
			inc dx
			cmp dx, di
			jl renderPaddle2LoopRow
		
		ret
		
	; wyswietla pilke
	renderBall:
		mov ah, 0Ch				; (0C - ustawia pixel)
		mov al, BALL_COLOR		; color
		mov bh, 0				; strona
		
		mov dx, word ptr ds:[BALL_POS_Y]
		sub dx, 2
		mov cx, word ptr ds:[BALL_POS_X]
		sub cx, 1
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		
		mov dx, word ptr ds:[BALL_POS_Y]
		sub dx, 1
		mov cx, word ptr ds:[BALL_POS_X]
		sub cx, 2
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		
		mov dx, word ptr ds:[BALL_POS_Y]
		mov cx, word ptr ds:[BALL_POS_X]
		sub cx, 2
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		
		mov dx, word ptr ds:[BALL_POS_Y]
		add dx, 1
		mov cx, word ptr ds:[BALL_POS_X]
		sub cx, 2
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		
		mov dx, word ptr ds:[BALL_POS_Y]
		add dx, 2
		mov cx, word ptr ds:[BALL_POS_X]
		sub cx, 1
		int 10h
		inc cx
		int 10h
		inc cx
		int 10h
		
		ret
	
	;============== POZOSTALE ===============;
	
	; zatrzymuje program na chwile w celu kontrolowania predkosci wykonywania
	sleep:
		push ax
		push cx
		push dx
		
		mov ah, 86h				; (86 - elapsed time wait)
		xor cx, cx				; czas do odczekania
		mov dx, ds:[SLEEP_TIME]		; czas do odczekania
		int 15h
		
		pop dx
		pop cx
		pop ax
		ret
	
	; przelaca sie spowrotem do trybu tekstowego i konczy program
	closeProgram:
		call setDefaultMode
		call exit
	
	; zakancza program z kodem 0
	exit:
		mov ah, 4Ch				; (4C - zakonczenie programu)
		mov al, 0				; kod zakonczenia
		int 21h

CODE ends
	
;=======================================;
;============ SEGMENT STOSU ============;
;=======================================;
STACK1 segment STACK
				dw	100 dup(?)
	stakcTop	dw	?
STACK1 ends

end start
