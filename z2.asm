;=======================================;
;=============== STALE =================;
;=======================================;
CHAR_NEW_LINE			equ	10, 13
CHAR_TAB				equ	09h
CHAR_SPACE				equ 20h
CHAR_CR					equ 0Dh

KEY_CTRL_X				equ 18h
KEY_CTRL_S				equ 13h
KEY_ARROW_RIGHT			equ	4Dh
KEY_ARROW_LEFT			equ	4Bh
KEY_ARROW_UP			equ	48h
KEY_ARROW_DOWN			equ	50h
KEY_DELETE				equ 53h
KEY_BACKSPACE			equ 08h



;=======================================;
;=========== SEGMENT DANYCH ============;
;=======================================;
DATA segment
	
	; komunikaty
	MSG_DESC			db	'Simple console text editor writen by Jan Golda', CHAR_NEW_LINE, '$'
	MSG_USAGE			db	'Usage:', CHAR_NEW_LINE, CHAR_TAB, 'z2.exe [options] <file>', CHAR_NEW_LINE, '$'
	MSG_OPTIONS			db	'Options:', CHAR_NEW_LINE, CHAR_TAB, '-h', CHAR_TAB, 'displays help page',  CHAR_NEW_LINE, CHAR_TAB, '-r', CHAR_TAB, 'opens file in read-only mode',  CHAR_NEW_LINE, CHAR_TAB, '-m', CHAR_TAB, 'displays footer with additional information', CHAR_NEW_LINE, '$'
	MSG_SHORTCUTS		db	'Shortcuts:', CHAR_NEW_LINE, CHAR_TAB, 'Ctrl+S', CHAR_TAB, 'save to file', CHAR_NEW_LINE, CHAR_TAB, 'Ctrl+X', CHAR_TAB, 'exit editor', CHAR_NEW_LINE, '$'
	MSG_ERR_SYNTAX		db	'Error: Wrong syntax', CHAR_NEW_LINE, '$'
	MSG_ERR_OPTION		db	'Error: Unknown option', CHAR_NEW_LINE, '$'
	MSG_ERR_FILE_OPEN	db	'Error: Can not open file', CHAR_NEW_LINE, '$'
	MSG_ERR_FILE_READ	db	'Error: Can not read file', CHAR_NEW_LINE, '$'
	
	; iterface
	UI_FILE_NAME		db	'File: $'
	UI_POS				db	'Row: __ Col: __$'
	
	; flagi dotyczace opcji
	OPTION_H			db	0		; help
	OPTION_R			db	0		; read-only mode
	OPTION_M			db	0		; footer
	OPTION_FILE			db	0		; flaga czy podano nazwe pliku
	
	; dane pliku
	FILE_NAME			db	255 dup('$')
	FILE_HANDLE			dw	?
	FILE_BUFF			db	2048 dup(?)
	
	; kursor
	CURSOR_ROW			db 0
	CURSOR_COL			db 0
	
DATA ends



;=======================================;
;=============== MAKRA =================;
;=======================================;

; zakonczenie programu z danym kodem
exit macro xx
	mov ah, 4Ch				; (4C - zakonczenie programu)
	mov al, xx				; kod zakonczenia
	int 21h
endm

; wypisuje stringa z danego miejsca w data
print macro xx
	mov dx, offset xx		; ustawienie offsetu na danego stringa
	mov ah, 09h				; (09 - wypisanie stringa)
	int 21h
endm

; ustawienie kursora 'wirtualnego', nie zmieniam pozycji kursora uzytkownika
moveCursor macro row, col
	push ax
	push bx
	push dx
	
	mov dh, row				; row
	mov dl, col				; column
	mov ah, 02h				; (02 - set cursor position)
	mov bh, 0				; page number
	int 10h
	
	pop dx
	pop bx
	pop ax
endm

; wypisuje jeden znak w miejscu kursora
printOneChar macro xx
	push dx
	push ax
	mov dx, xx
	mov ah, 02h
	int 21h
	pop ax
	pop dx
endm


