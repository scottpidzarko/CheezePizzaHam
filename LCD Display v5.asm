$MODDE2

FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))
FREQ0         EQU 100
TIMER0_RELOAD EQU 65538-(FREQ/(12*FREQ0))
SCLK EQU P0.2
MOSI EQU P0.1
MISO EQU P0.0
CE_ADC EQU P0.3
CE_EE EQu P0.4
CE_RTC EQU P0.5

org 0000H
	ljmp myprogram

org 000BH
	ljmp ISR_timer0

DSEG at 30H
x:    ds 4
y:    ds 4
z:    ds 4
count10ms: ds 1
Shiftcount: ds 1
AddressCounter: ds 1
SoakTemp: ds 1
SoakTime: ds 1
ReflowTemp: ds 1
ReflowTime: ds 1
RampTime: ds 1
DigitCount: ds 1
MenuState: ds 1			;0 = Start menu, 1 = Reflow process, 2 = Settings menu, 3 = Set Parameters menu,
						;4 = Set Parameters menu2, 5 = Set Parameters menu3, 6 = Setting Soak temp,
						;7 = Setting Soak time, 8 = Setting Reflow temp, 9 = Setting Reflow time, 10 = Setting Ramp time,

bcd:  ds 5

BSEG
mf:   dbit 1
timerflag: dbit 1
LCDflag: dbit 1
toggleflag: dbit 1
leftmenu: dbit 1
rightmenu: dbit 1
$include(math32.asm)

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
	
Back:
	DB 0A5H, 'Back', 0

Error_Too_large0:
	DB 'Error: Value', 0
Error_Too_large1:
	DB 'greater than 255', 0
	
ClearHex:
	mov HEX0, #7FH
	mov HEX1, #7FH
	mov HEX2, #7FH
	mov HEX3, #7FH
	mov HEX4, #7FH
	mov HEX5, #7FH
	mov HEX6, #7FH
	mov HEX7, #7FH
	ret
	
DisplayHex:
	mov dptr, #myLUT
	; Display Digit 0
    mov A, bcd+0
    anl a, #0fh
    movc A, @A+dptr
    mov HEX0, A
	; Display Digit 1
    mov A, bcd+0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    mov HEX1, A
	; Display Digit 2
    mov A, bcd+1
    anl a, #0fh
    movc A, @A+dptr
    mov HEX2, A
    ret

DisplayLCD:
	mov a, r7
	anl a, #0FH
	cjne a, #0, DisplayLCD_L0
	ljmp DisplayLCD_L1
DisplayLCD_L0:
	orl a, #30H
	lcall LCD_put
DisplayLCD_L1:
	mov a, r6
	push acc
	swap a
	anl a, #0FH
	cjne a, #0, DisplayLCD_L2
	ljmp DisplayLCD_L3
DisplayLCD_L2:
	orl a, #30H
	lcall LCD_put
DisplayLCD_L3:
	pop acc
	anl a, #0FH
	cjne a, #0, Return0
	orl a, #30H
	lcall LCD_put
Return0:
	ret
    


ClearLCD:
	push AR1
	mov a, #01H ; Clear screen (Warning, very slow command!)
	lcall LCD_command
    
    ; Delay loop needed for 'clear screen' command above (1.6ms at least!)
    mov R1, #40
Clr_loop:
	lcall Wait40us
	djnz R1, Clr_loop
	pop AR1
	ret
	
Wait40us:
	push AR0
	mov R0, #149
X1: 
	nop
	nop
	nop
	nop
	nop
	nop
	djnz R0, X1 ; 9 machine cycles-> 9*30ns*149=40us
	pop AR0
    ret
    
LCD_command:
	mov	LCD_DATA, A
	clr	LCD_RS
	nop
	nop
	setb LCD_EN ; Enable pulse should be at least 230 ns
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	clr	LCD_EN
	ljmp Wait40us

LCD_put:
	mov	LCD_DATA, A
	setb LCD_RS
	nop
	nop
	setb LCD_EN ; Enable pulse should be at least 230 ns
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	clr	LCD_EN
	ljmp Wait40us
	
LCD_string:
    clr a
    movc a, @a+dptr
    jz LCD_Done
    lcall LCD_put
    inc dptr
    sjmp LCD_string
LCD_Done:
    ret
	
LCD_read:
	setb LCD_RW
	setb LCD_RS
	mov LCD_DATA, #0
	nop
	nop
	setb LCD_EN ; Enable pulse should be at least 230 ns
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	clr	LCD_EN
	clr LCD_RW
	ljmp Wait40us
	
