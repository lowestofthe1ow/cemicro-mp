PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

DATA        EQU      ; Data bytes here
ADDR        EQU $00  ; Corresponding addresses
NUM_BYTES   EQU 25   ; 0x000 to 0x018

COUNT       RMB 1    ; Loop counter for bytes

    ORG PRG_START
            LDAA #8000

PULSE_LOOP  EORA #8000
            STAA PORTB
            BSR DELAY_1MS
            BRA PULSE_LOOP

DELAY_1MS   LDX #2000 ;2000 cycles as a 1ms delay

DELAY_LOOP  DEX
            BNE DELAY_LOOP
            RTS
