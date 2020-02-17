;File: 	tester_v2.s
;Autor: Matej Jurcik
;Datum: 8.1.2020
;Vyuzivane rozhrania: PA7(D11) - LED0 - zo zadania L1
;					  PA6(D12) - LED1 - zo zadania L2
;					  PA5(D13) - LED2 - zo zadania L3
;					  PA0(A0) - BUTTON0  - zo zadania TL1
;					  PA1(A1) - BUTTON1  - zo zadania TL2
;Popis programu: 	  Program je sucastou riesenia ulohy Tester reakcnej doby V2 v ramci hodin B3B38VSY.
;					  Funkcionalita:
;									 Na uvod programu sa spusti uvodna hlaska programu s navodom vyuzitia testera.
;									 Po stlaceni klavesy  "s" - spustenie rezimu testovania	
;															  - v tomto rezime musi uzivatel reagovat na svetelny signal diody			
;																stlacenim spravneho tlacidla
;									 Po stlaceni klavesy  "v" - spustenie rezimu vyhodnocovania
;															  - v tomto rezime program vyhodnoti a zobrazi v terminali:
;																	- priemernu dobu reakcie uzivatela
;																	- pocet spravnych stlaceni tlacidiel TL1 a TL2
;																	- pocet chybnych pokusov uzivatela
	area user_variables, data, readwrite, align=5 ;
	export VAR_BUFFER 
VAR_BUFFER SPACE 32 ; Inicializacia bufferu, kde budu ulozene nasledovne hodnoty
					; Index			|		 0			|		 1			|		 2			|		 3			|		 4			|
					; Ulozene data	|  pocet spravnych  |  pocet spravnych  |  pocet chybnych   | index	nameranej	| index	nameranej	|
					;				|	stlaceni TL1	|	stlaceni TL2	| stlaceni TL1/TL2  | 	 hodnoty R1     | 	hodnoty R2		|
	area STM32F3xx, code, readonly
	get stm32f303xe.s

; Definované casove konstanty
TIME_LIMIT EQU	571429			; Limit 0.5s na reakciu uzivatela, pri prekroceni tohoto casu -> chybny pokus
TIME_LIMIT_HALF_SEC EQU	1666667 ; Limit predstavujúci pol sekundy						
START_FREQUENCY_TIME EQU 150000 ; Casova konstanta na dobu blikania pri prvotnom spusteni programu

; ASCII konstanty pre vstup z klavesnice
ASCII_S EQU 115
ASCII_V EQU 118
; Konstanty na manipulaciu so vsetkymi LED L1-L3
LED0_PIN EQU 7						; Konstanty LED L1
LED0_MSK EQU (1 :SHL: LED0_PIN)
LED1_PIN EQU 6						; Konstanty LED L2
LED1_MSK EQU (1 :SHL: LED1_PIN)
LED2_PIN EQU 5						; Konstanty LED L3
LED2_MSK EQU (1 :SHL: LED2_PIN)
; Konstanty na manipulaciu s tlacidlami TL1,TL2	
BUTTON0_PIN EQU 0					; Konstanty TL1
BUTTON0_MSK EQU 1
BUTTON1_PIN EQU 1					; Konstanty TL2
BUTTON1_MSK EQU 2					
BUTTONS_PRESSED_MSK EQU 3			; Maska signalizujuca stlacenie oboch tlacidiel naraz
; Konstanty pre pracu s GPIO
GPIO_MODER_Offset EQU 0x00
GPIO_ODR_Offset   EQU 0x14
GPIO_IDR_Offset   EQU 0x10
GPIO_BSRR_Offset  EQU 0x18
; Konstanty pre pracu s RAM
MDR1_RAM EQU  0x20001000 			; Pociatocna adresa zoznamu meranych hodnot reakcnych dob R1
MDR2_RAM EQU  0x20002000			; Pociatocna adresa zoznamu meranych hodnot reakcnych dob R2
BIN_TO_DEC_RAM EQU  0x20003000		; Pociatocna adresa konvertovaneho binarneho 
									; cisla na decimalnu hodnotu	
