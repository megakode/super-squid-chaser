
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

; =================================================
; Decay value towards zero
; =================================================
;
; Input: 
;   A = value to decay
;   B = decay amount (positive)
;
; Output: 
;   A = decayed value
;
; =================================================

export DecayTowardsZero
DecayTowardsZero:

	or  a           ; sets Z if A == 0
    jr  z, .done

    bit 7, a        ; check sign bit
    jr  nz, .negative

.positive:
    ;dec a
    sub a, b ; carry set if a < b
    jr nc, .done 
    ; if underflow, set to zero
    ld a, 0
    jr .done

.negative:
    add a, b
    bit 7, a        ; check sign bit
    jr  nz, .done
    ; if overflow, set to zero
    ld a, 0

.done:
    ret