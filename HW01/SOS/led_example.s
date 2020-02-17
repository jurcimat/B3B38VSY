;File: 	led_example.s
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
DELAY_TIME EQU  1000000 
DELAY_TIME1 EQU  2000000   
LED_PIN EQU 5
LED_MSK EQU (1 :SHL: LED_PIN)
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
;* At the system reset, the prefetch buffer is enabled and the system clock
;* is switched on the HSI oscillator.
;* When using PLL as the clock source, be ware of the SYSCLK frequency as
;* there are rules for setting the Flash controller latency for accessing
;* the Flash memory. This mainly applies when setting the SYSCLK to high
;* frequencies.
;********************************************
MAIN
	; Initialize the GPIO
	BL GPIO_INIT
		
	; Main loop with period approximately 25 Hz.
	NOP
	NOP
LOOP
	; Delay the CPU execution by cycling within a loop for a given number of
	; cycles.
;----------------------------Moj kod------------------------------------------------------	
	BL SHORT_BLINK
	BL SHORT_BLINK
	BL SHORT_BLINK
	BL LONG_BLINK
	BL LONG_BLINK
	BL LONG_BLINK
	BL SHORT_BLINK
	BL SHORT_BLINK
	BL SHORT_BLINK
	LDR R2,  =DELAY_TIME1
	BL WAIT

	B LOOP

;----------------------------Moj kod KONIEC-----------------------------------------------	
;-----------------------------------------------------------------------------------------

;********************************************
;* Function:	WAIT
;* Brief:		This procedure waits 
;* Input:		None
;* Output:		None
;********************************************

WAIT   PROC
	PUSH {LR}
	; Delay the CPU execution by cycling within a loop for a given number of
	; cycles.
	;MOV R3, R2
	
D_WAIT
	SUBS R2, #1
	BNE D_WAIT
	POP {PC}
	ENDP

;----------------------------Moj kod---------------------------------------------------
;********************************************
;* Funkcia:	TURN_OFF
;* Popis:		Funkcia vypinajuca LED
;* Input:		None
;* Output:		None
;********************************************

TURN_OFF	PROC
	;pozicany kod od Jana Svetlika na vypinanie LEDky
	PUSH {LR}
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	AND  R1, #(:NOT: LED_MSK) ;vynuluj bit pro LED
	          ;  konstrukce (:NOT: LED_MSK) predstavuje negovanou hodnotu symbolu LED_MSK;
			  ; tedy na pozici  bitu 5 bude nula, ostatni  jsou jednicky 
	STR R1, [R0]   ; Toggle the output pin that drives the LED e.g. PA5.
	POP {PC}
	ENDP

;********************************************
;* Funkcia:		TURN_ON
;* Popis:		Funkcia zapinajuca LED
;* Input:		None
;* Output:		None
;********************************************
		

TURN_ON	PROC
	
	PUSH {LR}
	;borrowed code for turning on LED
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	ORR  R1, #(LED_MSK)
	STR R1, [R0]   ; Toggle the output pin that drives the LED e.g. PA5.
	POP {PC}
	ENDP	
;********************************************
;* Funkcia:		SHORT_BLINK
;* Popis:		Kratke bliknutie LEDkou
;* Input:		None
;* Output:		None
;********************************************

SHORT_BLINK PROC
	
	PUSH {LR}
	LDR R2,  =DELAY_TIME
	BL TURN_ON
	BL WAIT
	LDR R2,  =DELAY_TIME
	BL TURN_OFF
	BL WAIT
	POP {PC}
	ENDP
;********************************************
;* Funkcia:		LONG_BLINK
;* Popis:		Dlhe bliknutie LEDkou
;* Input:		None
;* Output:		None
;********************************************
LONG_BLINK PROC
	
	PUSH {LR}
	LDR R2,  =DELAY_TIME1
	BL TURN_ON
	BL WAIT
	LDR R2,  =DELAY_TIME
	BL TURN_OFF
	BL WAIT	
	POP {PC}
	ENDP	

;----------------------------Moj kod KONIEC-----------------------------------------------	
;-----------------------------------------------------------------------------------------

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
	
	; Configure the PA5 pin as the output
	LDR R0, =GPIOA_MODER
	LDR R1, [R0]
	; Mask the MODER group of bits which belongs to the pin 5. It is in case
	; there was a different value written in these bits, eg. "01" -> "10" so we
	; need to clear them first and then write them using binary OR. This is not
	; needed in case of configuration after reset, when these bits are all set
	; to 0, but it is needed during reconfiguration at runtime. At the system
	; reset most of the pins are configured as inputs.
	BIC R1, R1, #GPIO_MODER_MODER5    ; This clears the group of bits MODER5
	ORR R1, R1, #GPIO_MODER_MODER5_0  ; The final value is "01" at MODER5

	; Now the pin PA5 is configured as the general purpose output. The new value
	; to be stored back to the GPIOA_MODER register is 0xA8000020.
	STR R1, [R0]
	
	BX LR
	ENDP
	
	
;********************************************
;* Function:	SystemInit
;* Brief:		System initialization procedure. This function is implicitly
;*				generated by IDEs when creating new C project. It can be thrown
;*				away or the clock, GPIO, etc. configuration can be put here.
;* Input:		None
;* Output:		None
;********************************************
;SystemInit
;
;	BX LR

	ALIGN
	
	END