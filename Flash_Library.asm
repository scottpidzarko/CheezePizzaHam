$MODDE2

; This file contains code that saves the five variables into flash memory,
; and also recalls them from flash memory. There is a dummy program at the 
; bottom that demonstrates their use.

;FLASHSECTOR: Refers to the Flash sector we are using.
; Generally in our program we won't use multiple sectors.
;
;Flash sector SA1-SA7 are 8KB. Sectors SA8 - SA70 are 64KB
; ** SA8 is reverved for DEw-8052 soft processor progam storage
; 
; We select sector SA8 with FLASHSECTOR = 1, SA9 with FLASHSECTOR=2,
; and so on.

org 0000H
	ljmp myprogram

DSEG at 30H

SoakTemp: ds 1
SoakTime: ds 1
ReflowTemp: ds 1
ReflowTime: ds 1
RampTime: ds 1

CSEG

FLASHSECTOR:
	db 1

; To read a byte from flash memory, put the address in dptr.
; The result returns in acc.
Read_Flash:
	mov FLASH_MOD, #0x00 ; Set data port for input
	mov FLASH_ADD0, dpl
	mov FLASH_ADD1, dph
	mov FLASH_ADD2, #FLASHSECTOR
	mov FLASH_CMD, #0111B ; FL_CE_N=0, FL_OE_N=1
	mov FLASH_CMD, #0011B ; FL_CE_N=0, FL_OE_N=0
	nop
	mov a, FLASH_DATA
	nop
	mov FLASH_CMD, #0111B ; FL_CE_N=0, FL_OE_N=1
	mov FLASH_CMD, #1111B ; FL_CE_N=1, FL_OE_N=1
	ret
	
; To write a byte to flash memory, put the address in dptr
; and the byte to write in acc.
Write_Flash:
	mov FLASH_MOD, #0ffh ; Set data port for output
	mov FLASH_ADD0, dpl
	mov FLASH_ADD1, dph
	mov FLASH_ADD2, #FLASHSECTOR
	mov FLASH_DATA, a
	mov FLASH_CMD, #0111B ; FL_CE_N=0, FL_WE_N=1
	mov FLASH_CMD, #0101B ; FL_CE_N=0, FL_WE_N=0
	mov FLASH_CMD, #0111B ; FL_CE_N=0, FL_WE_N=1
	mov FLASH_CMD, #1111B ; FL_CE_N=1, FL_WE_N=1
	ret

; Zeros out the sector of flashmemory defined by FLASHSECTOR
;----------------------------------------------------------------
Write_Constant_Flash mac
	mov dptr, #%0
	mov a, #%1
	lcall Write_Flash
Endmac

EraseSector:
	Write_Constant_Flash( 0x0AAA, 0xAA )
	Write_Constant_Flash( 0x0555, 0x55 )
	Write_Constant_Flash( 0x0AAA, 0x80 )
	Write_Constant_Flash( 0x0AAA, 0xAA )
	Write_Constant_Flash( 0x0555, 0x55 )
	Write_Constant_Flash( 0x0000, 0x30 )
	; Check using DQ7 Data# polling when the erasing is done
EraseSector_L0:
	mov dptr, #0
	lcall Read_Flash
	cpl a
	jnz EraseSector_L0
	ret
;-------------------------------------------------------------------	

; Flashes a byte in a to the location in flash indicated by dptr,
; also verifies if write worked correctly
Flash_Byte:
	push dph
	push dpl
	push acc
	Write_Constant_Flash( 0x0AAA, 0xAA )
	Write_Constant_Flash( 0x0555, 0x55 )
	Write_Constant_Flash( 0x0AAA, 0xA0 )
	pop acc
	pop dpl
	pop dph
	mov r0, a ; Used later when checking...
	lcall Write_Flash
	;Check using DQ7 Data# polling when operation is done
Flash_Byte_L0:
	lcall Read_Flash
	clr c
	subb a, r0
	jnz Flash_Byte_L0
	ret

; Save SoakTemp, SoakTime, ReflowTemp, ReflowTime, RampTime in flash memory
SaveConfig:
	lcall EraseSector ; We need to erase whole sector :(
	mov dptr, #0
	mov a, SoakTemp
	lcall Flash_Byte
	inc dptr
	mov a, SoakTime
	lcall Flash_Byte
	inc dptr
	mov a, ReflowTemp
	lcall Flash_Byte
	inc dptr
	mov a, ReflowTime
	lcall Flash_Byte
	inc dptr
	mov a, RampTime
	lcall Flash_Byte
	inc dptr			;Key is 0x55, 0xAA
	mov a, #055H		;If key is not set, the
	lcall Flash_Byte	;Information stored 
	inc dptr			;in flash is not valid!
	mov a, #0aaH
	lcall Flash_Byte
	ret

; Recall SoakTemp, SoakTime, ReflowTemp, ReflowTime, RampTime back into variables from flash memory
; (WILL WIPE WHAT WAS IN SOAKTEMP, SOAKTIME, ETC) 
ReadConfig:
	mov SoakTemp, #120    ;'\ 
	mov SoakTime, #60     ; |
	mov ReflowTemp, #220  ; |= DEFAULTS!
	mov ReflowTime, #45	  ; |
	mov RampTime, #60	  ;/
	mov dptr, #6	; Reading flash backwareds 6 = number of variables needed + 1 
	lcall Read_Flash
	cjne a, #0aah, done_ReadConfig	; \	 If key is valid,
	dec dpl							; |_ initialize variables
	lcall Read_Flash				; |  with stored values
	cjne a, #055h, done_ReadConfig	; /
	dec dpl
	lcall Read_Flash
	mov Ramptime, a
	dec dpl
	lcall Read_Flash 
	mov ReflowTime, a
	dec dpl
	lcall Read_Flash
	mov ReflowTemp, a
	dec dpl
	lcall Read_Flash
	mov SoakTime, a
	dec dpl
	lcall Read_Flash
	mov SoakTemp, a
done_ReadConfig:
	ret
	
; Simple dummy program to test things.
myprogram:
		mov SP, #7FH
		mov LEDRA, #0
		mov LEDRB, #0
		mov LEDRC, #0
		mov LEDG, #0
		mov FLASHSECTOR, #2
Forever:
		mov SoakTemp, #111B
		mov SoakTime, #111011B
		mov ReflowTemp, #1011B
		mov ReflowTIme, #10B
		
		lcall SaveConfig
		
		mov SoakTemp, #0
		mov SoakTime, #0
		mov ReflowTemp, #0
		mov ReflowTIme, #0
		
		lcall ReadConfig
		
		mov LEDRA, SoakTime
		mov LEDRB, SoakTemp
		mov LEDRC, ReflowTime
		mov LEDG, ReflowTemp
		
	ljmp Forever
		
END