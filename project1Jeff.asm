$MODDE2
org 0000H
   ljmp MyProgram

FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))
CE_ADC EQU P0.3
SCLK EQU P0.2
MOSI EQU P0.1
MISO EQU P0.0

DSEG at 30H
x:   ds 4
y:   ds 4
z:	 ds 4
bcd: ds 5

BSEG
mf: dbit 1


$include(math32.asm)

CSEG
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
MyProgram:
    MOV SP, #7FH
    mov LEDRA, #0
    mov LEDRB, #0
    mov LEDRC, #0
    mov LEDG, #0
    clr mf
    LCALL InitSerialPort  
    orl P0MOD, #00001000b ; make CE_ADC (P0.3) output
	lcall INIT_SPI
	orl P0MOD, #00010000b
	
	mov z+0, #0
	mov z+1, #0
	mov z+2, #0
	mov z+3, #0
	
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
	
	jb SWA.0, Poweron
	clr P0.4
	ljmp Forever
Poweron:
	setb P0.4
	ljmp Forever
	
END
