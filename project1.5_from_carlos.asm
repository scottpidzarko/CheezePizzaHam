$MODDE2
org 0000H
   ljmp MyProgram
org 000BH
   ljmp ISR_Timer0
   
   
FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))

XTAL           EQU 33333333
FREQ_timer           EQU 100
TIMER0_RELOAD  EQU 65538-(XTAL/(12*FREQ_timer))

CE_ADC EQU P0.3
SCLK EQU P0.2
MOSI EQU P0.1
MISO EQU P0.0

DSEG at 30H
count10ms: ds 1
PWM:	   ds 1
x:   ds 4
y:   ds 4
z:	 ds 4
bcd: ds 5
sec: ds 1
state: ds 1
temp: ds 1

BSEG
mf: dbit 1


$include(math32.asm)

CSEG

;-------------------------------------------------------------------------------------------------------------------------
ISR_Timer0:
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    
    push acc
	push psw
	mov a, PWM
	cjne A, #10, skip_ten
	setb p0.5
	sjmp not_set_pin
skip_ten:

	cjne A, #0, skip_zero
	clr p0.5
	sjmp not_set_pin
skip_zero:

 	inc count10ms
 	mov a, count10ms
	
 	cjne a, #10, not_set
 	mov count10ms, #0

 	setb p0.5
not_set:

 	cjne a, PWM, not_set_pin
 	clr P0.5
not_set_pin:
	pop psw
	pop acc
	reti
	
;-------------------------------------------------------------------------------------------------------------------------	
Init_Timer0:
	clr TR0	
	mov TMOD,  #00000001B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
	clr TR0 ; Disable timer 0
	clr TF0
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    setb TR0 ; Enable timer 0
    setb ET0 ; Enable timer 0 interrupt
    setb EA
    ret
;-------------------------------------------------------------------------------------------------------------------------
INIT_SPI:
	orl P0MOD, #00000110b ; Set SCLK, MOSI as outputs
	anl P0MOD, #11111110b ; Set MISO as input
	clr SCLK ; Mode 0,0 default
	ret
DO_SPI_G:
	mov R1, #0 ; Received byte stored in R1
	mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
	mov a, R0 ; Byte to write is in R0
	rlc a ; Carry flag has bit to write
	mov R0, a
	mov MOSI, c
	setb SCLK ; Transmit
	mov c, MISO ; Read received bit
	mov a, R1 ; Save received bit in R1
	rlc a
	mov R1, a
	clr SCLK
	djnz R2, DO_SPI_G_LOOP
	ret
;-------------------------------------------------------------------------------------------------------------------------
; Channel to read passed in register b
Read_ADC_Channel:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	
	mov a, b
	swap a
	anl a, #0F0H
	setb acc.7 ; Single mode (bit 7).
	
	mov R0, a ; Select channel
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #03H
	mov R7, a
	
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 0 to 7
	mov R6, a
	setb CE_ADC
	lcall delay
	ret
;-------------------------------------------------------------------------------------------------------------------------
; Look-up table for 7-seg displays
T_7seg:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H
    DB 092H, 082H, 0F8H, 080H, 090H
    DB 088H, 083H


Display_BCD:
	
	mov dptr, #T_7seg

	mov a, bcd+1
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX3, a	
	
	mov a, bcd+1
	anl a, #0FH
	movc a, @a+dptr
	mov HEX2, a

	mov a, bcd+0
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX1, a
	
	mov a, bcd+0
	anl a, #0FH
	movc a, @a+dptr
	mov HEX0, a
	
	ret
;-------------------------------------------------------------------------------------------------------------------------
Display_BCD2:
	
	mov dptr, #T_7seg

	mov a, bcd+1
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX7, a	
	
	mov a, bcd+1
	anl a, #0FH
	movc a, @a+dptr
	mov HEX6, a

	mov a, bcd+0
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX5, a
	
	mov a, bcd+0
	anl a, #0FH
	movc a, @a+dptr
	mov HEX4, a
	
	ret
;-------------------------------------------------------------------------------------------------------------------------	
Delay:
	mov R3, #20
Delay_loop:
	djnz R3, Delay_loop
	ret
;-------------------------------------------------------------------------------------------------------------------------		
; Configure the serial port and baud rate using timer 2
InitSerialPort:
	clr TR2 ; Disable timer 2
	mov T2CON, #30H ; RCLK=1, TCLK=1 
	mov RCAP2H, #high(T2LOAD)  
	mov RCAP2L, #low(T2LOAD)
	setb TR2 ; Enable timer 2
	mov SCON, #52H
	ret
;-------------------------------------------------------------------------------------------------------------------------
; Send a character through the serial port
putchar:
    JNB TI, putchar
    CLR TI
    MOV SBUF, a
    RET
;-------------------------------------------------------------------------------------------------------------------------   
WaitHalfSec:
	mov R2, #90
