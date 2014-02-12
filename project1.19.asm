$MODDE2
org 0000H
   ljmp MyProgram
org 000BH
   ljmp ISR_Timer0
org 001BH
   ljmp ISR_Timer1
   
FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))

XTAL           EQU 33333333
FREQ_timer     EQU 100
TIMER0_RELOAD  EQU 65538-(XTAL/(12*FREQ_timer))

TIMER_RELOAD  EQU 65536-(XTAL/(12*2*20*FREQ_timer))

CE_ADC EQU P0.3
SCLK EQU P0.2
MOSI EQU P0.1
MISO EQU P0.0

DSEG at 30H
count10ms: ds 1
count10ms2: ds 1
PWM:	   ds 1
x:   ds 4
y:   ds 4
z:	 ds 4
bcd: ds 5
overall_time: ds 2
sec: ds 1
state: ds 1
temp: ds 1

Shiftcount: ds 1
AddressCounter: ds 1
SoakTemp: ds 1
SoakTime: ds 1
ReflowTemp: ds 1
ReflowTime: ds 1
RampTime: ds 1
DigitCount: ds 1
MenuState: ds 1	


BSEG
mf: dbit 1
timerflag: dbit 1
LCDflag: dbit 1
toggleflag: dbit 1
leftmenu: dbit 1
rightmenu: dbit 1
alarm:	dbit 1
noleadingzeroflag: dbit 1
secondsflag: dbit 1

$include(math32.asm)
$include(LCD_User_Interface_v3.asm)

CSEG

myLUT:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H        ; 0 TO 4
    DB 092H, 082H, 0F8H, 080H, 090H        ; 4 TO 9
    DB 088H, 083H, 0C6H, 0A1H, 086H, 08EH  ; A to F

Begin:
DB 0A5H, 'Begin', 0
Settings:
DB 0A5H, 'Settings', 0

Set_Parameters:
DB 0A5H, 'Set parameters', 0

Ramp_Time:
DB 0A5H, 'Ramp time', 0
Reflow_Temp:
DB 0A5H, 'Reflow temp', 0
Reflow_Time:
DB 0A5H, 'Reflow time', 0
Soak_Temp:
DB 0A5H, 'Soak temp', 0
Soak_Time:
DB 0A5H, 'Soak time', 0

Setting_Ramp_Time:
DB 'Ramp time:', 0
Setting_Reflow_Temp:
DB 'Reflow temp:', 0
Setting_Reflow_Time:
DB 'Reflow time:', 0
Setting_Soak_Temp:
DB 'Soak temp:', 0
Setting_Soak_Time:
DB 'Soak time:', 0

Ramp_to_soak:
DB 'Ramp to soak', 0
Soak:
DB 'Soak', 0
Ramp_to_peak:
DB 'Ramp to peak', 0
Reflow:
DB 'Reflow', 0
Cooling:
DB 'Cooling', 0

Back:
DB 0A5H, 'Back', 0

Error_Too_large0:
DB 'Error: Value', 0
Error_Too_large1:
DB 'greater than 255', 0
;-------------------------------------------------------------------------------------------------------------------------
; This ISR is for counting the amount of time elapsed and updates the BCD
;
ISR_Timer1:
	mov TH1, #high(TIMER0_RELOAD)
    mov TL1, #low(TIMER0_RELOAD)
    inc count10ms2
    push acc
    push psw
    push AR0
    push AR1
    push AR2
    push AR3
    
    clr c
    mov a, count10ms2
    subb a, #99
    jc ISR1_done
    
    mov a, overall_time+0
    inc a
    mov overall_time+0,a
    
    mov a, overall_time+1
    addc a, #0
    mov overall_time+1,a
    
    mov R0, x+0
    mov R1, x+1
    mov R2, x+2
    mov R3, x+3
    mov R4, bcd+0
    mov R5, bcd+1
    push AR0
    push AR1
    push AR2
    push AR3
    push AR4
    push AR5
	
    load_x(0)
	mov x+0, overall_time+0
	mov x+1, overall_time+1
	lcall hex2bcd
	setb secondsflag
	lcall DisplayLCD
	clr secondsflag
	pop AR5
	pop AR4
    pop AR3
    pop AR2
    pop AR1
    pop AR0
    mov x+0, R0
    mov x+1, R1
    mov x+2, R2
    mov x+3, R3
    mov bcd+0, R4
    mov bcd+1, R5
    
    inc sec
    mov count10ms2, #0
    ;cpl LEDRA.0

