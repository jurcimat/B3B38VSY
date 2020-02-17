;*******************************************************************************
;* File: 	tlac.s
;* Date: 	12.10.2018
;* Author:	Vaclav Grim
;* Course: 	A3B38VSY - Department of Measurement
;* Brief:	Simple program to blink LED by predefined pattern
;* -----------------------------------------------------------------------------
;* 
;*******************************************************************************

	
	area STM32F3xx, code, readonly ;instructions for linker: object file generated from
	;this source file (blik_tlac.o) is executable code and has to be stored in program
	;memory section named STM32F3xx	
	get stm32f303xe.s ;load register definitions (same as #include in c)


; Extension of register definition file

GPIO_MODER_Offset EQU 0x00
GPIO_ODR_Offset   EQU 0x14
GPIO_IDR_Offset   EQU 0x10
GPIO_BSRR_Offset  EQU 0x18


	export __main ;make function __main visible to other source files, in this case
	;it is called from reset handler in startup_stm32f30x.s
	export __use_two_region_memory ;no real purpose, startup_stm32f30x.s needs to have
	;it defined but does not use it
	ENTRY ;keyword to specify start of executable code. It has no real purpose, because
	;MCU always jumps to reset vector after power-on
	
__use_two_region_memory ;dummy label to enable symbol export
__main ;after startup, reset handler jumps here
	
;********************************************
;* Function:	MAIN
;* Brief:		The main program loop, it never returns
;* Input:		None
;* Output:		None
;********************************************	
MAIN
	; Initialize the GPIO
	BL GPIO_INIT
	LDR R4,=0 ;state of LED diode
LOOP
	; Read value from GPIOC
	LDR R0,=GPIOC
	LDR R1,[R0,#GPIO_IDR_Offset]
	;Compare current value at GPIOC with previous state
	;R1=new, R3=old
	TST R1,#(1 :SHL: 13) ;check bit 13 in R1: if 1 Z=0, if 0 Z=1
	BNE NOT_PRESSED ;current value at C13 was 1
	TST R3,#(1 :SHL: 13) ;check bit i3 in R3
	BEQ NOT_PRESSED ;current value was 0 but last value was also 0
	;					(do nothing when holding the button)
PRESSED
	BL CHANGE
	LDR R0,=10
	BL WAIT_MS
	MOV R3,R1
	B LOOP
NOT_PRESSED
	;Save current state for later
	MOV R3,R1
	;Small time delay (10 ms}
	LDR R0,=10
	BL WAIT_MS
	
	B LOOP
	
TURN_ON	PROC
	
	PUSH {LR}
	LDR R0,=GPIOA
	LDR R1,=(1 :SHL: 5)
	STR R1,[R0,#GPIO_BSRR_Offset]
	LDR R4,=1
	POP {PC}
	ENDP

TURN_OFF PROC
	
	PUSH {LR}
	LDR R0,=GPIOA
	LDR R1,=(1 :SHL: (5+16))
	STR R1,[R0,#GPIO_BSRR_Offset]
	LDR R4,=0
	POP {PC}
	ENDP
CHANGE PROC
	
	PUSH {LR}
	CMP R4,#0
	BEQ TURN_ON
	BNE TURN_OFF
	POP {PC}
	ENDP
;********************************************
;* Function:	WAIT_MS
;* Brief:		Simple waiting function, not for exact timing
;* Input:		R0 number of milliseconds
;* Output:		None
;********************************************
WAIT_MS PROC
	PUSH {R0,R1,LR}
	MOV R1,#2000
	MUL R0,R0,R1
WAITLOOP
	SUBS R0,#1
	NOP
	BNE WAITLOOP
	POP {R0,R1,PC}
	ENDP
	
;********************************************
;* Function:	GPIO_INIT
;* Brief:		This procedure initializes GPIO
;* Input:		None
;* Output:		None
;********************************************
GPIO_INIT    PROC
	PUSH {LR} ;no need to save other registers here
	;first enable clock gate to GPIOs A and C
	LDR R0,=RCC_AHBENR
	LDR R1,[R0]
	ORR R1,R1,#(RCC_AHBENR_GPIOAEN_Msk :OR: RCC_AHBENR_GPIOCEN_Msk)
	STR R1,[R0]
	;LED is on GPIO A5, switch to output
	LDR R0,=GPIOA ;0x4800 0000
	LDR R1,[R0,#GPIO_MODER_Offset] ;0x4800 0000 + 0 = 0x4800 0000 
	ORR R1,R1,#(0x01 :SHL: (5*2))
	STR R1,[R0,#GPIO_MODER_Offset]
	POP {PC} ;return to main by popping return address from stack to program counter
	ENDP
	
	ALIGN ;add padding to make size of the resulting memory segment be in multiples of 32 bits
	
	END

