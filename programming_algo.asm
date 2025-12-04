PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

DATA        EQU      ; Data bytes here
ADDR        EQU $00  ; Corresponding addresses
NUM_BYTES   EQU 25   ; 0x000 to 0x018

COUNT       RMB 1    ; Loop counter for bytes

    ORG PRG_START
START       CLRA
            ; 01001000
            BSET PORTA, #%01110000  ; Set PROG_EN (Conected to PA6) & OE to high for programming
            LDX #DATA ; X points to data table
            LDY #ADDR ; Y points to address table
            
            LDAA #NUM_BYTES
            STAA COUNT    

MAIN_LOOP   LDAA Y ; Load address for current byte
            STAA PORTB

            LDAA X ; Load data for current byte
            STAA PORTC
    
            ; Set control signals: CE=0 (PA5), OE=1 (PA4), P=1 (PA3)
            LDAA PORTA
            ANDA #$C7 ; Clear bits 3-5
            ORAA #$10 ; OE=1
            STAA PORTA
    
            ; Programming loop
            STAB #1 ; B is n

PULSE_LOOP  BCLR PORTA, $08 ; P=0 (start pulse)
            JSR DELAY_1MS
            BSET PORTA, $08 ; P=1 (end pulse)
            
    
            ; Verify: Set OE=0, read data, set OE=1
            BCLR PORTA, $10 ; OE=0
            LDAA PORTC ; read
            BSET PORTA, $10 ; OE=1
            
            CMPA X ; Compare to original data
            BEQ VERIFY_YES ; If match, go to next byte
            INCB  ; Else, n++
            CMPB #25 ; Check if n <= 25
            BLE PULSE_LOOP    ; If not, repeat pulse
            BRA FAIL
        
VERIFY_YES  JSR OVERPROGRAM
            BRA NEXT_BYTE  
            
NEXT_BYTE   INX ; Next data byte
            INY ; Next address (8-bit)
            DEC COUNT
            BNE MAIN_LOOP
    
            ;switch to 5V VCC/VPP for final verify
            BCLR PORTA, $40   ; PROG_EN Low for 5V voltages
    
            ; Final verification loop
            LDX #DATA ; Reset pointers
            LDY #ADDR
            LDAB #NUM_BYTES      
           
VERIFY_LOOP LDAA Y          ; Load address
            STAA PORTB
            BCLR PORTA, $10 ; OE=0
            LDAB PORTC  ; Read data
            BSET PORTA, $10 ; OE=1
            CMPB X          ; Compare
            BNE FAIL         ; If mismatch, fail/error
            INX     ;next data & address
            INY
            DECB
            BNE VERIFY_LOOP
    
            BRA END    
                                                          
FAIL        ;not sure what to do when it fails
            
;delay subroutine
DELAY_1MS   LDX #2000 ;2000 cycles as a 1ms delay
        
DELAY_LOOP  DEX
            BNE DELAY_LOOP
            RTS
         
;overprogram subroutine
OVERPROGRAM LDAA #3           ; A = 3    
            MUL               ; D = 3 * n
            TFR D, X          ; X = 3 * n (number of 1ms delays)
            BCLR PORTA, $08   ; P=0 (start overprogram pulse)
            
OVER_LOOP   JSR DELAY_1MS        
            DEX
            BNE OVER_LOOP     ; Repeat X times
            BSET PORTA, $08   ; P=1 (end overprogram pulse)
            RTS
            
END        