L3: mov R1, #250
L2: mov R0, #250
L1: djnz R0, L1
	djnz R1, L2
	djnz R2, L3
	ret
;-------------------------------------------------------------------------------------------------------------------------
SendNum:

	mov a, bcd+1
	swap a
	anl a,#0fH
	orl a,#30H
	lcall putchar
	
;	jb SWA.0,skip_dot
;	mov a,#2EH
;	lcall putchar
;skip_dot:	
	mov a, bcd+1
	anl a,#0fH
	orl a,#30H
	lcall putchar
	
	mov a, bcd+0
	swap a
	anl a,#0fH
	orl a,#30H
	lcall putchar

	mov a, bcd+0
	anl a,#0fH
	orl a,#30H
	lcall putchar
	
	ret
;-------------------------------------------------------------------------------------------------------------------------
; Send a constant-zero-terminated string through the serial port
SendString:
    CLR A
    MOVC A, @A+DPTR
    JZ SSDone
    LCALL putchar
    INC DPTR
    SJMP SendString
SSDone:
    ret
;-------------------------------------------------------------------------------------------------------------------------
Hello_World:
    DB  'Hello, World!', '\r', '\n', 0
Numbers:
	DB  '0','1','2','3','4','5','6','7','8','9'
;-------------------------------------------------------------------------------------------------------------------------

Bin2Voltage:
	mov x+3, #0
	mov x+2, #0
	mov x+1, R7
	mov x+0, R6
	Load_y(1000)
	lcall mul32
	Load_y(1024)
	lcall div32
	Load_y(5)
	lcall mul32
	
	;jnb SWA.0,skip1
	Load_y(50)	
	lcall mul32
	Load_y(100)
	lcall div32
	mov y+0, z+0
	mov y+1, z+1
	mov y+2, z+2
	mov y+3, z+3
	lcall add32
	
skip1:	
	ret
	
Bin2Voltage2:
	mov x+3, #0
	mov x+2, #0
	mov x+1, R7
	mov x+0, R6
	Load_y(1000)
	lcall mul32
	Load_y(1024)
	lcall div32
	Load_y(5)
	lcall mul32
	Load_y(2730)
	lcall sub32	
	mov z+0, x+0
	mov z+1, x+1
	mov z+2, x+2
	mov z+3, x+3
skip2:	
	ret
	
;-------------------------------------------------------------------------------------------------------------------------
state0:
	cjne a, #0, state1
	mov pwm, #0
	
	jb KEY.3, state0_done
	jnb KEY.3, $ ; Wait for key release
	mov state, #1
state0_done:
	ljmp forever

state1:
	cjne a, #1, state2
	mov pwm, #100
	mov sec, #0
	mov a, #150
	clr c
	subb a, temp
	jnc state1_done
	mov state, #2
state1_done:
	ljmp forever

state2:
	cjne a, #2, state3
	mov pwm, #20
	mov a, #60
	clr c
	subb a, sec
	jnc state2_done
	mov state, #3
state2_done:
	ljmp forever

state3:
	cjne a, #3, state4
	mov pwm, #20
	mov a, #60
	clr c
	subb a, sec
	jnc state3_done
	mov state, #4
state3_done:
	ljmp forever


state4:
	cjne a, #4, state5
	mov pwm, #20
	mov a, #60
	clr c
	subb a, sec
	jnc state4_done
	mov state, #5
state4_done:
	ljmp forever

state5:
	cjne a, #5, state3
	mov pwm, #20
	mov a, #60
	clr c
	subb a, sec
	jnc state5_done
	mov state, #0
state5_done:
	ljmp forever
;-------------------------------------------------------------------------------------------------------------------------
MyProgram:
    MOV SP, #7FH
    mov LEDRA, #0
    mov LEDRB, #0
    mov LEDRC, #0
    mov LEDG, #0
    clr mf
    LCALL InitSerialPort  
    orl P0MOD, #00101000b ; make CE_ADC (P0.3) output
	lcall INIT_SPI
	lcall Init_timer0
	;orl P0MOD, #00010000b
	
	mov z+0, #0
	mov z+1, #0
	mov z+2, #0
	mov z+3, #0

	mov count10ms, #0
	mov PWM, #0	
Forever:
	mov b,#0 ;thermo
	lcall Read_ADC_Channel
	lcall Bin2Voltage
	lcall hex2bcd
	lcall display_bcd
	
	lcall waithalfsec
	lcall waithalfsec
	lcall sendNum
	mov a,#'\r'
	lcall putchar
	mov a,#'\n'
	lcall putchar
	
	mov b,#1 ;lm335
	lcall Read_ADC_Channel
	lcall Bin2Voltage2
	lcall hex2bcd
	lcall display_bcd2
	
	mov PWM, SWA
	ljmp Forever
	
END
