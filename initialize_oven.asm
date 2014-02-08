; initialize_oven.asm: functions to call all the initialization subruitines from each of the files.
$NOLIST

CSEG

initialize_oven:
	
	;for setting up the lcd. must call in this order

	lcall LCDSetup
	lcall initializelcd
	lcall initializemenu
	
	
	lcall intiailize_temp_control
	lcall initialize_temp_display
	lcall initialize_temp_read
	
	ret
	
$LIST