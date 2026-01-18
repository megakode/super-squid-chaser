SECTION "Math variables", WRAM0

RandomSeed: db


SECTION "Math routines", ROM0

; ==================================================
; Init random seed
; ==================================================
export InitRandomSeed
InitRandomSeed:

    ld a,0xab; initial PRNG seed value
	ld [RandomSeed], a 

    ret

; ======================================================================
; Get Pseudo Random Byte
; ======================================================================
; Simple pseudo-random number generator
;
; Outputs:
;   - A = pseudo-random byte
; ======================================================================

export GetPseudoRandomByte
GetPseudoRandomByte:

	push bc
    ld  a,[RandomSeed]   ; A = seed
    ld   b,a         ; B = seed copy
    ldh  a,[$ff04]    ; A = DIV (changes constantly)
    xor  b           ; mix timer with seed
    add  a,$3D       ; add a constant (LCG-ish step)
    rrca             ; rotate right (more mixing)
    ld  [RandomSeed],a   ; store new seed
	pop bc
    ret              ; A = random


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

; =================================================
; ABS - Get absolute value of A
; =================================================
; Input:
;   A - signed value
; Output:
;   A - absolute value
; =================================================
export ABS
ABS:
    bit 7, a
    jr z, .done

    ; negate
    cpl
    inc a
.done:
    ret