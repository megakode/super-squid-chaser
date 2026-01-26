INCLUDE "hardware.inc"


; ==========================================================================
;
; Routines for managing background tile graphics
;
; E.g. generating patterns, clearing the screen, etc.
;
; ==========================================================================

SECTION "BG Shadow Tile Map", WRAM0[$C000]



export ShadowTileMap
ShadowTileMap:
	ds 32 * 32 ; reserve space for 32x32 tile map
ShadowTileMapEnd:
	
def ShadowTileMapSize = ShadowTileMapEnd - ShadowTileMap


export ShadowTileMapDirtyRows
ShadowTileMapDirtyRows:
	ds 32       ; one byte per row to indicate if that row is dirty (needs redrawing)

SECTION "BG variables", WRAM0


SECTION "BG Functions", ROM0

export ClearRockRow
export GenerateRockRow
export GenerateRockMap
export ClearScreen

export GenerateBackgroundMap
export GenerateBackgroundRow

; ======================================================================
; Set BG Tile by X,Y
;
; Tile is set in the shadow BG map, and marked as dirty for later update
;
; inputs:
;   - A = tile index
;   - D = Y row index (0-31)
;   - E = X column index (0-31)
; ======================================================================

export SetBGTileByXY
SetBGTileByXY:

	push hl
	push bc

	ld b,0
	ld c,d

	ld h,0
	ld l,d
	add hl, hl ; hl = row index * 2
	add hl, hl ; hl = row index * 4
	add hl, hl ; hl = row index * 8
	add hl, hl ; hl = row index * 16
	add hl, hl ; hl = row index * 32
	
	ld d,0
	add hl,de               ; hl = (row index * 32) + column index
	ld d,h
	ld e,l

	ld hl, ShadowTileMap ; start of BG map
	add hl, de ; hl = address of tile in BG map
	
	ld [hl], a

	ld hl,ShadowTileMapDirtyRows
	add hl, bc
	ld [hl], 1 ; mark row as dirty

	pop bc
	pop hl

	ret

; ======================================================================
; Clear Rock Row
;
; inputs:
;   - A = row index (0-31)
; ======================================================================

ClearRockRow:

	push bc
	push de
	push hl

	ld bc,0
	ld de, ShadowTileMap        ; start of BG map

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

	ld hl,ShadowTileMapDirtyRows
	ld d,0
	ld e,a
	add hl,de
	ld [hl], 1 ; mark row as dirty

	pop hl
	pop de
	pop bc

	ret

; ======================================================================
; Draw Dirty Rows to BG Map
; Must be called during VBlank
; ======================================================================
export DrawDirtyRowsToBGMap
DrawDirtyRowsToBGMap:

	ld bc,0

.next_row:

	ld hl,ShadowTileMapDirtyRows
	add hl,bc
	ld a,[hl]
	cp 0
	jr z, .skip_row

	ld [hl], 0 ; clear dirty flag

	push bc

	; setup DST pointer in BG map
	ld h,b
	ld l,c
	add hl,hl ; hl = row index * 2
	add hl,hl ; hl = row index * 4
	add hl,hl ; hl = row index * 8
	add hl,hl ; hl = row index * 16
	add hl,hl ; hl = row index * 32
	ld b,h ; BC = index * 32
	ld c,l
	ld hl, $9800
	add hl,bc ; 
	ld d,h 
	ld e,l  ; DE = 9800 + (row index * 32)

	; Setup SRC pointer from shadow BG map
	ld hl,ShadowTileMap
	add hl,bc ; HL = ShadowTileMap + (row index * 32)
	
	; copy row
	REPT 20 ; number of visible tiles in a row
	ld a,[hli]
	ld [de],a
	inc de
	ENDR
	
	pop bc

	; Return after copying one row. 
	; Call repeatedly to draw all rows. 
	; This ensures VBlank time is not exceeded.
	; We do have time to copy 2 (maybe 3) rows per VBlank, but to be safe we only do one for now.
	ret 

	.skip_row:

	inc c
	ld a,c
	cp 32
	jr c, .next_row

	ret 


