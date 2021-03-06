$NOLIST

CSEG

;-----------------------------------------------------------------------
;Clears the Hex Display
;-----------------------------------------------------------------------
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
	;lcall ClearLCD
	jb secondsflag, DisplayLCD_time
	mov a, #80H
	lcall LCD_command
	ljmp DisplayLCD_temperature
DisplayLCD_time:
	mov a, #8BH
	lcall LCD_command
DisplayLCD_temperature:
	mov a, bcd+1
	push acc
	swap a
	anl a, #0FH
	jz Zero0
	setb noleadingzeroflag
	orl a, #30H
	lcall LCD_put
Zero0:
	pop acc
	anl a, #0FH
	jb noleadingzeroflag, NoLeadingZero
	jz Zero1
NoLeadingZero:
	orl a, #30H
	lcall LCD_put
Zero1:
	mov a, bcd+0
	push acc
	swap a
	anl a, #0FH
	jnb secondsflag, Zero1_L0
	jz Zero1_L1
Zero1_L0:
	orl a, #30H
	lcall LCD_put
Zero1_L1:
	jb secondsflag, NoDecimal
	mov a, #2EH
	lcall LCD_put
NoDecimal:
	pop acc
	anl a, #0FH
	orl a, #30H
	lcall LCD_put
	jb secondsflag, Display_s
	mov a, #0DFH
	lcall LCD_put
	mov a, #43H
	lcall LCD_put
	ljmp Done
Display_s:
	mov a, #73H
	lcall LCD_put
	ljmp Done
Done:
	mov a, #20H
	lcall LCD_put
	mov a, #20H
	lcall LCD_put
	ret
    

;-----------------------------------------------------------------------
;Clears the LCD display.
;-----------------------------------------------------------------------
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

;-----------------------------------------------------------------------
;Acesses the instruction register of the LCD.
;-----------------------------------------------------------------------
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

;-----------------------------------------------------------------------
;Accesses the data register of the LCD and writes data.
;-----------------------------------------------------------------------
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
	
;-----------------------------------------------------------------------
;Acceses the data register of the LCD and reads data. Currently this does not actually read any relevant data and is simply
;used to increment the address counter and move the cursor to get around a glitch that causes the cursor to disappear when
;the cursor address is set to certain values.
;-----------------------------------------------------------------------
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
	
;-----------------------------------------------------------------------
;Sends a zero-terminated string to the LCD.
;-----------------------------------------------------------------------
LCD_string:
    clr a
    movc a, @a+dptr
    jz LCD_Done
    lcall LCD_put
    inc dptr
    sjmp LCD_string
LCD_Done:
    ret

;-----------------------------------------------------------------------
;Delay for the LCD.
;-----------------------------------------------------------------------
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
;-----------------------------------------------------------------------
;Writes spaces.
;-----------------------------------------------------------------------
Write_space:
	mov a, #20H
	lcall LCD_put
	djnz r0, Write_space
	ret
;-----------------------------------------------------------------------
;Waits one second.
;-----------------------------------------------------------------------
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

;-----------------------------------------------------------------------
;Unused shit.
;-----------------------------------------------------------------------
	
; Send a constant-zero-terminated string through the serial port

Delay:
	push AR5
	mov R5, #20
Delay_loop:
	djnz R5, Delay_loop
	pop AR5
	ret


;-----------------------------------------------------------------------
;Allows user to save values for a selected parameter. SW0-9 enters corresponding numbers to the LCD. KEY3 saves the entered
;value to the variable for the selected parameter and returns to the previous menu. KEY2 returns to the previous menu
;saving. KEY1 is backspace. A maximum of 3 digits can be entered. If a value larger than 8 bits is entered, an error message 
;is displayed and the user's entered value is cleared from the LCD. Time values are entered in seconds and temperature
;values are entered in degrees Celcius.
;-----------------------------------------------------------------------
SetTime:
	load_x(0)
	load_y(0)
	mov DigitCount, #0
	mov r2, #0
	mov AddressCounter, #0A8H
	mov b, #0
	mov a, AddressCounter
	lcall LCD_command
	mov a, #0FH
	lcall LCD_command
	clr c
CheckA:
	clr mf
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
	clr mf
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
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
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
	mov y+0, #10
	lcall div32
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

;-----------------------------------------------------------------------
;Scrolls through LCD Menu options when KEY1 is pressed.
;-----------------------------------------------------------------------
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

;-----------------------------------------------------------------------
;Checks the menu state and displays appropriate characters on the LCD.
;-----------------------------------------------------------------------
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
	mov a, #0A8H
	lcall LCD_command
	mov dptr, #back
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

;-----------------------------------------------------------------------
;Updates the menu state when menu options are selected.
;-----------------------------------------------------------------------
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
	mov State, #1
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	mov a, #0CH
	lcall LCD_command
	ret
UpdateMenu_State0_L0:
	mov MenuState, #2					;Move to Settings menu
	;setb leftmenu
	;clr rightmenu
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
	mov MenuState, #0
	setb leftmenu
	setb rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
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
	
	
;-----------------------------------------------------------------------
;Turns on and configures the LCD
;-----------------------------------------------------------------------
InitializeLCD:
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
	ret

;-----------------------------------------------------------------------
;Displays the start menu
;-----------------------------------------------------------------------
InitializeMenu:
	mov a, #0FH
	lcall LCD_command
	setb leftmenu
	setb rightmenu
	lcall DisplayOptions
	mov a, #80H
	lcall LCD_command
	ret

LCDSetup:
	mov R4, #0
	mov R5, #0
	mov R0, #8AH
	mov b, #80H
	mov SoakTemp, #0
	mov SoakTime, #0
	mov ReflowTemp, #0
	mov ReflowTime, #0
	mov RampTime, #0
	mov MenuState, #0
	ret
$LIST