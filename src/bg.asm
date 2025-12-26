; ==========================================================================
;
; Routines for managing background tile graphics
;
; E.g. generating patterns, clearing the screen, etc.
;
; ==========================================================================

SECTION "BG variables", WRAM0

SECTION "BG Functions", ROM0

export ClearRockRow
export GenerateRockRow
export GenerateRockMap
export ClearScreen

export GenerateBackgroundMap
export GenerateBackgroundRow

; ======================================================================
; Clear Rock Row
; ======================================================================

ClearRockRow:

	push bc
	push de
	push hl

	ld bc,0
	ld de, $9800        ; start of BG map

	ld h,0
	ld l,a
	add hl, hl ; hl = row index * 2
	add hl, hl ; hl = row index * 4
	add hl, hl ; hl = row index * 8
	add hl, hl ; hl = row index * 16
	add hl, hl ; hl = row index * 32

	add hl, de ; hl = address of start of row in BG map

	ld a,0

.next_tile:

	ld [hl], 0
	inc hl

	inc c

	ld a,c
	cp 20
	jp nz, .next_tile

.done:

	pop hl
	pop de
	pop bc

	ret

; ======================================================================
; Generate Rock Row
; ======================================================================
; Generates a row of rocks at random positions
;
; Inputs:
;   - A = row index (0-31)
; ======================================================================
GenerateRockRow:

	push bc
	push de
	push hl

	ld bc,0
	ld de, $9800        ; start of BG map

	ld h,0
	ld l,a
	add hl, hl ; hl = row index * 2
	add hl, hl ; hl = row index * 4
	add hl, hl ; hl = row index * 8
	add hl, hl ; hl = row index * 16
	add hl, hl ; hl = row index * 32

	add hl, de ; hl = address of start of row in BG map

.tile_loop:

	; decide whether to place rock or background tile (1/4 chance of rock)
	call GetPseudoRandomByte
	and `11
	cp 0
	jr nz,.generate_background_tile

.generate_rock_tile:

	; place rock tile, and add PRNG to rock tile variation
	call GetPseudoRandomByte
	and `11             ; limit to 0-31 tile indices
	add RockTilesOffset 
	ld [hl], a
	jp .next_tile

.generate_background_tile:
	
    ; NOTE: This code snippet is similar to GenerateBackgroundRow, but inlined here for performance
	call GetPseudoRandomByte
	and `111111             ; limit to 0-31 tile indices
	; compare A with 10 and jump if less than 10
	cp 10
	jr c, .set_background_tile ; if the random number is less the 10, use tile number A
	ld a, 0           ; otherwise use tile 0

.set_background_tile:

	ld [hl], a

.next_tile:

	inc hl
	inc c

	ld a,c
	cp 20
	jp nz, .tile_loop

.done:

	pop hl
	pop de
	pop bc

	ret

; ======================================================================
; Place rocks on map
; ======================================================================
;
; Places rock tiles on the background map at random positions
;
; ======================================================================
GenerateRockMap:

	ld c,0 ; row index

.next_row:

	ld a, c
	call GenerateRockRow

	inc c
	ld a, c
	cp 10
	jr c, .next_row

	ret


; ======================================================================
; Generate Background Row
; ======================================================================
;
; Fill a row of the BG map at $9800 with random tiles from 0-9, else tile 0
;
; Inputs:
;
;   - A = row index (0-31)
;
; Outputs: None
;
; ======================================================================

GenerateBackgroundRow:

    ld h, 0
    ld l, a        ; row index in L
    add hl, hl ; hl = row index * 2
    add hl, hl ; hl = row index * 4
    add hl, hl ; hl = row index * 8
    add hl, hl ; hl = row index * 16
    add hl, hl ; hl = row index * 32

	ld de, $9800        ; start of BG map
    add hl, de ; hl = address of start of row in BG map
	
    ld bc, 20      ; Number of (visible) tiles in a row. (Dont generate off-screen tiles)

.gen_loop:
	
	call GetPseudoRandomByte
	and `111111             ; limit to 0-31 tile indices
	; compare A with 10 and jump if less than 10
	cp 10
	jr c, .use_tile ; if the random number is less the 10, use tile number A
	ld a, 0           ; otherwise use tile 0

.use_tile:

	ld [hl+], a        ; write to BG map
	dec bc
	ld a, b
	or a, c
	jp nz, .gen_loop
	ret


; ======================================================================
; Generate Background Map star pattern
; ======================================================================
;
; Fill BG map at $9800 with random tiles from 0-9, else tile 0
;
; Inputs: None
; Outputs: None
;
; ======================================================================

GenerateBackgroundMap:

	push af
	push bc
	push hl

	ld hl, $9800        ; start of BG map
	ld bc, 32 * 32      ; size of BG map (32x32 tiles)

.gen_loop:
	
	call GetPseudoRandomByte
	and `111111             ; limit to 0-31 tile indices
	; compare A with 10 and jump if less than 10
	cp 10
	jr c, .use_tile ; if the random number is less the 10, use tile number A
	ld a, 0           ; otherwise use tile 0

.use_tile:

	ld [hl+], a        ; write to BG map
	dec bc
	ld a, b
	or a, c
	jp nz, .gen_loop

	pop hl
	pop bc
	pop af

	ret

; ======================================================================
; Clear Screen
; ======================================================================
;
; Set all BG map tiles from $9800 to $9C00 to 0
;
; Inputs: None
; Outputs: None
;
; ======================================================================

ClearScreen:

	push hl
	push af

	ld hl,$9800
	.clearLoop
	xor a
	ld [hli], a
	ld a, h
	cp $9C ; screen ends at $9C00
	jr nz, .clearLoop

	pop af
	pop hl

	ret
