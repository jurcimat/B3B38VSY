;File: 	tester_v1.s
;Autor: Matej Jurcik
;Datum: 7.11.2019
;Vyuzivane rozhrania: PA5 - na svietenie s LED
;					  PC13 - na zistenie stavu tlacidla na doske F303RE 
;Popis programu: Program je riesenim ulohy 3a - Tester reakcnej doby
;				 Pri prvom spusteni zasvieti program vystraznu LED a po zhasnuti caka na stlacenie
;				 tlacidla.
;                Po stlaceni uzivatel caka na opätovne zasvietenie LED, kedy pusta tlacidlo.
;				 V pripade, ze uzivatel stihen pustit tlacidlo, test sa opakuje.
;                V pripade, ze uzivatel pusti tlacidlo pre zavietenim LED alebo po casovom limite,
;				 LED program sa dostane do ERROR modu, kedy LED blika vyssou frekvenciou.
;				 Z ERROR modu sa da dostat stlacením tlacidla na dobu 0.5 sekundy, v tom pripade
;				 LED vystrazne preblikne a opat sa spusti testovacia cast programu.


	area STM32F3xx, code, readonly
	get stm32f303xe.s

; Definované konstanty
WARNING_LED_TIME EQU 3333333 	; Doba svietenia vystraznej LED
PREPARE_TIME EQU 1111111		; Doba pred zasvietenim LED v testovacom mode
BLINK_TIME EQU 250000			; Doba svietenia LED v ERROR mode
MIN_ERROR_TIME EQU 500000		; Doba minimálneho podrzania tlacidla na opustenie ERROR modu
TIME_LIMIT EQU	500000			; Limit 0.5s na reakciu uzivatela, pri prekroceni tohoto casu -> prechod do error modu
; Konstanty na manipulaciu s LED na PA5
LED_PIN EQU 5
LED_MSK EQU (1 :SHL: LED_PIN)

; Konstanty pre pracu s GPIO
GPIO_MODER_Offset EQU 0x00
GPIO_ODR_Offset   EQU 0x14
GPIO_IDR_Offset   EQU 0x10
GPIO_BSRR_Offset  EQU 0x18


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
	; Initialize the GPIO
	BL GPIO_INIT
	NOP
	NOP
	BL TURN_ON 					; uvedne vystrazne zasvietenie upozornujuce na start programu
	LDR R2, =WARNING_LED_TIME	
	BL WAIT
LOOP
	BL TURN_OFF
PREPARE_TIME_WAIT 			; Caka kým nie je stlacene tlacidlo	
	LDR R0,=GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13) 
	BNE PREPARE_TIME_WAIT
	LDR R2, =PREPARE_TIME
PREPARE_TIME_WAIT2			; Cakanie na zasvietenie LED
	LDR R0,=GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13)
	BNE ERROR				; Prechod do ERROR modu v pripade predcasneho pustenia tlacidla
	SUBS R2, #1
	BNE	PREPARE_TIME_WAIT2
	BL TURN_ON				; Zasvietenie LED - impulz na ktory reaguje uzivatel
	LDR R2, =TIME_LIMIT
MEASURE						; Slucka v ktorej ma uzivatel cas na reakciu limitovana konstantou TIME_LIMIT
	LDR R0,=GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13)
	BNE SUCCESS				; Ukoncenie slucky v pripade ze uzivatel stihol reagovat v limite
	SUBS R2, #1
	BNE MEASURE
UNTIL_RELEASED					; Caka kým uzivatel nepusti tlacidlo, sem sa dostane, len ked uzivatel nestihne v cas reagovat
	LDR R0, =GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13)
	BEQ UNTIL_RELEASED				
ERROR							; ERROR cyklus v ktorom LED blika
	BL TURN_ON
	LDR R2, =BLINK_TIME
	BL WAIT
	BL TURN_OFF
	LDR R2, =BLINK_TIME
	BL WAIT
	LDR R2, =MIN_ERROR_TIME
	LDR R0, =GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13)
	BEQ ERROR_TIME
	B ERROR
ERROR_TIME						; Opustenie ERROR modu, po dlhsom potrzani tlacidla
	LDR R0, =GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	TST R1,#(1 :SHL: 13)
	BNE ERROR
	SUBS R2, #1
	BNE	ERROR_TIME
	BL TURN_ON					; Zasvietnie LED na vystraznu dobu
	LDR R2, =WARNING_LED_TIME
	BL WAIT
	B LOOP						; Opakuj test
SUCCESS
	BL WAIT						; V pripade, ze uzivatel reaguje v limitnom case, nechaj dobehnut svietenie LED
	B LOOP 						; Opakuj test
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

;********************************************
;* Function:	TURN_ON
;* Brief:		Dá logicku 1 na pin PA5,
;*				-> zasvieti LED
;* Input:		None
;* Output:		None
;********************************************
TURN_ON	PROC
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, #(LED_MSK)
	STR R1, [R0]  
	POP {PC}
	ENDP	
;********************************************
;* Function:	TURN_OFF
;* Brief:		Dá logicku 0 na pin PA5,
;*				-> Zhasne LED
;* Input:		None
;* Output:		None
;********************************************
TURN_OFF	PROC
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	AND  R1, #(:NOT: LED_MSK) 	       
	STR R1, [R0]   
	POP {PC}
	ENDP

;********************************************
;* Function:	GPIO_INIT
;* Brief:		Procedura inicializujuca piny PA2 a PA5,
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

; inicalizacia pinu PA5
	LDR R0, =GPIOA_MODER 
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER5    
	ORR R1, R1, #GPIO_MODER_MODER5_0  
	STR R1, [R0]
	
	BX LR
	ENDP

	END