; ======================================================================
; Generate Rock Row
; ======================================================================
; Generates a row of rocks at random positions into a buffer. 
; Can be done without access to video memory.
;
; Inputs:
;   - A = row index (0-31)
; ======================================================================
GenerateRockRow:

	push af
	push bc
	push de
	push hl

	ld hl,ShadowTileMapDirtyRows
	ld d,0
	ld e,a
	add hl,de
	ld [hl], 1 ; mark row as dirty

	ld bc,0
	ld de, ShadowTileMap        ; start of BG map

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
	pop af

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

	ld hl,ShadowTileMapDirtyRows
	ld d,0
	ld e,a
	add hl,de
	ld [hl], 1 ; mark row as dirty

    ld h, 0
    ld l, a        ; row index in L
    add hl, hl ; hl = row index * 2
    add hl, hl ; hl = row index * 4
    add hl, hl ; hl = row index * 8
    add hl, hl ; hl = row index * 16
    add hl, hl ; hl = row index * 32

	ld de, ShadowTileMap        ; start of BG map
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

	ld c,0 ; row index
	ld hl,ShadowTileMapDirtyRows
	.mark_dirty_rows:
	ld a,1
	ld [hli], a ; mark row as dirty
	inc c
	ld a,c
	cp 32
	jr c, .mark_dirty_rows


	ld hl, ShadowTileMap        ; start of BG map
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
	push bc
	push af

	ld bc,ShadowTileMapSize
	ld hl,ShadowTileMap
	.clearLoop
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr z, .clearLoop

	pop af
	pop bc
	pop hl

	ret


; ======================================================================
; Get Map Address from Sprite Coordinates
; ======================================================================
;
; Adjusts for SCY (vertical scrolling) only
; 
; Inputs:
;   - D = Sprite X position in pixels
;   - E = Sprite Y position in pixels
; Outputs:
;   - HL = Address in BG map corresponding to tile coordinates
;
; ======================================================================
export GetMapAddressFromSpriteCoordinates
GetMapAddressFromSpriteCoordinates:

	ld a,[rSCY]
	add a, e                 ; E = spr Y position + scroll Y
	sub a,16				 ; adjust for margin
	ld e,a
	srl e
	srl e
	srl e                    ; E = sprite Y position in tiles


	; TODO: Does not handle Scroll X because we don't scroll horizontally in the game

	ld h,0
	ld l,e    ; hl = tile Y
	add hl,hl ; hl = tile Y * 2
	add hl,hl ; hl = tile Y * 4
	add hl,hl ; hl = tile Y * 8
	add hl,hl ; hl = tile Y * 16
	add hl,hl ; hl = tile Y * 32
	ld b,h
	ld c,l
	ld hl, ShadowTileMap
	add hl,bc ; hl = $9800 + (tile Y * 32)
	
	ld a, d ; e = Sprite X
	sub 8
	ld e,a
	ld d,0
	srl e
	srl e
	srl e                    ; e = Sprite X in tiles
	add hl,de               ; hl = $9800 + (tile Y * 32) + tile X

	ret


; ======================================================================
; Convert Sprite X,Y to Tile X,Y
; inputs:
;   - D = Sprite X position in pixels
;   - E = Sprite Y position in pixels
; outputs:
;   - D = Tile Y position
;   - E = Tile X position
; ======================================================================
export ConvertSpriteXYToTileXY
ConvertSpriteXYToTileXY:

	ld a,[rSCY]
	add a, e                 ; E = spr Y position + scroll Y
	sub a,16				 ; adjust for margin
	ld e,a
	srl e
	srl e
	srl e                    ; E = sprite Y position in tiles


	ld a, d ; e = Sprite X
	sub 8
	srl d
	srl d
	srl d                    ; d = Sprite X in tiles

	ret

; ======================================================================
; Get Map Index from Tile X,Y
; Inputs:
;   - D = Tile Y position (0-31)
;   - E = Tile X position (0-31)
; Outputs:
;   - HL = Index in BG map corresponding to tile coordinates
; ======================================================================

export GetMapIndexFromTileXY
GetMapIndexFromTileXY:

	push bc

	ld h,0
	ld l,d    ; hl = tile Y
	add hl,hl ; hl = tile Y * 2
	add hl,hl ; hl = tile Y * 4
	add hl,hl ; hl = tile Y * 8
	add hl,hl ; hl = tile Y * 16
	add hl,hl ; hl = tile Y * 32
	
	ld d,0
	add hl,de               ; hl = (tile Y * 32) + tile X

	pop bc

	ret