ISR1_done:
	pop AR3
    pop AR2
    pop AR1
    pop AR0
	pop psw
	pop acc
	reti
;-------------------------------------------------------------------------------------------------------------------------
; ISR for every time TIMER 0 goes.
;
;-------------------------------------------------------------------------------------------------------------------------
ISR_Timer0:
    mov TH0, #high(TIMER_RELOAD)
    mov TL0, #low(TIMER_RELOAD)
    
    push acc
	push psw
	
	jnb alarm, skip_alarm
	cpl p0.6
skip_alarm:

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
 	;clr c
    ;mov a, count10ms
    ;subb a, #9
    ;jc not_set
	
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
; Initialize timer as a 16-bit timer with TIMER_RELOAD as the value:
;
; Probably used for Counting seconds or 10ms?
;
;-------------------------------------------------------------------------------------------------------------------------

Init_Timer0:	
    
    mov TMOD,  #00010001B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
	clr TR0 ; Disable timer 0
	clr TF0
    mov TH0, #high(TIMER_RELOAD)
    mov TL0, #low(TIMER_RELOAD)
    setb TR0 ; Enable timer 0
    setb ET0 ; Enable timer 0 interrupt
    
    ;mov TMOD,  #00010000B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
	clr TR1 ; Disable timer 1
	clr TF1
    mov TH1, #high(TIMER0_RELOAD)
    mov TL1, #low(TIMER0_RELOAD)
    setb TR1 ; Enable timer 1
    setb ET1 ; Enable timer 1 interrupt
    
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
;Delay:
;	mov R3, #20
;Delay_loop:
;	djnz R3, Delay_loop
;	ret
;-------------------------------------------------------------------------------------------------------------------------		
; Configure the serial port and baud rate using timer 2
;-------------------------------------------------------------------------------------------------------------------------
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
	
WaitHalfSec2:
	lcall WaitHalfSec
	lcall WaitHalfSec
	lcall WaitHalfSec
	lcall WaitHalfSec
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
	
	mov a, #2EH
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


; Converts 
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

;-------------------------------------------------------------------------------------------------------------------------
MyProgram:
    MOV SP, #7FH
    mov LEDRA, #0
    mov LEDRB, #0
    mov LEDRC, #0
    mov LEDG, #0
	;orl P0MOD, #00010000b

	mov z+0, #0
	mov z+1, #0
	mov z+2, #0
	mov z+3, #0

	mov count10ms, #0
	mov count10ms2, #0
	mov PWM, #0	
	mov sec, #0
	mov state, #0
	mov temp, #0
	
	;====-=-=--=
	mov R4, #0
	mov R5, #0
	mov R0, #8AH
	mov b, #80H
	setb LCDflag
	clr rightmenu
	clr leftmenu
	mov MenuState, #0
	
	; Turn LCD on, and wait a bit.
    setb LCD_ON
    clr LCD_EN  ; Default state of enable must be zero
    lcall Wait40us
    
    mov LCD_MOD, #0xff ; Use LCD_DATA as output port
    clr LCD_RW ;  Only writing to the LCD in this code.
	
	mov a, #0ch ; Display on command
	lcall LCD_command
	mov a, #38H ; 8-bits interface, 2 lines, 5x7 characters
	lcall LCD_command
	lcall ClearLCD
	
	lcall ClearLCD
	mov a, #0FH
	lcall LCD_command
	setb leftmenu
	setb rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	push acc
	mov SoakTemp, #20 ;150
	mov SoakTime, #10 ;50
	mov ReflowTemp, #20 ;210
	mov ReflowTime, #10 ;45
	mov RampTime, #0
	clr alarm
	clr p0.6
    clr mf
 
    orl P0MOD, #01101000b ; make CE_ADC (P0.3) output
    clr P0.5
    clr P0.6
	

Foreverer:
	mov overall_time+0, #0
	mov overall_time+1, #0
	clr ea
	;mov a, SWC
	;jb acc.0, Pazz
	pop acc
	load_x(0)
	lcall UpdateMenu
	lcall Scroll
	push acc
	mov a, state
	cjne a, #1, Foreverer
	;ljmp Foreverer
;==-=-=-=-=-
Pazz:
	lcall Init_timer0
	LCALL InitSerialPort 
	lcall INIT_SPI
	mov state, #0
	
Forever:
	jb KEY.3, Forever_L0
	jnb KEY.3, $
	ljmp myprogram
