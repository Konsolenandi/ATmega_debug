;
; Atmega8_Debug.asm
;
; Created: 14.08.2019 20:29:57
; Author : Student
;
.equ	TRUE			=	1
.equ	FALSE			=	0
.equ	TIM2_DIVIDER	=	0b011		; Has to be 111 (=/1024), 110 (=/256), 101(=/128), 100(=/64), 011(=/32), 010(=/8), 001 (=/1)
.equ	RXBUF_SIZE		=	16			; Size of UART Receive buffer; Mustn't exceed 256
.equ	TXBUF_SIZE		=	16			; Size of UART Transmit buffer; Mustn't exceed 256
.equ	LINE_BEGIN		=	'<'

.def	TIMSYSL			=	r5			; Low byte. Don't use system timer registers anywhere else
.def	TIMSYSH			=	r6			; High byte

.include "RAM.asm"

.cseg
.org 0x0000
	rjmp init
;.org 0x0001         
;	rjmp   EXT_INT0       ; IRQ0 Handler
;.org 0x0002         
;	rjmp   EXT_INT1       ; IRQ1 Handler
.org 0x0003         
	rjmp   TIM2_COMP      ; Timer2 Compare Handler
;.org 0x0004         
;	rjmp   TIM2_OVF       ; Timer2 Overflow Handler
;.org 0x0005         
;	rjmp   TIM1_CAPT      ; Timer1 Capture Handler
;.org 0x0006         
;	rjmp   TIM1_COMPA     ; Timer1 CompareA Handler
;.org 0x0007         
;	rjmp   TIM1_COMPB     ; Timer1 CompareB Handler
;.org 0x0008         
;	rjmp   TIM1_OVF       ; Timer1 Overflow Handler
;.org 0x0009         
;	rjmp   TIM0_OVF       ; Timer0 Overflow Handler
;.org 0x000a         
;	rjmp   SPI_STC        ; SPI Transfer Complete Handler
;.org 0x000b         
;	rjmp   USART_RXC      ; USART RX Complete Handler
;.org 0x000c         
;	rjmp   USART_UDRE     ; UDR Empty Handler
.org 0x000d         
	rjmp   USART_TXC      ; USART TX Complete Handler
;.org 0x000e         
;	rjmp   ADC_Ready	  ; ADC Conversion Complete Handler
;.org 0x000f         
;	rjmp   EE_RDY         ; EEPROM Ready Handler
;.org 0x0010         
;	rjmp   ANA_COMP       ; Analog Comparator Handler
;.org 0x0011         
;	rjmp   TWSI           ; Two-wire Serial Interface Handler
;.org 0x0012         
;	rjmp   SPM_RDY        ; Store Program Memory Ready Handler
.org 0x0013

; Interrupts must push used registers no matter if they are caller- or callee-saved

; SYSTEM TIMER
TIM2_COMP:	; Update System Timer = TIMSYSH|TIMSYSL
	push	r16
	clr		r16
	inc		TIMSYSL
	adc		TIMSYSH,r16
	mov		r16,	TIMSYSL
	cpi		r16,	250
	breq	ms250_passed
TIM2_COMP_end:
	pop		r16
reti
ms250_passed:
	push	XH
	push	XL
	ldi		XH,		HIGH(ispassed_250ms)
	ldi		XL,		LOW(ispassed_250ms)
	ldi		r16,	TRUE
	st		X,		r16
	pop		XL
	pop		XH	
rjmp TIM2_COMP_end

; UART Transmission
USART_TXC:
	push	r2
	push	r16
	push	r17
	push	YH
	push	YL

	ldi		YH,		HIGH(UART_TX_P)
	ldi		YL,		LOW(UART_TX_P)
	ld		r16,	Y+		; Load current index into register (UART_TX_P)
	ld		r17,	Y		; Load data length into register (UART_TX_LEN)

	clr		r2
	ldi		YH,		HIGH(UART_TX_BUF)
	ldi		YL,		LOW(UART_TX_BUF)
	add		YL,		r16
	adc		YH,		r2		; Get address of current byte to send
	ld		r2,		Y

	out		UDR,	r2		; Begin transmission

	inc		r16
	cp		r16,	r17
	brlo	USART_tx_notdone	; End of data reached
	cbi		UCSRB,	TXCIE	; Disable Interrupt
	rjmp	USART_TXC_end
USART_tx_notdone:	
	ldi		YH,		HIGH(UART_TX_P)
	ldi		YL,		LOW(UART_TX_P)
	st		Y,		r16		; Store next index

USART_TXC_end:
	pop		YL
	pop		YH
	pop		r17
	pop		r16
	pop		r2
reti


; End of Interrupt routines
; ---------------------------------------------

init:
; Deactivate Interrupts in init
	cli
