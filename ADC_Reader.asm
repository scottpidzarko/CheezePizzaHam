; Channel to read passed in register b
Read_ADC_Channel:
clr CE_ADC
mov R0, ?#?00000001B? ; Start bit:1
lcall DO_SPI_G

mov a, b
swap a
anl a, ?#?0F0H?
setb acc.7 ; Single mode (bit 7).

mov R0, a ; Select channel
lcall DO_SPI_G
mov a, R1 ; R1 contains bits 8 and 9
anl a, ?#?03H?
mov R7, a

mov R0, ?#?55H? ; It doesn't matter what we transmit...
lcall DO_SPI_G
mov a, R1 ; R1 contains bits 0 to 7
mov R6, a
setb CE_ADC
ret