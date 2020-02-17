;File: 	first_uart.s
;Autor: Matej Jurcik
;Datum: 17.10.2019
;Vyuzite casti zo vzotoveho kodu led_example.s z kurzu B3B38VSY
;autor pouzitych kodov: Jan Svetlik
;Popis programu: Program blika LEDkou na pine PA5 SOS signal

;Upravy 10.10.2018 s ceskym komentarem
; volani podprogramu, nastavovani zvlast "0" a "1" na brane PA_5

;*******************************************************************************
;* File: 	led_example.s
;* Date: 	24. 4. 2017
;* Author:	Jan Svetlik
;* Course: 	A3B38MMP - Department of Measurement
;* Brief:	A very simple example of program for STM32F303RE
;* -----------------------------------------------------------------------------
;* This example shows simple usage of GPIO pin as an output for driving LED.
;* In this example, the HSI is used as the system clock, so there is no need to
;* configure anything.
;* This project can be used as a project template for programming STM32F303RE
;* microcontroller in assembler.
;*******************************************************************************
	area STM32F3xx, code, readonly
	get stm32f303xe.s

; Definition of some usefull constants goes here
DELAY_TIME EQU 270
DELAY_TIME1 EQU 500
LED_PIN EQU 2
LED_MSK EQU (1 :SHL: LED_PIN)
GPIO_MODER_Offset EQU 0x00
GPIO_ODR_Offset   EQU 0x14
GPIO_IDR_Offset   EQU 0x10
GPIO_BSRR_Offset  EQU 0x18
CHARACTER1 EQU 2_010011010
CHARACTER2 EQU 2_010010100
; pomocne informace
;GPIOC_IDR 
;GPIOA_ODR

; LED na pinu PA5
; tlacitko k zemi na PC13

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
;* Brief:		This procedure contains the main loop for the program
;* Input:		None
;* Output:		None
;********************************************

;********************************************
MAIN
	; Initialize the GPIO
	BL GPIO_INIT
	NOP
	NOP
	LDR R7, =0
LOOP
	LDR R3, =CHARACTER1
	LDR R4, =9
	BL TURN_OFF
LOOP_CHARACTER1
	BL WAIT_BIT
	LSRS R3, #1
	SUBS R4, #1
	BEQ STOP
	TST R3, #0x1
	BNE TURN_ON_PIN
	BEQ TURN_OFF_PIN
STOP
	BL TURN_ON
	BL WAIT_BIT
	BL WAIT_WORD
	LDR R3, =CHARACTER2
	LDR R4, =9
	BL TURN_OFF
;LOOP_CHARACTER2
;	BL WAIT_BIT
	;LSRS R3, #1
;	SUBS R4, #1
;	BEQ STOP2
;	TST R3, #0x00000001
;	BNE TURN_ON_LED2
;	BEQ TURN_OFF_LED2
;STOP2
;	BL TURN_ON
;	BL WAIT_BIT
;	BL WAIT_WORD
	B LOOP

;********************************************
;* Function:	WAIT
;* Brief:		
;* Input:		None
;* Output:		None
;********************************************

WAIT_BIT   PROC
	PUSH {LR}
	LDR R2, =DELAY_TIME
SUBSTRACT
	SUBS R2, #1
	BNE SUBSTRACT
	POP {PC}
	ENDP

WAIT_WORD   PROC
	PUSH {LR}
	LDR R2, =DELAY_TIME1
WORD_WAIT
	SUBS R2, #1
	BNE WORD_WAIT
	POP {PC}
	ENDP
	
TURN_ON	PROC
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, #(LED_MSK)
	STR R1, [R0]  
	POP {PC}
	ENDP	

TURN_OFF	PROC
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	AND  R1, #(:NOT: LED_MSK) 	       
	STR R1, [R0]   
	POP {PC}
	ENDP
		
TURN_ON_PIN
	NOP
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, #(LED_MSK)
	STR R1, [R0]   
	B LOOP_CHARACTER1	
		
TURN_OFF_PIN
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	AND  R1, #(:NOT: LED_MSK) 
	STR R1, [R0]  
	B LOOP_CHARACTER1
;TURN_ON_LED2
;	NOP
;	LDR R0, =GPIOA_ODR
;	LDR R1, [R0]
;	ORR  R1, #(LED_MSK)
;	STR R1, [R0]   
;	B LOOP_CHARACTER2	
		
;TURN_OFF_LED2
;	LDR R0, =GPIOA_ODR
;	LDR R1, [R0]
;	AND  R1, #(:NOT: LED_MSK)  
;	STR R1, [R0]  
;	B LOOP_CHARACTER2
	

;********************************************
;* Function:	GPIO_INIT
;* Brief:		This procedure initializes GPIO
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
	LDR R0, =GPIOA_MODER ;inicalizuje pin PA2
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER2    
	ORR R1, R1, #GPIO_MODER_MODER2_0  
	STR R1, [R0]
	
	LDR R0, =GPIOA_MODER ;inicalizuje pin PA5
	LDR R1, [R0]
	BIC R1, R1, #GPIO_MODER_MODER5    
	ORR R1, R1, #GPIO_MODER_MODER5_0  
	STR R1, [R0]
	
	BX LR
	ENDP

	END