ISR_Timer0:
	push acc
	
	; Reload the timer
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    
    inc count10ms
    mov a, count10ms
    cjne A, #10, ISR_Timer0_L0
    mov count10ms, #0
    mov a, #18H
	lcall LCD_command
	inc Shiftcount
	;mov a, #0A8H
	;lcall LCD_command
	;mov a, #6
	;lcall LCD_command
	;mov a, #' '
	;lcall LCD_put
	;mov a, #4
	;lcall LCD_command
	mov a, #0A8H
	add a, Shiftcount
	lcall LCD_command
    
ISR_Timer0_L0:
	pop acc
    reti
    
WaitHalfSec:
	mov R2, #18
L3: mov R1, #250
L2: mov R0, #250
L1: djnz R0, L1
	djnz R1, L2
	djnz R2, L3
	ret
	
WaitOneSec:
	push AR0
	push AR1
	push AR2
	mov R2, #180
L3A: mov R1, #250
L2A: mov R0, #150
L1A: djnz R0, L1A
	djnz R1, L2A
	djnz R2, L3A
	pop AR2
	pop AR1
	pop AR0
	ret
	
; Send a constant-zero-terminated string through the serial port

Delay:
	push AR5
	mov R5, #20
Delay_loop:
	djnz R5, Delay_loop
	pop AR5
	ret

Init_Timer0:	
	mov TMOD,  #00000001B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
	clr TR0 ; Disable timer 0
	clr TF0
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    setb TR0 ; Enable timer 0
    setb ET0 ; Enable timer 0 interrupt
    ret
    
SetTime:
	mov x+0, #0
	mov x+1, #0
	mov DigitCount, #0
	mov r2, #0
	clr mf
	mov AddressCounter, #0A8H
	mov b, #0
	mov a, AddressCounter
	lcall LCD_command
	mov a, #0FH
	lcall LCD_command
	clr c
CheckA:
	cjne r2, #3, CheckA_L0
	ljmp Backspace
CheckA_L0:
	mov r1, #0
	mov b, #0
	mov a, SWA
	jz CheckB
	mov r0, a
	ljmp WaitA
CheckB:
	mov a, SWB
	anl a, #11B
	jz Backspace
	mov r0, a
	ljmp WaitB
WaitA:
	mov a, SWA
	jnz WaitA
	mov a, r0
	ljmp Rotate
WaitB:
	mov a, SWB
	jnz WaitB
	mov a, r0
	mov r1, #1
Rotate:
	rrc a
	inc b
	jnc Rotate
	dec b
	mov a, b
	cjne r1, #1, SkipB
	add a, #8
SkipB:
	mov r7, a
	push acc
	lcall SaveValue
	pop acc
	add a, #30H
	lcall LCD_put
	inc r2
	inc AddressCounter
Backspace:
	lcall CheckBackspace
CheckDone:
	jb KEY.2, CheckEnter
	jnb KEY.2, $
	ljmp SetTime_Return
CheckEnter:
	jb KEY.3, CheckA
	jnb KEY.3, $
	mov y+3, #0
	mov y+2, #0
	mov y+1, #0
	mov y+0, #255
	lcall x_gt_y
	jnb mf, ValidValue
	mov a, #0CH
	lcall LCD_command
	lcall ClearLCD
	mov a, #80H
	lcall LCD_command
	mov dptr, #Error_Too_large0
	lcall LCD_string
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #Error_Too_large1
	lcall LCD_string
	lcall WaitOneSec
	lcall WaitOneSec
	lcall WaitOneSec
	lcall DisplayOptions
	ljmp SetTime
ValidValue:
	mov a, MenuState
	cjne a, #6, ValidValue_L0
	mov SoakTemp, x+0
	ljmp SetTime_Return
ValidValue_L0:
	cjne a, #7, ValidValue_L1
	mov SoakTime, x+0
	ljmp SetTime_Return
ValidValue_L1:
	cjne a, #8, ValidValue_L2
	mov ReflowTemp, x+0
	ljmp SetTime_Return
ValidValue_L2:
	cjne a, #9, ValidValue_L3
	mov ReflowTime, x+0
	ljmp SetTime_Return
ValidValue_L3:
	mov RampTime, x+0
SetTime_Return:
	ret
	
	
CheckBackspace:
	jb KEY.1, CheckBackspace_Return
	mov a, AddressCounter
	subb a, #0A7H
	jz CheckBackspace_Return
	jnb KEY.1, $
	dec AddressCounter
	mov a, AddressCounter
	lcall LCD_command
	mov a, #' '
	lcall LCD_put
	mov a, #0A8H
	lcall LCD_command
