PRG_START   EQU $0000   ; Internal ROM start

PORTA	    EQU $1000   ; PORTA controls OE'
PORTB       EQU $1004   ; PORTB controls 2764 address lines
PORTC       EQU $1003   ; PORTC receives/sends data from/to 2764
DDRC        EQU $1007   ; PORTC direction pins

DATA        EQU $B001   ; Location to store 25 bytes in on-chip memory
N           EQU $B000   ; Should contain the current value of n

    ORG DATA
            ; 25-element array for the data
ARRAY       DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE

    ORG PRG_START
            ; Set PORTA. PROG_EN' and CE' are activated at program start.
            ; Bit 6: PROG_EN = 1
            ; Bit 5: CE' = 0
            ; Bit 4: OE' = 1
            LDAA #%01010000
            STAA PORTA

            LDX #0
NEXT_DATA   LDAB DATA,X ; Get first byte to store...
            STAB PORTC  ; ...and place on PORTC

            STX PORTB   ; Index X is also the target address on the 2764

            LDAA #$FF
            STAA DDRC   ; Set all PORTC pins to output

            ; By this point, HC11 is outputting data and adddress to the 2764

            LDAA #1     ; Start at n = 1
RETRY       PSHA        ; Push current n to stack

            LDAA #1     ; ] 1 ms
            BSR PULSE   ; ] pulse

            LDAA #$00
            STAA DDRC   ; Set all PORTC pins to input

            PULA        ; Retrieve current n from stack

            ; By this point, ACCB has the actual data bit for reference
            ; Compare against PORTC to verify

            CMPB PORTC
            BEQ NEXT

            INCA        ; n++
            CMPA #26    ; n > 25
            BEQ FAIL

            BRA RETRY

NEXT        LDAB #3     ; ACCB = 3, ACCA = n
            MUL         ; D = 3*n
            TAB         ; ACCA = 3*n
            BSR PULSE   ; 3*n ms pulse
            INX
            CPX #25     ; Address > $18
            BNE NEXT_DATA

SUCCESS     NOP

FAIL        NOP

            STOP

; ------------------------------------------------------------------------------
; Subroutine PULSE
; Sends an approx. n-ms pulse at bit 7 of PORTB
; ((6 + (3 + (3 + 3) * 332 + 2 + 3) * 1) + 5 + 2 + 4) / 2 MHz ~= n ms
;
; Parameters:
;   ACCA: Duration of pulse in ms
; ------------------------------------------------------------------------------

PULSE       PSHA            ; Save accumulators
            PSHB
            PSHX
            LDAB PORTB      ; Save address lines
            ORAB #$80       ; Set bit 7 to 1
            STAB PORTB
            BSR DELAY_1MS   ; 6 cycles
            ANDB #$7F       ; 2 cycles --- reset bit 7
            STAB PORTB      ; 4 cycles
            PULX
            PULB
            PULA
            RTS

DELAY_1MS   LDX #332        ; 3 cycles
DELAY_LOOP  DEX             ; 3 cycles
            BNE DELAY_LOOP  ; 3 cycles
            DECA            ; 2 cycles
            BNE DELAY_1MS   ; 3 cycles
            RTS             ; 5 cycles

