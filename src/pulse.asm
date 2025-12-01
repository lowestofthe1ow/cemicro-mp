PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

PULSE_WIDTH EQU $19

ADDR        EQU $00  ; Corresponding addresses
NUM_BYTES   EQU 25   ; 0x000 to 0x018

COUNT       RMB 1    ; Loop counter for bytes

    ORG PRG_START
            LDAA #5

; ------------------------------------------------------------------------------
; Subroutine PULSE
; Sends a 1ms pulse at bit 7 of PORTB
; Pulse time: (2+4+6+5+(3+3)*PULSE_WIDTH+5)s / 2MHz
;
; Parameters:
;   ACCA: Duration of pulse in ms
; Modifies: ACCA, ACCB, X
; ------------------------------------------------------------------------------

; Calculate value of PULSE_WIDTH.
; Will be 330+333*(n-1) for an n-ms pulse. Follows from equation above.
PULSE       DECA
            LDAB #333
            MUL
            ADDD #330

            LDAA #$80
PULSE_LOOP  EORA #$80       ; 2 cycles
            STAA PORTB      ; 4 cycles
            BSR DELAY_1MS   ; 6 cycles
            BRA PULSE_LOOP  ; 3 cycles

DELAY_1MS   LDX PULSE_WIDTH ; 5 cycles
DELAY_LOOP  DEX             ; 3 cycles
            BNE DELAY_LOOP  ; 3 cycles
            RTS             ; 5 cycles