CheckBackspace_L0:
	cjne a, AddressCounter, CheckBackspace_L1
	ljmp CheckBackspace_L2
CheckBackspace_L1:
	lcall LCD_read
	inc a
	ljmp CheckBackspace_L0
CheckBackspace_L2:
	mov a, r6
	mov b, #10
	div ab
	mov ReflowTime, a
	dec r2
CheckBackspace_Return:
	ret

SaveValue:
	mov y+0, #10
	lcall mul32
	mov y+0, x+0
	mov x+0, r7
	lcall add32
	;lcall hex2bcd
	;lcall DisplayHex
	ret

Scroll:
	jb KEY.1, Scroll_Return
	jnb KEY.1, $
Scroll_L0:
	cjne a, #80H, Scroll_L1
	mov a, #8FH
	lcall LCD_command
	jb rightmenu, Scroll_L1
	ret
Scroll_L1:
	
	cjne a, #8FH, Scroll_L2
	mov a, #0A8H
	lcall LCD_command
	ret
Scroll_L2:
	cjne a, #0A8H, Scroll_L3
	mov r0, #15
Scroll_L2_L0:
	lcall LCD_read
	djnz r0, Scroll_L2_L0
	mov a, #0B7H
	jb leftmenu, Scroll_L3
	ret
Scroll_L3:
	mov a, #80H
	lcall LCD_command
	ret
Scroll_Return:
	ret

Scroll0:
	dec AddressCounter
	mov a, AddressCounter
	subb a, #80H
	mov r0, a
Scroll0_L0:
	lcall LCD_read
	djnz r0, Scroll0_L0
	ret
	
DisplayOptions:
	lcall ClearLCD
	mov r0, MenuState
	cjne r0, #0, DisplayOptions_State1
	mov a, #80H
	lcall LCD_command
	mov dptr, #Begin
	lcall LCD_string
	mov a, #0A8H
	lcall LCD_Command
	mov dptr, #Settings
	lcall LCD_string
	lcall ClearHex
	ret
DisplayOptions_State1:
	cjne r0, #1, DisplayOptions_State2
	lcall ClearHex
	ret
DisplayOptions_State2:
	cjne r0, #2, DisplayOptions_State3
	mov a, #80H
	lcall LCD_command
	mov dptr, #Set_parameters
	lcall LCD_string
	lcall ClearHex
	ret
DisplayOptions_State3:
	cjne r0, #3, DisplayOptions_State4
	mov a, #80H
	lcall LCD_command
	mov dptr, #Soak_temp
	lcall LCD_string
	mov a, #0A8H
	lcall LCD_Command
	mov dptr, #Soak_time
	lcall LCD_string
	mov a, #8FH
	lcall LCD_command
	mov a, #7EH
	lcall LCD_put
	lcall ClearHex
	ret
DisplayOptions_State4:
	cjne r0, #4, DisplayOptions_State5
	mov a, #80H
	lcall LCD_command
	mov dptr, #Reflow_temp
	lcall LCD_string
	mov a, #0A8H
	lcall LCD_Command
	mov dptr, #Reflow_time
	lcall LCD_string
	mov a, #8FH
	lcall LCD_command
	mov a, #7EH
	lcall LCD_put
	mov a, #0B7H
	lcall LCD_command
	mov a, #7FH
	lcall LCD_put
	lcall ClearHex
	ret
DisplayOptions_State5:
	cjne r0, #5, DisplayOptions_State6
	mov a, #80H
	lcall LCD_command
	mov dptr, #Ramp_time
	lcall LCD_string
	mov a, #0A8H
	lcall LCD_Command
	mov dptr, #Back
	lcall LCD_string
	mov a, #0B7H
	lcall LCD_command
	mov a, #7FH
	lcall LCD_put
	lcall ClearHex
	ret
DisplayOptions_State6:
	cjne r0, #6, DisplayOptions_State7
	mov a, #80H
	lcall LCD_command
	mov dptr, #Setting_Soak_Temp
	lcall LCD_string
	mov x+0, SoakTemp
	lcall hex2bcd
	lcall DisplayHex
	ret
DisplayOptions_State7:
	cjne r0, #7, DisplayOptions_State8
	mov a, #80H
	lcall LCD_command
	mov dptr, #Setting_Soak_Time
	lcall LCD_string
	mov x+0, SoakTime
	lcall hex2bcd
	lcall DisplayHex
	ret