Forever_L0:
	mov b,#0 ;thermo
	lcall Read_ADC_Channel
	lcall Bin2Voltage
	lcall hex2bcd
	lcall display_bcd
	lcall DisplayLCD
	
	Load_y(10)
	lcall div32
	mov temp, x+0
	lcall waithalfsec
	lcall sendNum
	mov a,#'\r'
	lcall putchar
	mov a,#'\n'
	lcall putchar
	
	mov b,#1 ;lm335
	lcall Read_ADC_Channel
	lcall Bin2Voltage2
	mov x+0, sec
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall hex2bcd
	lcall display_bcd2
	
	
	
	mov a, state
	mov LEDG, state
	;mov LEDRB, temp

;	cjne a, #0, state0_skip
	
state0:
	cjne a, #0, state1
;	lcall UpdateMenu
;	lcall Scroll
;	cjne a, #0, state1
;	mov pwm, #0
;	mov a, ReflowTime
;	cjne a, #0, state1switch
;	sjmp state0_done
;state1switch:
;	mov state, #1
;state0_done:
	mov state, #1
	setb alarm
	mov sec, #0
	mov count10ms2, #0
	;lcall waithalfsec
	ljmp forever

state1:
	push acc
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Ramp_to_soak
	lcall LCD_string
	pop acc
	
	clr alarm
	clr p0.6
	cjne a, #1, state2
	mov pwm, #10
	
	mov LEDRB, Soaktemp
	mov a, SoakTemp
	clr c
	dec a
	subb a, temp
	jnc state1_done
	mov state, #2
	setb alarm
	;lcall waithalfsec
	mov sec, #0
	mov count10ms2, #0
state1_done:
	ljmp forever

state2:
	push acc
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Soak
	lcall LCD_string
	mov r0, #8
	lcall Write_space
	pop acc
	
	clr alarm
	clr p0.6	
	cjne a, #2, state3
	
	
	mov a, SoakTemp
	clr c
	subb a, temp
	jnc increase_temp
	mov pwm, #0
	sjmp not_increase_temp
increase_temp:
	mov pwm, #2
not_increase_temp:

	mov LEDRB, SoakTime
	mov a, SoakTime
	clr c
	dec a
	subb a, sec
	jnc state2_done
	mov sec, #0
	mov count10ms2, #0
	mov state, #3
	setb alarm
	;lcall waithalfsec
state2_done:
	ljmp forever

state3:
	push acc
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Ramp_to_peak
	lcall LCD_string
	pop acc
	;cpl LEDRA.2;;;;;;;;;;;;;
	clr alarm
	clr p0.6
	cjne a, #3, state4
	;cpl LEDRA.3;;;;;;;;;;;;
	mov pwm, #10
	
	mov LEDRB, Reflowtemp
	mov a, ReflowTemp
	clr c
	dec a
	subb a, temp
	jnc state3_done
	;cpl LEDRA.4;;;;;;;;;;;;;;;
	mov state, #4
	;mov LEDG,state
	setb alarm
	;cpl LEDRA.4;;;;;;;;;;;;;;;
	;lcall waithalfsec
	;cpl LEDRA.5;;;;;;;;;;;;;;;
	mov sec, #0
	mov count10ms2, #0
state3_done:
	
	ljmp forever

state4:
	push acc
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Reflow
	lcall LCD_string
	mov r0, #6
	lcall Write_space
	pop acc
	;cpl LEDRA.5;;;;;;;;;;;;;;;
	clr alarm
	clr p0.6
	cjne a, #4, state5
	mov pwm, #1
	
	mov LEDRB, ReflowTime
	mov a, ReflowTime
	clr c
	dec a
	subb a, sec
	jnc state4_done
	mov state, #5
	setb alarm
	lcall waithalfsec2  ;;;;;;;;;;;;
	mov sec, #0
	mov count10ms2, #0
state4_done:
	ljmp forever

state5:
	push acc
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Cooling
	lcall LCD_string
	pop acc
	;cjne a, #5, state0
	clr alarm
	clr p0.6
	mov pwm, #0
	clr c
	mov a, temp
	subb a, #50
	jnc state5_done
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	lcall waithalfsec
	
	setb alarm
	lcall waithalfsec
	clr alarm
	clr p0.6
	
	mov sec, #0
	mov count10ms2, #0
	
	mov state, #0
	mov LEDG, state
	mov menustate, #0
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	mov a, #0FH
	lcall LCD_command
	mov LEDRB, #0
	mov a, #80H
	push acc
	ljmp foreverer
state5_done:
	ljmp forever
	
END
