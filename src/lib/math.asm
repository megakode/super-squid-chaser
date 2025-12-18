
SECTION "Math routines", ROM0
; =================================================
; CalculateTensAndOnes
; =================================================
; 
; Input: A = number (0-99)
; Output: B = tens digit, C = ones digit
;
; =================================================

export CalculateTensAndOnes
CalculateTensAndOnes:

    ld  b, 0          ; tens = 0

.loop:
    cp  10            ; A >= 10?
    jr  c, .done
    sub 10            ; A -= 10
    inc b             ; tens++
    jr  .loop

.done:
    ld  c, a          ; ones = A
    
    ret