;=======================================;
;============ SEGMENT KODU =============;
;=======================================;
CODE segment
	start:
		; inicializaca
		call initStack
		call initSegments
		
		; wczytanie z lini polecen
		call parseInput
		
		; sprawdzenie czy nie nalezy wyswietlic strony pomocy
		cmp ds:[OPTION_H], 1
		je displayHelpPage
		
		; srawdzenie czy podano nazwe pliku
		cmp ds:[OPTION_FILE], 1
		jne SyntaxException
		
		; ustawienie edytora
		call setDisplay
		
		; proba wczytania pliku
		call loadFile
		
		; sprawdzenie czy jest ustawiona opcja tylko do odczytu
		cmp byte ptr ds:[OPTION_R], 1
		je startReadOnly
		
		; glowna petla programu
		mainLoop:
			; update graphics
			call render
			
			; wait for user input
			call waitForKeystroke
			
			; i jeszcze raz :)
			jmp mainLoop
	
	; wersja tylko do odczytu
	startReadOnly:
		moveCursor 100, 100
		; czeka na wcisniecie klawisza
		mov ah, 08h;							; (08 - oczekiwanie na nacisniecie klawisza)
		int 21h
		; porownuje z ctrl+x
		cmp al, KEY_CTRL_X
		je closeProgram
		jne startReadOnly
		
		
		
	;============ INICJALIZACJA =============;
	
	; inicjalizacja stosu
	initStack:
		mov ax, seg stakcTop
		mov ss, ax
		mov sp, offset stakcTop
		ret
	
	; przeniesienie segmentu lini komend do es i ustawienie ds jako segmentu data
	initSegments:
		mov	ax, ds
		mov	es, ax
		mov	ax, seg MSG_DESC
		mov	ds, ax
		ret
	
	;
	setDisplay:
		; set video mode
		mov ah, 00h				; (00 - set video mode)
		mov al, 03h				; 80x25 16 color text
		int 10h
		
		; jezeli opcja m jest uruchomiona wyswietl stopke
		cmp byte ptr ds:[OPTION_M], 1
		jne noFooter
		call printFooter
		noFooter:
		
		; set cursor at 0,0
		mov byte ptr ds:[CURSOR_ROW], 0
		mov byte ptr ds:[CURSOR_COL], 0
		call setCursor
		
		ret
	
	;=============== PARSER =================;
	
	; wczytuje argumenty z lini polecen
	parseInput:
		; sprawdzenie czy linia polecen nie jest pusta
		cmp	byte ptr es:[80h], 0
		je	SyntaxException
		
		; iterator po lini polecen
		mov si, 82h
		
		; petla po wejsciu
		parseLoop:
			; pomija biale znaki na poczatku
			call parseSkipWhiteSpace
			
			; sprawdza czy wejscie sie nie skonczylo (13 - CR)
			cmp byte ptr es:[si], CHAR_CR
			je parseLoopEnd
			
			; sprawdza czy zaczyna sie opcja
			cmp byte ptr es:[si], '-'
			je parseInputOption
			
			; w innm przypadku zaczyna sie nazwa pliku
			jmp parseInputFileName
		
		; sprawdza czy wejscie sie jeszcze nie skonczylo (13 - CR) i rozpoczyna nastepna petle
		parseLoopNext:
			cmp byte ptr es:[si], CHAR_CR
			je parseLoopEnd
			jne parseLoop
		
		parseLoopEnd:
		ret
	
	; usuwa wszystkie biale znaki od tego miejsca
	parseSkipWhiteSpace:
		; sprawdza czy spacja
		cmp byte ptr es:[si], CHAR_SPACE
		je parseSkipWhiteSpaceNext
		
		; sprawdza czy tab
		cmp byte ptr es:[si], CHAR_TAB
		je parseSkipWhiteSpaceNext
		
		; konczy prawdzanie
		ret
		
		;  zwieksza iterator i znowu sprawdza bialy znak
		parseSkipWhiteSpaceNext:
			inc si
			jmp parseSkipWhiteSpace
	
	; wczytuje opcje
	parseInputOption:
		; pomija znak '-'
		inc si
		
		; sprawdza symbol opcji h
		cmp byte ptr es:[si], 'h'
		je parseInputOptionH
		
		; sprawdza symbol opcji r
		cmp byte ptr es:[si], 'r'
		je parseInputOptionR
		
		; sprawdza symbol opcji m
		cmp byte ptr es:[si], 'm'
		je parseInputOptionM
		
		; jakikolwiek inny symbol jest bledny
		jmp OptionException
	
	; wczytuje opcje h
	parseInputOptionH:
		; ustawia flage opcji
		mov ds:[OPTION_H], 1
		
		; wraca do petli parsera
		inc si
		jmp parseLoopNext
	
	; wczytuje opcje r
	parseInputOptionR:
		; ustawia flage opcji
		mov ds:[OPTION_R], 1
		
		; wraca do petli parsera
		inc si
		jmp parseLoopNext
	
	; wczytuje opcje m
	parseInputOptionM:
		; ustawia flage opcji
		mov ds:[OPTION_M], 1
		
		; wraca do petli parsera
		inc si
		jmp parseLoopNext
	
	; wczytuje nazwe pliku
	parseInputFileName:
		; sprawdza czy nie podano juz nazwy pliku
		cmp ds:[OPTION_FILE], 1
		je SyntaxException
		
		; ustawia flage ze podano
		mov ds:[OPTION_FILE], 1
		
		; indeks nazwy pliku
		mov di, offset FILE_NAME
		
		; petla po nazwie
		fileNameLoop:
			; sprawdza czy nazwa sie nie skonczyla <=> czy nie jest to bialy znak albo koniec linii
			cmp byte ptr es:[si], CHAR_SPACE
			je fileNameLoopEnd
			cmp byte ptr es:[si], CHAR_TAB
			je fileNameLoopEnd
			cmp byte ptr es:[si], CHAR_CR
			je fileNameLoopEnd
			
			; przepisuje znak
			mov ah, byte ptr es:[si]
			mov byte ptr ds:[di], ah
			
			; przechodzi do nastepnej iteracji
			inc si
			inc di
			jmp fileNameLoop
			
		fileNameLoopEnd:
			; konczy nazwe pliku zerem
			mov byte ptr ds:[di+1], 0
			
			; wraca do petli parsera
			jmp parseLoop
	
	
	
	;========= OPERACJE NA PLIKU ==========;
		
	; wczytanie pliku
	loadFile:
		push ax
		push bx
		push cx
		push dx
		
		; otwarcie pliku
		mov al, 02h
		mov ah, 3dh								; (3d - otwarcie pliku)
		mov dx, offset FILE_NAME
		int 21h
		jc loadFileNope
		mov word ptr ds:[FILE_HANDLE], ax		; zapisanie uchwytu do pliku
		
		; wczytanie do buffora
		mov ah, 3fh							; (3f - odczytanie pliku)
		mov bx, word ptr ds:[FILE_HANDLE]	; uchwyt pliku
		mov cx, 2000						; ilosc bajtow do wczytania
		mov dx, offset FILE_BUFF			; buffor do ktorego wczytuje
		int 21h
		jc loadFileNope
		
		; dodanie znaku konca stringa
		mov si, ax
		mov ds:FILE_BUFF[si], '$'
		
		; wypisanie na ekran
		print FILE_BUFF
		
		; zakmniecie pliku
		mov ah, 3eh								; (3e - zamkniecie pliku)
		mov bx, word ptr ds:[FILE_HANDLE]
		int 21h
		
		loadFileNope:
		pop dx
		pop cx
		pop bx
		pop ax
		ret
		
	; save file --- TODO
	saveFile:
		push ax
		push bx
		push cx
		push dx
		push si
		push di
		
		; utworzenie pliku
		mov ah, 3ch								; (3c - utworzenie/nadpisanie pliku)
		mov cx, 0								; atrybuty pliku
		mov dx, offset FILE_NAME				; nazwa pliku
		int 21h
		jc saveFileNope
		mov word ptr ds:[FILE_HANDLE], ax		; zapisanie uchwytu do pliku
		
		; pozycja kursora
		mov dh, 0
		mov dl, 0
		; ilosc bajtow do zapisania
		mov di, 0
		; petla po linijakch
		saveLoopRow:
			mov dl, 0
			; petla po kolumnach
			saveLoopCol:
				
				; ustawienie kursora
				mov ah, 02h				; (02 - set cursor position)
				mov bh, 0				; page number
				int 10h
				
				; odczytanie znaku
				mov ah, 08h
				mov bh, 0
				int 10h
				
				; jezeli 0 pomijamy
				cmp al, 0
				je saveLoopNoWrite
				
				; przepisanie znaku
				mov ds:FILE_BUFF[di], al
				inc di
				
				saveLoopNoWrite:
				
				;warunek petli
				inc dl
				cmp dl, 78
				jl saveLoopCol
				
			; dopisanie znaku nowej linii
			mov ds:FILE_BUFF[di], 0Dh
			inc di
			mov ds:FILE_BUFF[di], 0Ah
			inc di
			
			; warunek petli
			inc dh
			cmp dh, 24
			jl saveLoopRow
		
		; zapisanie bufora do pliku
		mov ah, 40h							; (40 - zapis do pliku)
		mov bx, word ptr ds:[FILE_HANDLE]	; uchwyt pliku
		mov cx, di						; ilosc bajtow do wczytania
		mov dx, offset FILE_BUFF			; buffor z ktorego zapisuje
		int 21h
		
		; zamkniecie pliku
		mov ah, 3eh								; (3e - zamkniecie pliku)
		mov bx, word ptr ds:[FILE_HANDLE]
		int 21h
		
		saveFileNope:
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret
		
	; zamyka plik
	closeFile:
		mov ah, 3eh								; (3e - zamkniecie pliku)
		mov bx, word ptr ds:[FILE_HANDLE]
		int 21h
		ret
	
	;======= FUNKCJE WYSWIETLAJACE ========;
	
	; updatuje zawartosc edytora
	render:
		; jezeli stopka jest uruchomiona updatuje pozycje
		cmp byte ptr ds:[OPTION_M], 1
		jne renderNoFooter
			call printCursorPos
		
		renderNoFooter:
		call setCursor			; przywraca kursor
		ret
	
	; wypisuje stopke
	printFooter:
		push ax
		push bx
		push cx
		; ustawia kursor na ostatnim wierszu
		moveCursor 24, 0
		
		; ustawia tlo
		mov ah, 09h				; (09 - write character and attribute)
		mov bh, 0				; display page
		mov al, ' '				; znak (tutuaj spacja)
		mov bl, 70h				; attrybut (tutaj: 7 biale tlo; 0 czarny text)
		mov cx, 80				; ilosc znakow (tutaj caly wiersz)
		int 10h
		
		; wypisuje nazwe pliku
		moveCursor 24, 1
		print UI_FILE_NAME
		moveCursor 24, 7
		print FILE_NAME
		
		; wypisuje polozenie kursora 
		moveCursor 24, 64
		print UI_POS
		call printCursorPos
		
		pop cx
		pop bx
		pop ax
		ret
		
	; wypisuje polozenie kursora
	printCursorPos:
		push ax
		push bx
		push dx
		
		; obliczenie cyfr wiersza w systemie dziesietnym
		mov ax, 0
		mov al, byte ptr ds:[CURSOR_ROW]		; liczba do podzialu
		add al, 1								; dodanie 1 (indeksowanie od 1)
		mov dx, 0								; reszta z dzielenia
		mov bx, 10								; dzielnik
		div bx
		; przeksztalcenie na chara
		add ax, '0'
		add dx, '0'
		; wypisanie
		moveCursor 24, 69
		printOneChar ax
		moveCursor 24, 70
		printOneChar dx
		
		; obliczenie cyfr kolumny w systemie dziesietnym
		mov ax, 0
		mov al, byte ptr ds:[CURSOR_COL]		; liczba do podzialu
		add al, 1								; dodanie 1 (indeksowanie od 1)
		mov dx, 0								; reszta z dzielenia
		mov bx, 10								; dzielnik
		div bx
		; przeksztalcenie na chara
		add ax, '0'
		add dx, '0'
		; wypisanie
		moveCursor 24, 77
		printOneChar ax
		moveCursor 24, 78
		printOneChar dx
		
		
		pop dx
		pop bx
		pop ax
		ret
	
	;========= OBSŁUGA KLAWISZY ===========;
	
	waitForKeystroke:
		; czeka na wcisniecie klawisza
		mov ah, 08h;							; (08 - oczekiwanie na nacisniecie klawisza)
		int 21h
		
		; porownanie z 0, oznacza to ze jest to extended keystroke i zeby pobrac scan code trzeba jeszcze raz wywolac fukcje
		cmp al, 0
		je waitForKeystrokeExtended
		jne waitForKeystrokeNormal
		
		waitForKeystrokeNormal:
			; porownanie z ctrl+x (wyjscie z programu)
			cmp al, KEY_CTRL_X
			je closeProgram
			
			; porownanie z ctrl+s (zapisanie do pliku)
			cmp al, KEY_CTRL_S
			je saveFile
			
			; porownanie z backspace (usuniecie poprzedniego znaku)
			cmp al, KEY_BACKSPACE
			je backspaceChar
			
			; kazdy inny znak wypisuje i przesuwa kursor
			mov ah, 0
			printOneChar ax
			call moveCursorRight
			
			ret
		
		waitForKeystrokeExtended:
			; wywolanie jeszcze raz
			mov ah, 08h
			int 21h
			
			; porownanie z strzalka w prawo
			cmp al, KEY_ARROW_RIGHT
			je moveCursorRight
			
			; porownanie z strzalka w lewo 
			cmp al, KEY_ARROW_LEFT
			je moveCursorLeft
			
			; porownanie z strzalka w gore
			cmp al, KEY_ARROW_UP
			je moveCursorUp
			
			; porownanie z strzalka w dol
			cmp al, KEY_ARROW_DOWN
			je moveCursorDown
			
			; porownanie z delete (usuniecie znaku)
			cmp al, KEY_DELETE
			je deleteChar
			
			ret
	
	
		
	;========== OBSŁUGA KURSORA ===========;
	
	; ustawia kursor na pozycje przechowywana w pamieci (CURSOR_ROW, CURSOR_COL)
	setCursor:
		push ax
		push bx
		push dx
		
		mov ah, 02h					; (02 - set cursor position)
		mov bh, 0					; page number
		mov dh, byte ptr ds:[CURSOR_ROW]	; row
		mov dl, byte ptr ds:[CURSOR_COL]	; column
		int 10h
		
		pop dx
		pop bx
		pop ax
		ret
	
	; przesuwa kursor w prawo jezeli nie wykroczy przy tym z zakresu
	moveCursorRight:
		cmp byte ptr ds:[CURSOR_COL], 79		; jezeli jest aktualnie na 79 to nie przesunie sie
		jge moveCursorRightNope
		
		inc byte ptr ds:[CURSOR_COL]
		call setCursor
		
		moveCursorRightNope:
		ret
	
	; przesuwa kursor w lewo jezeli nie wykroczy przy tym z zakresu
	moveCursorLeft:
		cmp byte ptr ds:[CURSOR_COL], 0		; jezeli jest aktualnie na 0 to nie przesunie sie
		jle moveCursorLeftNope
		
		dec byte ptr ds:[CURSOR_COL]
		call setCursor
		
		moveCursorLeftNope:
		ret
	
	; przesuwa kursor w gore jezeli nie wykroczy przy tym z zakresu
	moveCursorUp:
		cmp byte ptr ds:[CURSOR_ROW], 0		; jezeli jest aktualnie na 0 to nie przesunie sie
		jle moveCursorUpNope
		
		dec byte ptr ds:[CURSOR_ROW]
		call setCursor
		
		moveCursorUpNope:
		ret
	
	; przesuwa kursor w dol jezeli nie wykroczy przy tym z zakresu
	moveCursorDown:
		cmp byte ptr ds:[CURSOR_ROW], 23		; jezeli jest aktualnie na 23 to nie przesunie sie
		jge moveCursorDownNope
		
		inc byte ptr ds:[CURSOR_ROW]
		call setCursor
		
		moveCursorDownNope:
		ret
	
	
	;============ EDYCJA TEKSTU ============;
	
	; usuwa char na pozycji kursora
	deleteChar:
		printOneChar ' '
		ret
		
	; usuwa znak przed kursorem o ile nie jest w col 0
	backspaceChar:
		cmp byte ptr ds:[CURSOR_COL], 0
		jle backspaceCharNope
		
		call moveCursorLeft
		printOneChar ' '
		
		backspaceCharNope:
		ret
	
	;=============== WYJATKI ===============;
	
	; wypisuje informacje o bledzie skladni i konczy program z kodem 1
	SyntaxException:
		print MSG_ERR_SYNTAX
		print MSG_USAGE
		exit 1
	
	; wypisuje informacje o podaniu blednej opcji i konczy program z kodem 2
	OptionException:
		print MSG_ERR_OPTION
		print MSG_OPTIONS
		exit 2
	
	; wypisuje informacje o bledzie podczas otwierania pliku i konczy program z kodem 10
	OpenFileException:
		print MSG_ERR_FILE_OPEN
		exit 10
	
	; wypisuje informacje o bledzie podczas czytania pliku i konczy program z kodem 11
	ReadFileException:
		print MSG_ERR_FILE_READ
		exit 11
	
	
	;============ STRONA POMOCY =============;
	
	; wypisuje strone pomocy i konczy program z kodem 0
	displayHelpPage:
		print MSG_DESC
		print MSG_USAGE
		print MSG_OPTIONS
		print MSG_SHORTCUTS
		exit 0
	
	; czysci ekran i wychodzi z programu z kodem 0
	closeProgram:
		; zamyka plik
		call closeFile
		
		; czyszczenie ekranu pop rzez zmiane trybu video
		mov ah, 00h				; (00 - set video mode)
		mov al, 02h				; 80x25 16 shades of gray text
		int 10h
		
		; wyjscie
		exit 0
	
CODE ends



;=======================================;
;============ SEGMENT STOSU ============;
;=======================================;
STACK1 segment STACK
				dw	100 dup(?)
	stakcTop	dw	?
STACK1 ends

end start