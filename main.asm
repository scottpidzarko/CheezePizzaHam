; main.asm
; 
; Define variables in this file that are used in other programs so we don't have overlapping variable names, etc.
;
; Always try to compile from this file too, so we don't have conflicting/multiple labels of the same name.
;  
$MODDE2

;-------------------------------------------------------
;---------------- GLOBAL CONSTANTS HERE ----------------
;-------------------------------------------------------
;
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

;----------------------------------------------------------------
;---------------- ISRs and jump to main function ----------------
;----------------------------------------------------------------
;
org 0000H
	ljmp myprogram

org 000BH
	ljmp ISR_timer0

;-------------------------------------------------------------
;---------------- VARAIABLE DECLARATIONS HERE ----------------
;-------------------------------------------------------------
;
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

;------------------------------------------------
;---------------- $INCLUDES HERE ----------------
;------------------------------------------------

$include(solder_reflow_oven.asm)
$include(initialize_oven.asm)
$include(math32.asm)
$include(control.asm)
$include(temp_measurement.asm)
$include(ADC_reader.asm)

CSEG

;-------------------------------------------------
;---------------- STRINGS FOR LCD ----------------
;-------------------------------------------------
;

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
	
;-----------------------------------------------------------------------
;---------------- LOOK-UP-TABLES FOR 7SEG Displays, etc ----------------
;-----------------------------------------------------------------------
;
myLUT:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H        ; 0 TO 4
    DB 092H, 082H, 0F8H, 080H, 090H        ; 4 TO 9
    DB 088H, 083H, 0C6H, 0A1H, 086H, 08EH  ; A to F
    
;-------------------------------------------
;---------------- CODE HERE ----------------
;-------------------------------------------

; there shouldn't really be any code in this file, so we're just calling the function that does shit.

myprogram:
	mov SP, #7FH ; Set the stack pointer
	mov LEDRA, #0 ; Turn off all LEDs
	mov LEDRB, #0
	mov LEDRC, #0
	mov LEDG, #0
	lcall initialize_oven

Forever:

	lcall solder_reflow_oven
	sjmp Forever	

END