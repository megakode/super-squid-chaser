
INCLUDE "hardware.inc"
	rev_Check_hardware_inc 4.0

SECTION "Header", ROM0[$100]

	; This is your ROM's entry point
	; You have 4 bytes of code to do... something
	di
	jp EntryPoint

	; Make sure to allocate some space for the header, so no important
	; code gets put there and later overwritten by RGBFIX.
	; RGBFIX is designed to operate over a zero-filled header, so make
	; sure to put zeros regardless of the padding value. (This feature
	; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
	; introduced in that version.)
	ds $150 - @, 0


SECTION "OAM Data", WRAM0, ALIGN[8] ; align to 256 bytes
	
	EXPORT ShadowOAMData	
	ShadowOAMData:
		SprPlayerY:   db
		SprPlayerX:   db
		SprPlayerTileNum:   db
		SprPlayerAttributes:db
		ds 4 * 39 ; reserve space for 40 sprites (4 bytes each)
	ShadowOAMDataEnd:	

SECTION "Game variables", WRAM0

; Misc

RandomSeed: db

; Player 

PlayerTileX: db
PlayerTileY: db

SECTION "Entry point", ROM0
	
	Tiles:    
		INCBIN "assets/bg_stars.2bpp"
	TilesEnd:
	
	Sprites:	
		INCBIN "assets/sprites.2bpp"
	SpriteDataAlien1:
		INCBIN "assets/alien1.2bpp"
	SpriteDataAlien2:
		INCBIN "assets/alien2.2bpp"
	SpriteDataAlien3:
		INCBIN "assets/alien3.2bpp"
	SpritesEnd:

def AlienOffset1 = (SpriteDataAlien1 - Sprites) / 16
println "Alien 1 sprite offset in tiles: 0x{x:AlienOffset1}"

def AlienOffset2 = (SpriteDataAlien2 - Sprites) / 16
println "Alien 2 sprite offset in tiles: 0x{x:AlienOffset2}"

def AlienOffset3 = (SpriteDataAlien3 - Sprites) / 16
println "Alien 2 sprite offset in tiles: 0x{x:AlienOffset3}"
; ----------------------------------------------
; Sprite Definitions
; ----------------------------------------------
; Each sprite definition consists of:
;
;   - Tile data start index (1 byte)
;   - Total frames (1 byte)
;   - Frame delay (1 byte)
;   - Attributes (1 byte) unused for now
;
; The tile data start index is the index of the first tile
; for the sprite animation in VRAM.
; It is not directly coupled to the tile data loaded from the
; sprite .2bpp files, as those are loaded sequentially into VRAM.
; Rather, just look in the debugger to see what tile index each sprite
; starts at after loading, and use that value here.
; ----------------------------------------------

SprDef_Alien1:
db AlienOffset1, 4, 10, 0  ; Alien 1
SprDef_Alien2:
db AlienOffset2, 5, 10, 0  ; Alien 2
SprDef_Alien3:
db AlienOffset3, 5, 10, 0  ; Alien 3
SprDef_Exhaust:
db 1, 5, 10, 0


	

EntryPoint:
	
	; turn off lcd
	xor a ; ld a, 0
	ld [rLCDC], a

	; Copy the tile data to VRAM $9000

	ld de, Tiles
	ld hl, $9000
	ld bc, TilesEnd - Tiles
	call Memcopy

	ld de, Sprites
	ld hl, $8000 
	ld bc, SpritesEnd - Sprites
	call Memcopy

	ld a,0xab; initial seed value
	ld [RandomSeed], a 

	
	call ClearScreen
	call GenerateBackgroundPattern

	
	; Setup LCD screen
	
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
	
	; Setup default palettes
	
	ld a, `11100100
	ld [rOBP0], a
	ld [rOBP1], a
	ld [rBGP], a
	
	; Clear existing sprites
	call SpritesClear
	
	; Setup a sprite
	ld a,80 ; Y position
	ld [SprPlayerY], a
	ld a,40 ; X position
	ld [SprPlayerX], a
	ld a,0  ; Tile number
	ld [SprPlayerTileNum], a
	ld a,0 ; No attributes
	ld [SprPlayerAttributes], a
	
	; move DMA subroutine to HRAM
	call SetupDMACopy
	
	call SpriteAnimationsInit
	call InputHandlerInit
	
	; ld de, SprDef_Alien1
	; ld a,0 ; sprite 0
	; ld b, AnimationStatePlayOnce
	; call SpriteAnimationAdd


.game_loop:

	call SpriteAnimationsUpdate

	; update game logic

	call InputHandlerUpdate
	
	call WaitVBlank

	; call the DMA subroutine we copied to HRAM, which then copies the shadow OAM data to video memory
	ld  a, HIGH(ShadowOAMData)
	call ExecuteDMACopy

	jr  .game_loop
	
; --------------------------------
; Button was pressed event handler
; --------------------------------
; A = button identifier
; --------------------------------
export ButtonWasPressed
ButtonWasPressed:

	ret
		
; --------------------------------
; Button was released event handler
; --------------------------------
; A = button identifier
; --------------------------------
export ButtonWasReleased
ButtonWasReleased:

	ret

; --------------------------------
; Button is down event handler
; --------------------------------
; A = button identifier
; --------------------------------
export ButtonIsDown
ButtonIsDown:
	cp BUTTON_RIGHT
	jr z,.right_was_pressed
	cp BUTTON_LEFT
	jr z,.left_was_pressed
	cp BUTTON_UP
	jr z,.up_was_pressed
	cp BUTTON_DOWN
	jr z,.down_was_pressed
	ret

.right_was_pressed:
	ld a,[SprPlayerX]
	inc a
	ld [SprPlayerX],a
	ret
	
.left_was_pressed:
	ld a,[SprPlayerX]
	dec a
	ld [SprPlayerX],a
	ret
	
.up_was_pressed:
	ld a,[SprPlayerY]
	dec a
	ld [SprPlayerY],a
	ret
	
.down_was_pressed:
	ld a,[SprPlayerY]
	inc a
	ld [SprPlayerY],a
	ret

; ------------------------
; play move animation
; -----------------------

.PlayMoveAnimation:

ld de, SprDef_Alien1
ld a,0 ; sprite 0
ld b, AnimationStatePlayOnce
call SpriteAnimationAdd

ret 

; -----------------------------
; Generate Background Pattern
; -----------------------------
; Fill BG map at $9800 with random tiles from 0-9, else tile 0

GenerateBackgroundPattern:

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
	ret

; -----------------------------
; Clear Screen
; -----------------------------
; Set all BG map tiles from $9800 to $9C00 to 0

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

; -----------------------------
; Wait for VBlank
; -----------------------------
		
WaitVBlank:

		ld a, [rLY]
		cp 144
		jr c, WaitVBlank
		ret


;-----------------------------
; Memcopy
;-----------------------------	
; Copy bytes from one area to another.
; Uses registers: a,b,c,d,e,h,l
; @param de: Source
; @param hl: Destination
; @param bc: Length

Memcopy:

	ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, Memcopy
    ret

; -----------------------------
; Random
; -----------------------------
; Simple pseudo-random number generator

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


; Debug print the size of the sprite data

PRINTLN "-----------------------------"
DEF tiles_size = (TilesEnd - Tiles)
PRINTLN "Size of tiles: {d:tiles_size} bytes"
DEF sprites_size = (SpritesEnd - Sprites)
PRINTLN "Size of sprites: {d:sprites_size} bytes"
PRINTLN "-----------------------------"