; Konstanty nutne pre vypocet reakcnej doby v milisekundach
T_LOOP EQU 7						; Pocet prikazov v cykle
T_MILISEC EQU 8000					; Pocet vykonanych prikazov za milisekundu
; Konstanty pre pracu s UARTom 
USART_CR1_Offset   EQU 0x00
USART_BRR_Offset   EQU 0x0c
USART_ISR_Offset   EQU 0x1c	
USART_RDR_Offset   EQU 0x24	
USART_TDR_Offset   EQU 0x28
	export __main
	export __use_two_region_memory
		
__use_two_region_memory
__main

ENTRY
	
;********************************************
;* Function:	MAIN
;* Brief:		Hlavná vetva programu
;* Input:		None
;* Output:		None
;********************************************
;********************************************
MAIN
	BL GPIO_INIT 			; Inicializacia periferii
	LDR R4, =UART_START_MSG
	BL SEND_MSG				; Poslanie pociatocnej spravy
	BL CLEAR_VAR_BUFFER
START
	BL START_UP_FLASHING
	LDR R0, =USART2_ISR 	; Overenie prichodu znaku cez UART 
	LDR R1, [R0] 
	LDR R2,=USART_ISR_RXNE
	TST R1, #(USART_ISR_RXNE)
	BNE CHECK_IF_S
	B START
CHECK_IF_S					; Kontrola ci prichodzi znak zodpoveda znaku "s"
	LDR R0,=USART2_RDR
	LDR R1, [R0]
	LDR R3,=ASCII_S
	CMP R1,R3
	BEQ TEST_MODE
	B START
TEST_MODE					; ZACIATOK TESTOVANIA REAKCNEJ DOBY UZIVATELA
	LDR R2,= LED2_MSK	
	BL TURN_OFF
WAIT_FOR_RELEASE			; LED nezasvieti kym nie su TL1 a TL2 pustene!
	LDR R0, =GPIOA_IDR
	LDR R1,[R0]
	LDR R2,=BUTTONS_PRESSED_MSK
	TST R2,R1
	BNE WAIT_FOR_RELEASE
	LDR R2,= TIME_LIMIT_HALF_SEC  ; Minimalna pauza pred zasvietenim diody
	BL WAIT
	LDR R0,= TIM1_CNT			  ; Cakanie nahodnu dobu podla TIM1
	LDR R2, [R0]
	LSR R2, R2, #2
	BL WAIT
	LDR R1, [R0]				  ; Na zaklade TIM1_CNT rozhodnut o zasvieteni L1/L2
	TST R1, #0x1			
	ITTEE EQ
	LDREQ R2, =LED1_MSK
	LDREQ R4, =BUTTON1_MSK
	LDRNE R2, =LED0_MSK
	LDRNE R4, =BUTTON0_MSK
	TST R1, #0x1
	ITE EQ
	LDREQ R5, =BUTTON0_MSK
	LDRNE R5, =BUTTON1_MSK 
	MOV R3,R2 						; R3 - maska_diody
	BL TURN_ON
	LDR R0, =GPIOA_IDR
	LDR R2,=TIME_LIMIT
MEASURE								; Od tejto instrukcie program meria reakcnu dobu uzivatela
									; jednotkach strojnych cyklov
	LDR R1,[R0]
	TST R1, R4
	BNE SUCCESS
	TST R1, R5
	BNE FAIL
	SUBS R2, #1
	BNE MEASURE