;Initialization of Stack
	ldi		r16,	high(RAMEND)					; Main program start
	out		SPH,	 r16
	ldi		r16,	low(RAMEND)
	out		SPL,	r16								; Set Stack Pointer to top of RAM

; Init USART
	rcall	USART_Init

; Initialize system timer
	clr		r5
	clr		r6

;Initialization of Timer/Counter2
	;Control Register	|	Clear Timer on Compare Match (CTC) -> WGM2x = 10
	ldi		r16,	(0<<FOC2)|(1<<WGM21)|(0<<WGM20)|(0<<COM21)|(0<<COM20)|TIM2_DIVIDER
	out		TCCR2,	r16
	ldi		r16,	250
	out		OCR2,	r16
	; -> No Output Compare on pin and no PWM
;Set Timer0-2 Interrupts
	ldi		r16,	(1<<OCIE2)|(0<<TOIE2)|(0<<TICIE1)|(0<<OCIE1A)|(0<<OCIE1B)|(0<<TOIE1)|(0<<TOIE0)
	out		TIMSK,	r16
	; -> Enable Output Compare of Timer2

; Enable interrupt for normal operation
	sei

	clr		r17
; Replace with your application code
loop:
	ldi		XH,		HIGH(ispassed_250ms)
	ldi		XL,		LOW(ispassed_250ms)
	ld		r16,	X	
	cpi		r16,	TRUE
	breq	schedule_250ms
rjmp loop
schedule_250ms:
	ldi		r16,	FALSE
	st		X,		r16
	; Insert user code here

	; End of user code
	inc		r17
	cpi		r17,	4
	brsh	schedule_1s
rjmp loop
schedule_1s:
	clr		r17
	rcall	TESTBUF_Init

	ldi		r16,	6
	mov		r12,	r16
	ldi		r16,	HIGH(TESTBUF)	
	mov		r11,	r16	
	ldi		r16,	LOW(TESTBUF)
	mov		r10,	r16
	rcall USART_Transmit
rjmp loop

Debug_softBp:

TESTBUF_Init:
	ldi		XH,		HIGH(TESTBUF)
	ldi		XL,		LOW(TESTBUF)
	ldi		r16,	'A'
	st		X+,		r16
	inc		r16
	st		X+,		r16
	inc		r16
	st		X+,		r16
	inc		r16
	st		X+,		r16
	inc		r16	
	st		X+,		r16
	inc		r16
	st		X+,		r16
ret

; Inits USART with Baudrate 115200 @ 8MHz
USART_Init:
	; Set baud rate (See table in datasheet)
	ldi		r21,	0x00
	ldi		r22,	0x03
	out		UBRRH,	r21
	out		UBRRL,	r22
	; Enable receiver and transmitter
	ldi		r21,	(1<<RXEN)|(1<<TXEN)
	out		UCSRB,	r21
	; Set frame format: Asynchronous, No Parity, 1 Stop Bit, 8bit
	ldi		r21,	(1<<URSEL)|(0<<UMSEL)|(0<<UPM1)|(0<<UPM0)|(0<<USBS)|(3<<UCSZ0)
	out		UCSRC,	r21
ret

; Transmit uint8 via UART
;	input:	r10 -> Data to transmit
;	stack:	0 Bytes
USART_TransmitU8:
	; Wait for empty transmit buffer
	sbis	UCSRA,	UDRE
	rjmp	USART_Transmit
	; Put LSB data (r10) into buffer, sends the data
	out		UDR,	r10
ret

; Transmit multiple bytes via UART (uses interrupt)
;	input:	r10 (LSB), r11 (MSB)	-> data pointer
;	input:	r12						-> Length of data
;	stack:	2 Bytes
USART_Transmit:
	push	XH
	push	XL
	ldi		XH,		HIGH(UART_TX_BUF)
	ldi		XL,		LOW(UART_TX_BUF)
	mov		YH,		r11
	mov		YL,		r10
	clr		r2
	USART_Transmit_for01:
	ld		r3,		Y+
	st		X+,		r3	; ToDo: Check for memory violation
	inc		r2
	cp		r2,		r12
	brlo	USART_Transmit_for01			
	USART_Transmit_for01_end:
	; Setup for asynchronous transmission
	ldi		YH,		HIGH(UART_TX_P)
	ldi		YL,		LOW(UART_TX_P)
	clr		r2
	st		Y+,		r2	; Set index of current transmission to 0	(UART_TX_P)
	st		Y,		r12 ; Set length of current transmission		(UART_TX_LEN)
	sbi		UCSRA,	TXC		; Clear previous interrupt flag
	sbi		UCSRB,	TXCIE	; Enable interrupt
	ldi		r21,	LINE_BEGIN
	out		UDR,	r21
	pop		XL
	pop		XH
ret