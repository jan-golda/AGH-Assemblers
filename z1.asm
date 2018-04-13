
; statyczne dane
data segment

	errMsg  db	'Error: Expected HEX digit$'

	one		db	'   #   $', '  ##   $', ' # #   $', '   #   $', '   #   $', '   #   $', ' ##### $'
	zero    db	'  ###  $', ' #   # $', '#     #$', '#     #$', '#     #$', ' #   # $', '  ###  $'
	
data ends

; glowny segment programu
main segment
	
	; poczatek programu
	start:
		call initStack
		call readChar
		call printNewLine
		
		call convert
		continue1:
		
		; przesuniecie ostatnich 4 bitow do lewej
		shl al, 1
		shl al, 1
		shl al, 1
		shl al, 1
		; licznik wierszy
		mov cx, 7
		; przesuniecie w tablicy one i zero
		mov bx, 0
		; petla po wierszach
		loopRow:
			; zachowywanie licznika wierszy i originalnej wartosci al
			push cx
			push ax
			; licznik bitow
			mov cx, 4
			; petla po bitach
			loopBit:
				; przesuniecie o jeden bit w lewo
				shl al, 1
				; sprawdzenie flagi przeniesienia, jest -> 1
				jc printOne
				; sprawdzenie flagi przeniesienia, nie ma -> 0
				jnc printZero
				; przejscie do nastepnego bitu
				continue2:
				loop loopBit
			; zakonczenie wiersza
			call printNewLine
			; odzyskiwanie licznika wierszy i originalnej wartosci al
			pop ax
			pop cx
			; zwiekszenie przesuniecia
			add bx, 8
			; przejscie do nastepnego wiersza
			loop loopRow
		
		
		call finish
	
	
	;========= FUNKCJE POMOCNICZE =========;
	
	; inicjalizuje stos
	initStack:
		mov	ax, seg stackTop
		mov ss, ax
		mov sp, offset stackTop
		mov ax, seg zero
		mov ds, ax
		ret
	
	; wczytuje znak z klawiatury do al (01 - wczytanie chara, z echem)
	readChar:
		mov ah, 01h
		int 21h
		ret
		
	; sprawdza czy znak w al jest cyfra w HEX, a potem zamienia go na DEC
	convert:
		; jezeli wczytany znak jest mniejszy od '0', jezeli tak mamy blad
		cmp al, '0'
		jb error
		
		; jezeli wczytany znak jest mniejszy badz rowny '9', a zatem z przedzialu '0' do '9' wlacznie, jest ok
		cmp al, '9'
		jbe convertDigit
		jbe continue1
		
		; jezeli wczytany znak jest mniejszy od 'A', a zatem z przedzialu '0' do 'A' wylacznie, mamy blad
		cmp al, 'A'
		jb error
		
		; jezeli wczytany znak jest mniejszy badz rowny 'F', a zatem z przedzialu 'A' do 'F' wlacznie, jest ok
		cmp al, 'F'
		jbe convertBigLetter
		jbe continue1
		
		; jezeli wczytany znak jest mniejszy od 'a', a zatem z przedzialu 'F' do 'a' wylacznie, mamy blad
		cmp al, 'a'
		jb error
		
		; jezeli wczytany znak jest mniejszy badz rowny 'f', a zatem z przedzialu 'a' do 'f' wlacznie, jest ok
		cmp al, 'f'
		jbe convertSmallLetter
		jbe continue1
		
		; w kazdym innym przypadku mamy blad
		ja error
	
	; zamienia znaki 'A' do 'F' na ich odpowiedniki w DEC poprzez odjecie 'A' i dodanie 10
	convertBigLetter:
        sub al, 'A'
        add al, 10
		ret
	
	
	; zamienia znaki 'a' do 'f' na ich odpowiedniki w DEC poprzez odjecie 'a' i dodanie 10
	convertSmallLetter:
        sub al, 'a'
        add al, 10
		ret
		
	
	; zamienia znaki '0' do '9' na ich odpowiedniki w DEC poprzez odjecie '0'
	convertDigit:
        sub al, '0'
		ret
	
	; wypisuje znak nowej lini, zachowuje rejestr ax i dx nie zmieniony (znaki 10 i 13)
	printNewLine:
		push dx
		push ax
		; new line
		mov dx, 13
		mov ah, 02h
		int 21h
		; carriage return
		mov dx, 10
		mov ah, 02h
		int 21h
		pop ax
		pop dx
		ret
		
	; wypisuje jedynke z przesunieciem bx, zachowuje rejestr dx nie zmieniony
	printOne:
		push dx
		mov si, offset one
		mov dx, 0
		add dx, si
		add dx, bx
		call print
		pop dx
		jmp continue2
		
	; wypisuje zero z przesunieciem bx, zachowuje rejestr dx nie zmieniony
	printZero:
		push dx
		mov si, offset zero
		mov dx, 0
		add dx, si
		add dx, bx
		call print
		pop dx
		jmp continue2
	
	; wypisuje stringa, zachowuje rejestr ax nie zmieniony (09 - wypisanie stringa)
	print:
		push ax
		mov ah, 09h
		int 21h
		pop ax
		ret
	
	; wypisuje wiadomosc o bledzie i konczy program z kodem 1 (4C - zakonczenie programu)
	error:
		mov ax, seg errMsg
		mov ds, ax
		mov dx, offset errMsg
		call print
		mov ax, 4C01h
		int 21h
	
	; konczy program z kodem 0 (4C - zakonczenie programu)
	finish:
		mov ax, 4C00h
		int 21h
		
	
main  ends

; stos
stos1   segment STACK
					dw      200 dup(?) 
		stackTop    dw      ?
stos1   ends

; wskazuje na poczatek programu
end start
