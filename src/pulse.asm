PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

PULSE_WIDTH EQU $19

ADDR        EQU $00  ; Corresponding addresses
NUM_BYTES   EQU 25   ; 0x000 to 0x018

COUNT       RMB 1    ; Loop counter for bytes

    ORG PRG_START
            LDAB #5

; ------------------------------------------------------------------------------
; Subroutine PULSE
; Sends an approx. n-ms pulse at bit 7 of PORTB
; (6 + (3 + (3 + 3)*332) * n) / 2MHz ~= n*0.9975ms
;
; Parameters:
;   ACCB: Duration of pulse in ms
; Modifies: ACCA, ACCB, X
; ------------------------------------------------------------------------------

            LDAA #$80
            STAA PORTB      ; 4 cycles
            BSR DELAY_1MS   ; 6 cycles
            CLRB
            RTS             ; 5 cycles

DELAY_1MS   LDX #332        ; 3 cycles
DELAY_LOOP  DEX             ; 3 cycles
            BNE DELAY_LOOP  ; 3 cycles
            DECB            ; 2 cycles
            BNE DELAY_1MS   ; 3 cycles
            RTS             ; 5 cycles

