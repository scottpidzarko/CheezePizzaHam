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

$include(math32.asm)
$include(control.asm)
$include(temp_measurement.asm)
$include(ADC_reader.asm)


CSEG

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

	lcall initialize_oven

Forever:

	lcall solder_reflow_oven
	sjmp Forever	

END