;File: 	first_uart.s
;Autor: Matej Jurcik
;Datum: 7.11.2019
;Popis programu: Program vysiela na UART sekvenciu písmen MJ, na pine PA5 vysiela syncronizacne pulzy
; 				 Konstanty programu sú nastavené na baudrate 9600 


	area STM32F3xx, code, readonly
	get stm32f303xe.s

; Definované konstanty
DELAY_TIME_BIT_HALF EQU 100
DELAY_TIME_BIT_SYNC EQU 70
DELAY_TIME_CTRL EQU 274
DELAY_TIME_WORD EQU 1000
LED_PIN EQU 2
LED_MSK EQU (1 :SHL: LED_PIN)
LED_PIN5 EQU 5
LED_MSK5 EQU (1 :SHL: LED_PIN5)
GPIO_MODER_Offset EQU 0x00
GPIO_ODR_Offset   EQU 0x14
GPIO_IDR_Offset   EQU 0x10
GPIO_BSRR_Offset  EQU 0x18
CHARACTER1 EQU 2_01001101 ; písmeno M v binárnom zápise
CHARACTER2 EQU 2_01001010 ; písmeno J v binárnom zápise

; Export of important modifiers to be used in other modules e.g. in the
; startup_stm32f30x.s
	export __main
;	export SystemInit
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
LOOP
	LDR R3, =CHARACTER1
	BL SEND_CHARACTER
	BL WAIT_WORD	
	LDR R3, =CHARACTER2
	BL SEND_CHARACTER
	BL WAIT_WORD
	B LOOP

;********************************************
;* Function:	SEND_CHARACTER
;* Brief:		Odosiela ascii znak pomocou UARTu
;*       		na pine PA2
;* Input:		None
;* Output:		None
;********************************************

SEND_CHARACTER PROC
	PUSH {LR}
	LDR R4, =8
	BL TURN_OFF
	BL WAIT_BIT
LOOP_CHARACTER1
	TST R3, #0x1
	BNE TURN_ON_PIN
	BEQ TURN_OFF_PIN
STOP
	BL TURN_ON
	BL WAIT_BIT
	POP {PC}
	ENDP
;********************************************
;* Function:	WAIT_BIT_ACK
;* Brief:		Cakanie s dlzkou jedneho bitu 
;* 				pre baudrate 9600
;*				zaroven vysiela synchronizacny
;* 				pulz porebný pre kontrolu
;* Input:		None
;* Output:		None
;********************************************
WAIT_BIT_ACK 
	LDR R2, =DELAY_TIME_BIT_HALF
SUB_WAIT
	SUBS R2, #1
	BNE SUB_WAIT
	LDR R2, =DELAY_TIME_BIT_SYNC
	LDR R0, =GPIOA_ODR		;turn on pin PA5
	LDR R1, [R0]
	ORR  R1, #(LED_MSK5)
	STR R1, [R0]
SUB_WAIT2
	SUBS R2, #1
	BNE SUB_WAIT2
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]			;turn off pin PA5
	AND  R1, #(:NOT: LED_MSK5) 	       
	STR R1, [R0]  
	LDR R2, =DELAY_TIME_BIT_HALF
SUB_WAIT3
	SUBS R2, #1
	BNE SUB_WAIT3
	LSRS R3, #1
	SUBS R4, #1
	BEQ STOP
	B LOOP_CHARACTER1
;********************************************
;* Function:	WAIT_BIT 
;* Brief:		Cakanie s dlzkou jedneho bitu 
;* 				pre baudrate 9600
;* Input:		None
;* Output:		None
;********************************************
WAIT_BIT   PROC
	PUSH {LR}
	LDR R2, =DELAY_TIME_CTRL
SUBSTRACT
	SUBS R2, #1
	BNE SUBSTRACT
	POP {PC}
	ENDP
;********************************************
;* Function:	WAIT_WORD 
;* Brief:		Caka nastavenym casom prodlevy
;* Input:		None
;* Output:		None
;********************************************
WAIT_WORD   PROC
	PUSH {LR}
	LDR R2, =DELAY_TIME_WORD
WORD_WAIT
	SUBS R2, #1
	BNE WORD_WAIT
	POP {PC}
	ENDP
;********************************************
;* Function:	TURN_ON
;* Brief:		Dá logicku 1 na pin PA2,
;*				-> prepnutie ako specialna procedura
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
;* Brief:		Dá logicku 0 na pin PA2,
;*				-> prepnutie ako specialna procedura
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
;* Function:	TURN_ON_PIN
;* Brief:		Dá logicku 1 na pin PA2
;* Input:		None
;* Output:		None
;********************************************		
TURN_ON_PIN
	NOP
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, #(LED_MSK)
	STR R1, [R0]   
	B WAIT_BIT_ACK	
;********************************************
;* Function:	TURN_OFF_PIN
;* Brief:		Dá logicku 0 na pin PA2
;* Input:		None
;* Output:		None
;********************************************		
TURN_OFF_PIN
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	AND  R1, #(:NOT: LED_MSK) 
	STR R1, [R0]  
	B WAIT_BIT_ACK

;********************************************
;* Function:	GPIO_INIT
;* Brief:		Procedura inicializujuca piny PA2 a PA5,
;*              kód je inspirovany zo vzoroveho kodu od Jana Svetlika led_example.s
;* Input:		None
;* Output:		None
;********************************************
GPIO_INIT    PROC
	; Enable clock for the GPIOA and GPIOC port in the RCC.
	; Load the address of the RCC_AHBENR register.
	LDR R0, =RCC_AHBENR
	; Load the current value at address stored in R0 and store it in R1
	LDR R1, [R0]
	; Set the bit which enables the GPIOA clock by using OR (non destructive
	; operation in view of other bits).
	ORR R1, R1, #(RCC_AHBENR_GPIOAEN :OR: RCC_AHBENR_GPIOAEN)
	; povoleni hodin pro GPIO:A a GPIO_C v registru RCC_AHBENR
	
	STR R1, [R0]
	LDR R0, =GPIOA_MODER ;inicalizacia pinu PA2
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER2    
	ORR R1, R1, #GPIO_MODER_MODER2_0  
	STR R1, [R0]
	
	LDR R0, =GPIOA_MODER ;inicalizacia pinu PA5
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER5    
	ORR R1, R1, #GPIO_MODER_MODER5_0  
	STR R1, [R0]
	
	BX LR
	ENDP

	END