DisplayOptions_State8:
	cjne r0, #8, DisplayOptions_State9
	mov a, #80H
	lcall LCD_command
	mov dptr, #Setting_Reflow_Temp
	lcall LCD_string
	mov x+0, ReflowTemp
	lcall hex2bcd
	lcall DisplayHex
	ret
DisplayOptions_State9:
	cjne r0, #9, DisplayOptions_State10
	mov a, #80H
	lcall LCD_command
	mov dptr, #Setting_Reflow_Time
	lcall LCD_string
	mov x+0, ReflowTime
	lcall hex2bcd
	lcall DisplayHex
	ret
DisplayOptions_State10:
	mov a, #80H
	lcall LCD_command
	mov dptr, #Setting_Ramp_Time
	lcall LCD_string
	mov x+0, RampTime
	lcall hex2bcd
	lcall DisplayHex
	ret

UpdateMenu:
	jb KEY.3, UpdateMenu_L0
	jnb KEY.3, $
	ljmp UpdateMenu_State0
UpdateMenu_L0:
	ljmp UpdateMenu_Return
	
UpdateMenu_State0:
	mov r0, MenuState
	cjne r0, #0, UpdateMenu_State1
	cjne a, #80H, UpdateMenu_State0_L0
	mov MenuState, #1
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State0_L0:
	mov MenuState, #2					;Move to Settings menu
	setb leftmenu
	clr rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
	
UpdateMenu_State1:
	cjne r0, #1, UpdateMenu_State2
	ret
	
UpdateMenu_State2:
	cjne r0, #2, UpdateMenu_State3
	cjne a, #80H, UpdateMenu_State2_L0
	mov MenuState, #3
	setb leftmenu
	clr rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State2_L0:
	ret
	
UpdateMenu_State3:
	cjne r0, #3, UpdateMenu_State4
	cjne a, #80H, UpdateMenu_State3_L0
	mov MenuState, #6
	lcall DisplayOptions
	lcall SetTime
	mov MenuState, #3
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State3_L0:
	cjne a, #8FH, UpdateMenu_State3_L1
	mov MenuState, #4
	clr leftmenu
	clr rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State3_L1:
	mov MenuState, #7
	lcall DisplayOptions
	lcall SetTime
	mov MenuState, #3
	lcall DisplayOptions
	mov a, #0A8H
	lcall LCD_command
	ret

UpdateMenu_State4:
	cjne r0, #4, UpdateMenu_State5
	cjne a, #80H, UpdateMenu_State4_L0
	mov MenuState, #8
	lcall DisplayOptions
	lcall SetTime
	mov MenuState, #4
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State4_L0:
	cjne a, #8FH, UpdateMenu_State4_L1
	mov MenuState, #5
	clr leftmenu
	setb rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State4_L1:
	cjne a, #0A8H, UpdateMenu_State4_L2
	mov MenuState, #9
	lcall DisplayOptions
	lcall SetTime
	mov MenuState, #4
	lcall DisplayOptions
	mov a, #0A8H
	lcall LCD_command
	ret
UpdateMenu_State4_L2:
	mov MenuState, #3
	clr rightmenu
	setb leftmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
	
UpdateMenu_State5:
	cjne r0, #5, UpdateMenu_State6
	cjne a, #80H, UpdateMenu_State5_L0
	mov MenuState, #10
	lcall DisplayOptions
	lcall SetTime
	mov MenuState, #5
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State5_L0:
	cjne a, #0A8H, UpdateMenu_State5_L1
	mov MenuState, #2
	clr rightmenu
	setb leftmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
UpdateMenu_State5_L1:
	mov MenuState, #4
	clr rightmenu
	clr leftmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret
	
UpdateMenu_State6:
UpdateMenu_Return:
	ret
	
	
	
	

myprogram:
	mov SP, #7FH ; Set the stack pointer
	mov LEDRA, #0 ; Turn off all LEDs
	mov LEDRB, #0
	mov LEDRC, #0
	mov LEDG, #0
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
	
	;lcall Init_Timer0
	;setb EA
	

	lcall ClearLCD
	mov a, #0FH
	lcall LCD_command
	setb leftmenu
	setb rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	mov SoakTemp, #0
	mov SoakTime, #0
	mov ReflowTemp, #0
	mov ReflowTime, #0
	mov RampTime, #0
Forever:
	lcall UpdateMenu
	lcall Scroll
	ljmp Forever
	mov dptr, #Reflow_Time
	lcall LCD_string
	;lcall Init_Timer0
	;setb EA
ShiftLCD:
	mov a, SWC
	jnb acc.1, Skip0
Skip0:
	ljmp ShiftLCD
	
	
END