FAIL								; Prekrocenie stanoveneho limitu na reakciu 
	SUBS R4, #1						; alebo stlacenie nespravneho tacidla
	LDR R2,=TIME_LIMIT
	LDR R0,=VAR_BUFFER
	LDR R1,[R0, #2]
	ADD R1, #1
	STRB R1, [R0,#2]
	B RAM_WRITE
SUCCESS								; Uspesne zareagovanie uzivatela do limitu
	SUBS R4, #1
	LDR R0,=TIME_LIMIT
	SUBS R2, R0, R2
	LDR R0,=VAR_BUFFER
	TST R4,#0x1
	ITE EQ
	LDRBEQ R1,[R0,#0]
	LDRBNE R1, [R0,#1]
	ADD R1,#1
	TST R4,#0x1
	ITE EQ
	STRBEQ R1,[R0,#0]
	STRBNE R1, [R0,#1]
	B RAM_WRITE
RAM_WRITE							; Ulozenie reakcnej doby do RAM
	LDR R0,= VAR_BUFFER
	TST R4,#0x1
	ITTEE EQ
	LDRBEQ R1,[R0,#3]
	LDREQ R3,=MDR1_RAM
	LDRBNE R1, [R0,#4]
	LDRNE R3,=MDR2_RAM
	LSL R1, #2
	STR.W R2,[R3,R1]
	LSR R1, #2
	ADD	R1,#1
	TST R4,#0x1
	ITE EQ
	STRBEQ R1,[R0,#3]
	STRBNE R1,[R0,#4]
	TST R4,#0x1						; Vypnutie zvolenej diody
	ITE EQ
	LDREQ R2,=LED0_MSK
	LDRNE R2,=LED1_MSK
	BL TURN_OFF
	LDR R0,=VAR_BUFFER 				; Kontrola ci nedoslo k preteceniu premennych
	LDR R1,[R0,#2]
	CMP R1,#255
	BEQ EVALUATE_MODE
	LDR R1,[R0,#3]
	CMP R1,#255
	BEQ EVALUATE_MODE
	LDR R1,[R0,#4]
	CMP R1,#255
	BEQ EVALUATE_MODE
CHECK_IF_V
	LDR R0,=USART2_RDR				; Kontrola ci prichodzi znak je totozny s "v"
	LDR R1, [R0]
	LDR R3,=ASCII_V
	CMP R1,R3
	BNE TEST_MODE
EVALUATE_MODE						; VYHODNOTENIE NAMERANYCH UDAJOV PROGRAMOM
	LDR R2,=LED2_MSK
	BL TURN_ON
	LDR R5,=0
	BL SEND_MEASUREMENT
	LDR R5,=1
	BL SEND_MEASUREMENT
	
	LDR R4,=UART_MISTAKE_MSG		; Zobrazenie poctu chybnych stlaceni tlacidiel
	BL SEND_MSG
	LDR R0,=VAR_BUFFER
	LDR R1,=0
	LDRB R4,[R0,#2]
	BL BIN_TO_DEC_CONVERSION
	BL SEND_NUMBER_DEC_MSG
	LDR R4,=UART_LINE_SEPARATOR
	BL SEND_MSG	
	LDR R4,=UART_TEST_SEPARATOR
	BL SEND_MSG	
	LDR R4,=UART_TEST_SEPARATOR
	BL SEND_MSG	
	BL CLEAR_VAR_BUFFER
WAIT_FOR_S
	LDR R0, =USART2_ISR 			; Cakanie na prichod znaku z UARTu 
	LDR R1, [R0]
	LDR R2,=USART_ISR_RXNE
	TST R1, #(USART_ISR_RXNE)
	BNE CHECK_IF_S_AGAIN
	B WAIT_FOR_S
CHECK_IF_S_AGAIN					; Kontrola ci dany znak je "s"
	LDR R0,=USART2_RDR
	LDR R1, [R0]
	LDR R3,=ASCII_S
	CMP R1,R3
	BEQ TEST_MODE
	B WAIT_FOR_S
	LTORG 							; Direktiva LTORG vyuzita kvoli dlzke programu
;*----------KONIEC MAIN FUNKCIE--------------
;********************************************

;********************************************
;* Function:	WAIT 
;* Brief:		Cakanie s dlzkou podla poctu 
;* 				opakovaní nastavených 
;*				v registry R2
;* Input:		None
;* Output:		None
;********************************************
WAIT   PROC
	PUSH {LR}
SUBSTRACT
	SUBS R2, #1
	BNE SUBSTRACT
	POP {PC}
	ENDP

;*-Funkcie vyuzivane pri vypocte reakcnej doby-
;********************************************
;* Function:	AVERAGE
;* Brief:		Funkcia vypocita aritmeticky 
;* 				priemer zo slov umiestnenych
;*				v RAM.
;* Input:		None
;* Output:		None
;********************************************
AVERAGE PROC
	PUSH {R0,R1,R2,R3,LR}
	ADD R1, #3
	LDRB R0,[R0,R1]
	SUB R1,#3
	TST R1,#1
	ITE EQ
	LDREQ R1,=MDR1_RAM
	LDRNE R1,=MDR2_RAM
	MOV R2,R0
	CMP R2,#0
	BEQ END_AVG
	LDR R4,=0
	SUBS R2,#1
	BEQ IS_ZERO
SUMATION
	LSL R2, #2
	LDR.W R3,[R1,R2]
	ADD R4,R3
	LSR R2, #2
	SUBS R2, #1
	BNE SUMATION
	LDR.W R3,[R1,R2]
	ADD R4,R3
	UDIV R4,R4,R0
	B END_AVG
IS_ZERO
	LSL R2, #2
	LDR.W R3,[R1,R2]
	ADD R4,R3
	LSR R2, #2
END_AVG
	CMP R0,#0
	IT EQ 
	LDREQ R4,=0xFFFFFFFF
	POP {R0,R1,R2,R3,PC}
	ENDP

;********************************************
;* Function:	SYS_CYCLE_TO_MS  
;* Brief:		Funkcia prepocitavajuca 
;* 				reakcnu dobu uzivatela v cykloch  
;*				procesora na milisekundy.
;* Input:		R4 - priemerna hodnota reakcnej doby 
;* Output:		None
;********************************************
SYS_CYCLE_TO_MS PROC
	PUSH {R0,R1,LR}
	CMP R4, #0xFFFFFFFF
	BEQ END_SYS_CYCLE_TO_MS
	LDR R0,=T_LOOP
	LDR R1,=T_MILISEC
	MUL R4, R0,R4
	UDIV R4, R4,R1
END_SYS_CYCLE_TO_MS
	POP {R0,R1,PC}
	ENDP

;********************************************
;* Function:	BIN_TO_DEC_CONVERSION
;* Brief:		Funkcia prevadza hexadecimalne
;* 				cislo v registri na pole integerov 
;*				predstavujucich cifry toho isteho
;*				cisla v desiatkovej sustave. 
;*				Maximalne cislo na konverziu - 0x3E7
;* Input:		None
;* Output:		None
;********************************************
BIN_TO_DEC_CONVERSION	PROC
	PUSH {R0,R1,R2,R3,LR}
	CMP R4, #0xFFFFFFFF
	BEQ END_CONV
	LDR R0,=BIN_TO_DEC_RAM
	LDR R1,=0
SUB_HUNDRED
	ADD R1,#1
	SUBS R4,#0x64
	BCS SUB_HUNDRED
	ADD R4, #0x64
	SUB R1, #1
	STRB R1,[R0],#1
	LDR R1,=0
SUB_TEN
	ADD R1,#1
	SUBS R4,#0xA
	BCS SUB_TEN
	ADD R4, #0xA
	SUB R1, #1
	STRB R1,[R0],#1
	STRB R4,[R0],#1
	LDR R1,=0xFF
	STRB R1,[R0],#1
END_CONV
	POP {R0,R1,R2,R3,PC}
	ENDP
;----------------------------------------------
;----------------------------------------------

;---Funkcie na posielanie dat pomocou UARTu----
;********************************************
;* Function:	SEND_MEASUREMENT 
;* Brief:		Funkcia vypisujuca vysledky merania 
;* 				na teminal pocas vyhodnocovacej fazy
;*				programu.			
;* Input:		R5 - 0/1 - na zaklade ci chceme 
;*				vysledne hodnoty pre meranie R1/R2
;* Output:		None
;********************************************
SEND_MEASUREMENT PROC
	PUSH {R0,R1,R2,R3,R4,LR}
	CMP R5,#0
	ITE EQ
	LDREQ R4,=UART_EVALUATE_MSG_1
	LDRNE R4,=UART_EVALUATE_MSG_2
	BL SEND_MSG
	
	LDR R0,=VAR_BUFFER
	MOV R1,R5
	BL AVERAGE 					; R4 = priemerna hodnota cyklov
	BL SYS_CYCLE_TO_MS 			; R4 = priemerna hodnota v milisekundach
	BL BIN_TO_DEC_CONVERSION 	; hodnota je na adrese v RAM
	BL SEND_NUMBER_MSG 					; hodnota odoslana
	
	CMP R5,#0
	ITE EQ
	LDREQ R4,=UART_EVALUATE_PRESSED_MSG_1
	LDRNE R4,=UART_EVALUATE_PRESSED_MSG_2
	BL SEND_MSG
	LDRB R4,[R0,R5]
	BL BIN_TO_DEC_CONVERSION
	BL SEND_NUMBER_DEC_MSG
	LDR R4,=UART_LINE_SEPARATOR
	BL SEND_MSG
	LDR R4,=UART_LINE_SEPARATOR
	BL SEND_MSG
	POP {R0,R1,R2,R3,R4,PC}
	ENDP
;!!!!!!!!!!!!!!!!!!!!!-Nasledovne funkcie su variaciou na
;funkciu SEND_MSG zo vzoroveho programu hwuart.s-!!!!!!!!!!!!!!
;********************************************
;* Function:	SEND_NUMBER_DEC_MSG  
;* Brief:		Funkcia zobrazi cislo v dekadickom 
;* 				tvare na vystup terminalu.				
;* Input:		Je potrebne aby cislo bolo 
;*				v tvare zoznamu integerov na addrese
;*				BIN_TO_DEC_RAM.
;* Output:		None
;********************************************
		
SEND_NUMBER_DEC_MSG   PROC
	PUSH {R0,R1,R2,R3,R4,R5,LR}
	LDR R4,=BIN_TO_DEC_RAM
	LDR R5,=0
TDR_NOT_EMPTY_BIT_DEC
	LDR R0, =USART2_ISR
	LDR R1, [R0]
	TST R1, #(USART_ISR_TXE)  
	BEQ TDR_NOT_EMPTY_BIT_DEC 
	LDR R0, =USART2_TDR 
	LDRB R3,[R4],#1
	CMP R3,#0xFF
	BEQ SEND_NUMBER_DEC_MSG_END
	CMP R3,#0
	BNE WRITE_TO_UART
	CMP R5,#0
	BEQ TDR_NOT_EMPTY_BIT_DEC
WRITE_TO_UART
	ADD R3,#0x30
	STRB R3, [R0] 
	LDR R5,=1
	LDR R2, =0xF
	BL WAIT
	B TDR_NOT_EMPTY_BIT_DEC
SEND_NUMBER_DEC_MSG_END
	CMP R5, #0
	ITT EQ
	LDREQ R3,=0x30
	STRBEQ R3, [R0]
	POP {R0,R1,R2,R3,R4,R5,PC}
	ENDP

;********************************************
;* Function:	SEND_MSG  
;* Brief:		Funkcia posielajuca cez UART
;* 				pozadovany text
;*				!!!!- je prebrana zo vzoroveho programu
;* 						hwuart.s
;* Input:		R4 - adresa zaciatku pozadovanych znakov
;* Output:		None
;********************************************
SEND_MSG   PROC
	PUSH {R0,R1,R2,R3,LR}
TDR_NOT_EMPTY
	LDR R0, =USART2_ISR 
	LDR R1, [R0] 
	TST R1, #(USART_ISR_TXE)  
	BEQ TDR_NOT_EMPTY 
	LDR R0, =USART2_TDR   ;
	LDRB R3,[R4],#1
	STRB R3, [R0] 
	LDR R2, =0xF
	BL WAIT
	CMP R3,#0
	BEQ SEND_MSG_END
	B TDR_NOT_EMPTY
SEND_MSG_END
	POP {R0,R1,R2,R3,PC}
	ENDP

;********************************************
;* Function:	SEND_NUMBER_MSG
;* Brief:		Funkcia posielajuca pomocou UARTu 
;* 				priemer reacnej doby v pozadovanom
;*				formate - 0.XXX s 
;* Input:		None
;* Output:		None
;********************************************
SEND_NUMBER_MSG PROC
	PUSH {R0,R1,R2,R3,LR}
	CMP R4, #0xFFFFFFFF
	BEQ ERROR
	LDR R4,=UART_NUMBER_PREFIX
	BL SEND_MSG
	LDR R4,=BIN_TO_DEC_RAM
TDR_NOT_EMPTY_BIT
	LDR R0, =USART2_ISR 
	LDR R1, [R0] 
	TST R1, #(USART_ISR_TXE)  
	BEQ TDR_NOT_EMPTY_BIT 
	LDR R0, =USART2_TDR   
	LDRB R3,[R4],#1
	CMP R3,#0xFF
	BEQ SEND_SUFIX
	ADD R3,#0x30
	STRB R3, [R0] 
	LDR R2, =0xF
	BL WAIT
	B TDR_NOT_EMPTY_BIT
SEND_SUFIX
	LDR R4,=UART_NUMBER_SUFIX
	BL SEND_MSG
	B SEND_NUMBER_MSG_END
ERROR
	LDR R4,=ERROR_MSG_NOT_ENOUGH_MEASUREMENTS
	BL SEND_MSG
SEND_NUMBER_MSG_END
	POP {R0,R1,R2,R3,PC}
	ENDP
;----------------------------------------------
;----------------------------------------------

;------------Funkcie na manipulaciu s LED------
;********************************************
;* Function:	START_UP_FLASHING  
;* Brief:		Funkcia vykonavajuca striedave 
;* 				zapnutie a vypnutie LED pri 
;*				uvodnom zapnuti programu.
;* Input:		None
;* Output:		None
;********************************************

START_UP_FLASHING PROC
	PUSH {LR}
	LDR R2, =LED2_MSK
	BL TURN_ON
	LDR R2, =START_FREQUENCY_TIME
	BL WAIT
	LDR R2, =LED2_MSK
	BL TURN_OFF
	LDR R2, =START_FREQUENCY_TIME
	BL WAIT
	POP {PC}
	ENDP


;********************************************
;* Function:	TURN_ON
;* Brief:		Dá logicku 1 na pin danej LED,
;*				-> zasvieti LED
;* Input:		Na register R2 ide maska LED,
;*				ktoru chceme zapnut 
;* Output:		None
;********************************************
TURN_ON	PROC
	PUSH {LR}
	NOP
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, R2
	STR R1, [R0]  
	POP {PC}
	ENDP	
;********************************************
;* Function:	TURN_OFF
;* Brief:		Dá logicku 0 na pin danej LED,
;*				-> Zhasne LED
;* Input:		Na register R2 ide maska LED,
;*				ktoru chceme vypnut 
;* Output:		None
;********************************************
TURN_OFF	PROC
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	EOR R2, #0xFFFFFFFF
	AND  R1, R2     
	STR R1, [R0]   
	POP {PC}
	ENDP
;----------------------------------------------
;----------------------------------------------

;--------Funkcia pre pracu s VAR_BUFFEROM------
;********************************************
;* Function:	CLEAR_VAR_BUFFER 
;* Brief:		Inicializuje pouzivany buffer premennnych na nulove hodnoty
;* Input:		None
;* Output:		None
;********************************************
CLEAR_VAR_BUFFER PROC
	PUSH {LR}
	MOV R1, #8
	LDR R0,=VAR_BUFFER
	LDR R2,=0x0
LOOP
	STRB R2,[R0,R1]
	SUBS R1, #1
	BNE LOOP
	STRB R2,[R0,R1]
	POP {PC}
	ENDP
;----------------------------------------------
;----------------------------------------------

;-----------INICIALIZACNA FUNKCIA--------------
;********************************************
;* Function:	GPIO_INIT
;* Brief:		Procedura inicializujuca piny PA5 - PA7,
;*				nastavuje UART na komunikaciu s PC an pinoch PA2 a PA3,
;*				nastavuje a spusta periferiu TIMER1
;*              kód je inspirovany zo vzoroveho kodu od Jana Svetlika led_example.s
;* Input:		None
;* Output:		None
;********************************************
GPIO_INIT    PROC
; povolenie hodin na rozhrania GPIOA a GPIOC
	LDR R0, =RCC_AHBENR
	LDR R1, [R0]
	ORR R1,R1,#(RCC_AHBENR_GPIOAEN_Msk :OR: RCC_AHBENR_GPIOCEN_Msk)
	STR R1, [R0]

; inicalizacia na vystup pinu PA5
	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER5    
	ORR R1, R1, #GPIO_MODER_MODER5_0  
	STR R1, [R0]

; inicalizacia na vystup pinu PA6
	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER6    
	ORR R1, R1, #GPIO_MODER_MODER6_0  
	STR R1, [R0]

; inicalizacia na vystup pinu PA7
	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER7    
	ORR R1, R1, #GPIO_MODER_MODER7_0  
	STR R1, [R0]

; inicalizacia na vystup pinu PA7
	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER7    
	ORR R1, R1, #GPIO_MODER_MODER7_0  
	STR R1, [R0]

; inicalizacia UARTU - kod je prebraty z prednasky 4, zaoberaujucej sa UARTom
	; inicializacia pinov PA2 a PA3
 	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	ORR R1, R1, #(GPIO_MODER_MODER2_1 :OR: GPIO_MODER_MODER3_1) ; 
	STR R1, [R0]
	; povolenie alternujucej funkcie AF7 pre piny PA2 a PA3
	LDR R0, =GPIOA_AFRL 
	LDR R1,=((7 :SHL: GPIO_AFRL_AFRL2_Pos) :OR: (7:SHL:GPIO_AFRL_AFRL3_Pos)) 
	STR R1, [R0]
	; povolenie hodinoveho signalu pre USART2
	LDR R0, =RCC_APB1ENR 
	LDR R1, [R0] 
	ORR R1, R1, #(RCC_APB1ENR_USART2EN) 
	STR R1, [R0] 
	; nastavenie modulacnej rychlosti 9600Bd
	LDR R0, =USART2_BRR 
	LDR R1, =833   ;   8 000 000Hz/833 = 9603,8  Hz, 
	STR R1, [R0] 
	; povolenie primania a vysielania cez UART
	LDR R0, =USART2_CR1
	LDR R1, [R0] 
	ORR R1, R1, #(USART_CR1_RE:OR: USART_CR1_TE:OR: USART_CR1_UE) 
	STR R1, [R0]
	; inicializacia hodin casovaca
	LDR R0, =RCC_APB2ENR
	LDR R1, [R0]
	ORR R1,R1,#(RCC_APB2ENR_TIM1EN_Msk)
	STR R1, [R0]
	; nastavenie casovaca TIMER1 - ten je vyuzity na generovanie pseudonahody
	LDR R0, =TIM1_CR1
	LDR R1, [R0]
	ORR R1, R1, #0x1
	STR R1, [R0]

	BX LR
	ENDP
;----------------------------------------------
;----------------------------------------------
; Umiestnenie vsetkych vypisovanych hlasok programu
	area my_msg_ascii, data, readonly		
ERROR_MSG_NOT_ENOUGH_MEASUREMENTS DCB "Nedostatocny pocet merani na vyhotovenie priemeru! \r\n",0
UART_NUMBER_PREFIX DCB "0.",0
UART_NUMBER_SUFIX DCB " s\r\n",0
UART_LINE_SEPARATOR DCB "\r\n",0
UART_TEST_SEPARATOR DCB "---------------------------------------\r\n",0
UART_START_MSG DCB "Tester reakcie V2 \r\nAutor: Matej Jurcik \r\nRok: 2019 \r\n--------------\r\ns - spusti TEST\r\nv -  vyhodnot reakciu\r\n",0
UART_EVALUATE_MSG_1 DCB "Priemerny cas reakcie MR1:\r\n",0
UART_EVALUATE_PRESSED_MSG_1 DCB "Pocet stlaceni tlacidla TL1:\r\n",0
UART_EVALUATE_MSG_2 DCB "Priemerny cas reakcie MR2:\r\n",0
UART_EVALUATE_PRESSED_MSG_2 DCB "Pocet stlaceni tlacidla TL2:\r\n",0
UART_MISTAKE_MSG DCB "Pocet chybnych pokusov:\r\n",0
	ALIGN
	END