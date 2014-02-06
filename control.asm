; CONTROL.ASM
;
; This file takes a Look-up table, provided in the file defined at the top of this piece of code,
; as well as a temperature read and placed in R7, and sets or clears a bit in heat_oven to turn on or 
; off the heater as desired.
;
$MODDE2

; set to name of asm file containing the look-up table for the temperature curve
LOOKUPFILE EQU lookup.asm
;set to name of the lookuptable for temperature found in the file you set just above
LUT EQU templookuptable

org 0000H
	ljmp control_main

;not sure if this variable will be defined here or in the main file: uncomment later if necessary	
;BSEG at 20H
;heat_oven: dbit 1

DSEG at 30H
seconds_elapsed: ds 1	

CSEG

$include lookupfile

control_main:

;don't want to keep reseting shit
cjne isOn, 1, control_loop

control_setup:
	mov SP, #7FH ; Set the stack pointer
	mov dptr, #LUT
	mov seconds_elapsed, #0
	
control_loop:
	
	; increment to grab the next item in our lookuptable, place in R0
	inc seconds_elapsed
	mov R0, @dptr+seconds_elapsed
	
	;First check if we are already at our desired temp, and if so do nothing until next check
	cjne R0, R7, do_something
	ljmp do_nothing
	
do_something:
	
	mov x, R0
	mov y, R7
	
	lcall x_lessthan_y ; or whatever the function is in the math.asm file we have
	
	;mf flag is set? if R0 [desired temp] is less than R7 [read temp]
	; so if mf flag set, want to turn oven off
	; if not set, turn oven on
	cjne mf, 0, next
	setb heat_oven
	
next:
	clr heat_oven
		
do_nothing:
	ret
END