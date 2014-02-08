;solder_reflow_oven.asm: main functionality for reflow oven done here
$NOLIST

CSEG

solder_reflow_oven:
	
	;for displaying shit on the LCD. Must call in this order
	lcall UpdateMenu
	lcall Scroll


$LIST