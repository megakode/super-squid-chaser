
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

; OAM Entry bytes:
; Byte 0: Y Position
; Byte 1: X Position
; Byte 2: Tile Number
; Byte 3: Attributes

; Sprite Attribute Byte Bits:
; 7: Render priority
; 6: Y flip
; 5: X flip
; 4: Palette number
; 3: VRAM bank            (GB Color only)
; 2: Palette number bit 3 (GB Color only)
; 1: Palette number bit 2 (GB Color only)
; 0: Palette number bit 1 (GB Color only)
	
	EXPORT ShadowOAMData	
	ShadowOAMData:
		SprPlayerY:   db
		SprPlayerX:   db
		SprPlayerTileNum:   db
		SprPlayerAttributes:db
		SprShots:  ds 4 * 5 ; reserve space for 5 shots (4 bytes each)
		SprEnemies:  ds 4 * 20 ; reserve space for 20 enemies (4 bytes each)
		ds 4 * 14 ; reserve space for 40 sprites (4 bytes each)
	ShadowOAMDataEnd:	

def SprEnemiesIndex = (SprEnemies - ShadowOAMData) / 4

SECTION "Game variables", WRAM0

; Misc

RandomSeed: db

; Player 

PlayerX: db
PlayerY: db
PlayerThrustX: db
PlayerThrustY: db
PlayerVelocityX: db
PlayerVelocityY: db

; Shots / Rocks collision tracking

CurrentShotTileX: db
CurrentShotTileY: db
; CurrentShotIndex: db

SECTION "Entry point", ROM0
	
	Tiles:    
		INCBIN "assets/bg_stars.2bpp"
		INCBIN "assets/statusbar.2bpp"
	RockTiles:
		INCBIN "assets/rocks.2bpp"   ; Rocks in complete state
		INCBIN "assets/rocks_2.2bpp" ; damaged 1/3
		INCBIN "assets/rocks_3.2bpp" ; damaged 2/3
		INCBIN "assets/rocks_4.2bpp" ; damaged 3/3
	RockTilesEnd:
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

;def StatusbarTileOffset = (TilesStatusbar - Tiles) / 16
;println "Statusbar tile offset in tiles: 0x{x:StatusbarTileOffset}"

def AlienOffset1 = (SpriteDataAlien1 - Sprites) / 16
println "Alien 1 sprite offset in tiles: 0x{x:AlienOffset1}"

def AlienOffset2 = (SpriteDataAlien2 - Sprites) / 16
println "Alien 2 sprite offset in tiles: 0x{x:AlienOffset2}"

def AlienOffset3 = (SpriteDataAlien3 - Sprites) / 16
println "Alien 2 sprite offset in tiles: 0x{x:AlienOffset3}"

def RockTilesOffset = (RockTiles - Tiles) / 16
println "Rock tiles offset in tiles: 0x{x:RockTilesOffset}"
def RockTilesCount = (RockTilesEnd - RockTiles) / 16
println "Rock tiles count: {d:RockTilesCount} tiles"
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
	

RockData: 
db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1
db 0,0,0,1,0,1,0,1,1,0,0,1,0,1,0,0,1,0,1,0
db 0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 0,0,0,1,0,0,0,0,0,1,0,0,0,1,1,0,1,0,0,0
db 0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0
db 0,1,0,0,1,0,0,0,0,1,0,0,0,0,1,0,1,0,1,0
db 0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0
db 0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0
RockDataEnd:


EntryPoint:
	
	; turn off lcd
	xor a ; ld a, 0
	ld [rLCDC], a

	; Copy BG tile data to VRAM $9000

	ld de, Tiles
	ld hl, $9000
	ld bc, TilesEnd - Tiles
	call Memcopy

	; Copy status bar tile data to VRAM $9800
	ld de,StatusbarTileMap
	ld hl,$9c00 ; BG map start
	ld bc, 20
	call Memcopy

	; Copy sprite data to VRAM $8000

	ld de, Sprites
	ld hl, $8000 
	ld bc, SpritesEnd - Sprites
	call Memcopy

	ld a,0xab; initial PRNG seed value
	ld [RandomSeed], a 

	
	call ClearScreen
	call GenerateBackgroundPattern

	; Show window status bar
	call ShowStatusBar
	; Set initial status bar values
	ld hl,StatusBarMovementValue
	ld [hl], DEFAULT_MOVEMENT_VALUE ; initial movement value
	ld hl,StatusBarAmmoValue
	ld [hl], DEFAULT_AMMO_VALUE ; initial ammo value
	ld hl,StatusBarGemValue
	ld [hl], DEFAULT_GEM_VALUE ; initial gem value

	call StatusBarUpdate

	call PlaceRocksOnMap
	
	; Setup LCD screen
	
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_WINON | LCDCF_WIN9C00 | LCDCF_BG9800 | LCDCF_PRIOFF
    ld [rLCDC], a

	; Setup default palettes
	
	ld a, `11100100
	ld [rOBP0], a
	ld [rOBP1], a
	ld [rBGP], a
	
	; Clear existing sprites
	call SpritesClear
	
	; Setup a sprite

	ld a,0
	ld hl,PlayerThrustX
	ld [hl],a
	ld hl,PlayerThrustY
	ld [hl],a
	ld hl,PlayerVelocityX
	ld [hl],a
	ld hl,PlayerVelocityY
	ld [hl],a

	ld a,80 ; Y position
	ld [PlayerY], a
	ld a,40 ; X position
	ld [PlayerX], a
	ld a,0  ; Tile number
	ld [SprPlayerTileNum], a
	ld a,`00000000 ; No attributes
	ld [SprPlayerAttributes], a
	
	; move DMA subroutine to HRAM
	call SetupDMACopy
	
	call SpriteAnimationsInit
	call InputHandlerInit
	
	ld hl,SprShots
	call ShotsInit

	ld hl,SprEnemies
	call EnemiesInit
	; add an enemy for testing
	ld d, 120 ; X position
	ld e, 60  ; Y position
	call AddEnemy


	ld de, SprDef_Alien1
	ld a,SprEnemiesIndex
	ld b, AnimationStatePlayLooped
	call SpriteAnimationAdd


.game_loop:

	call SpriteAnimationsUpdate
	call UpdateShots

	; update game logic

	call InputHandlerUpdate

	call UpdatePlayerMovement
	; call UpdateEnemies
	
	call WaitVBlank

	call DrawShots
	call DrawEnemies
	call StatusBarUpdate

	; TODO: optimize by calculating a list of "explosions" where colision occurred and only updating those rocks in the BG map during VBlank
	call ColisionDetectionShotsRocks 

	; call the DMA subroutine we copied to HRAM, which then copies the shadow OAM data to video memory
	ld  a, HIGH(ShadowOAMData)
	call ExecuteDMACopy

	jr  .game_loop

; ---------------------------------
; Collision detection between shots and rocks
; ---------------------------------

ColisionDetectionShotsRocks:

	ld bc,0
	ld a,0

.next_shot:

	ld hl,PlayerShotsActive
	add hl, bc
	ld a,[hl]
	cp 0
	jr z, .skip_shot ; if shot not active, skip


	; get shot X/Y position and convert to tile coordinates

	ld hl, PlayerShotsX
	add hl, bc
	ld a, [hl]               ; D = shot X position in pixels
	sub 4 ; adjust for shot hotspot
	srl a					 ; convert to tile coordinate (divide by 8)
	srl a
	srl a                    ; D = shot X position in tiles
	ld [CurrentShotTileX],a

	ld hl,PlayerShotsY
	add hl, bc
	ld a, [hl]               ; E = shot Y position in pixels
	sub 16 ; adjust for shot hotspot
	srl a					 ; convert to tile coordinate (divide by 8)
	srl a
	srl a                    ; E = shot Y position in tiles
	ld [CurrentShotTileY], a


	; calculate address in BG map

	ld h,0
	ld l,a ; hl = tile Y
	add hl,hl ; hl = tile Y * 2
	add hl,hl ; hl = tile Y * 4
	add hl,hl ; hl = tile Y * 8
	add hl,hl ; hl = tile Y * 16
	add hl,hl ; hl = tile Y * 32
	ld d,h
	ld e,l
	ld hl, $9800
	add hl,de ; hl = $9800 + (tile Y * 32)
	ld a, [CurrentShotTileX]
	ld d,0
	ld e,a
	add hl,de ; hl = $9800 + (tile Y * 32) + tile X
	
	; is there a rock here? ( Tile number between RockTilesOffset and RockTilesOffset + RockTilesCount )

	ld a,[hl] 			 ; A = tile number at shot position
	cp RockTilesOffset
	jr c, .skip_shot       ; if tile number < RockTilesOffset, no rock present
	cp RockTilesOffset + RockTilesCount
	jr nc, .skip_shot      ; if tile number >= RockTilesOffset + RockTilesCount, no rock present

	add 4 ; advance to next rock damage state tile
	ld [hl],a

	; remove shot (set active flag to 0)
	ld hl, PlayerShotsActive
	add hl, bc
	ld a,0
	ld [hl], a

	ld hl,PlayerShotsCount
	dec [hl]

	; TODO: update shadow OAM to hide shot sprite

	
.skip_shot:

	; increment to next shot

	; are we there yet?
	inc c
	ld a, c
	cp MAX_PLAYER_SHOTS
	jr c, .next_shot


	ret

; --------------------------------
; Place rocks on map
; --------------------------------
; Places rock tiles on the background map at random positions
PlaceRocksOnMap:

	ld hl,RockData
	ld c,0
	ld de, $9800        ; start of BG map

.next_tile:

	; Load rock data from byte array
	; ld a,[hl]
	; cp 0
	; jr z,.skip_place_rock

	; Decide rock data randomly
	call GetPseudoRandomByte
	and `11
	cp 0
	jr nz,.skip_place_rock

	; place rock tile
	push hl
	ld h,d
	ld l,e

	; add PRNG to rock tile variation
	call GetPseudoRandomByte
	and `11             ; limit to 0-31 tile indices
	add RockTilesOffset 
	ld [hl], a
	pop hl

.skip_place_rock:

	inc hl
	inc de
	inc c

	ld a,c
	cp 20
	jp nz, .dont_increase_row

	push hl
	; move to next row by adding 12 to DE
	ld h,d    ; DE -> HL
	ld l,e
	ld de,12 
	add hl,de ; HL += 12
	ld d,h    ; HL -> DE
	ld e,l
	ld c,0

	pop hl

.dont_increase_row:

	ld   a, h
    cp   HIGH(RockDataEnd)
    jr   nz, .next_tile

    ld   a, l
    cp   LOW(RockDataEnd)
    jr   nz, .next_tile

	ret

; --------------------------------
; Update player movement
; --------------------------------
; Updates player position based on input and velocity

UpdatePlayerMovement:

	ld hl,PlayerThrustX
	ld [hl],0
	ld hl,PlayerThrustY
	ld [hl],0

.ship_movement_start:
.check_left:
	ld hl,button_left_is_down_flag
	ld a, [hl]
	cp 1
	jr nz, .check_left_done
	; button was just pressed, move player
	ld hl,PlayerThrustX
	ld [hl],-PLAYER_THRUST

.check_left_done:

.check_right:
	ld hl,button_right_is_down_flag
	ld a, [hl]
	cp 1
	jr nz, .check_right_done
	; button was just pressed, move player
	ld hl,PlayerThrustX
	ld [hl],PLAYER_THRUST

.check_right_done:


.check_up:
	ld hl,button_up_is_down_flag
	ld a, [hl]
	cp 1
	jr nz, .check_up_done
	; button was just pressed, move player
	ld hl,PlayerThrustY
	ld [hl],-PLAYER_THRUST

.check_up_done:

.check_down:
	ld hl,button_down_is_down_flag
	ld a, [hl]
	cp 1
	jr nz, .check_down_done
	; button was just pressed, move player
	ld hl,PlayerThrustY
	ld [hl],PLAYER_THRUST

.check_down_done:


	; *** Adjust velocity based on thrust ***

	; if( thrust.x != 0 ) PlayerVelocityX = Thrust.X
	ld hl,PlayerThrustX
	ld a,[hl]				; A = Thrust.X
	cp 0				    ; if (thrust.x == 0) goto .skip_velocity_x_update
	jr z,.skip_velocity_x_update
	ld hl,PlayerVelocityX	; hl = address of Velocity.X
	ld [hl],a			    ; PlayerVelocityX = Thrust.X	
.skip_velocity_x_update

	; if( thrust.y != 0 ) PlayerVelocityY = Thrust.Y
	ld hl,PlayerThrustY
	ld a,[hl]				; A = Thrust.Y
	cp 0				    ; if (thrust.y == 0) goto .skip_velocity_y_update
	jr z,.skip_velocity_y_update
	ld hl,PlayerVelocityY	; hl = address of Velocity.Y
	ld [hl],a			    ; PlayerVelocityY = Thrust.Y	
.skip_velocity_y_update

	; *** Update player position based on velocity ***

	; PlayerX += PlayerVelocityX
	ld hl,PlayerVelocityX
	ld a,[hl]				; A = PlayerVelocityX
	ld hl,PlayerX
	ld b, [hl]				; B = PlayerX
	add a, b				; A = PlayerX + PlayerVelocityX
	ld [hl], a				; PlayerX = A

	; PlayerY += PlayerVelocityY
	ld hl,PlayerVelocityY
	ld a,[hl]				; A = PlayerVelocityY
	ld hl,PlayerY
	ld b, [hl]				; B = PlayerY
	add a, b				; A = PlayerY + PlayerVelocityY
	ld [hl], a				; PlayerY = A

	; *** Bounds checking ***

	; if PlayerX < 8 then PlayerX = 8
	ld hl,PlayerX
	ld a,[hl]
	cp 8
	jr nc, .skip_playerx_min_bound
	ld b,8
	ld [hl],b
.skip_playerx_min_bound:

	; if PlayerX > 160 then PlayerX = 160
	cp 160
	jr c, .skip_playerx_max_bound
	ld b,160
	ld [hl],b
.skip_playerx_max_bound:

	; if PlayerY < 16 then PlayerY = 16
	ld hl,PlayerY
	ld a,[hl]
	cp 16
	jr nc, .skip_playery_min_bound
	ld b,16
	ld [hl],b
.skip_playery_min_bound:

	; if PlayerY > 143 then PlayerY = 143
	cp 143
	jr c, .skip_playery_max_bound
	ld b,143
	ld [hl],b
.skip_playery_max_bound:

	; *** Decelerate velocity ***
	
	ld hl, PlayerVelocityX
	ld a, [hl]
	ld b,PLAYER_DEACCELERATION
	call DecayTowardsZero
	ld [hl], a

	ld hl,PlayerVelocityY
	ld a, [hl]
	ld b,PLAYER_DEACCELERATION
	call DecayTowardsZero
	ld [hl], a

	; *** Update sprite position ***

	ld hl,PlayerX
	ld a,[hl]        ; A = PlayerX
	ld hl,SprPlayerX
	ld [hl], a		; update sprite X position

	ld hl,PlayerY
	ld a,[hl]        ; A = PlayerY
	ld hl,SprPlayerY
	ld [hl], a		; update sprite Y position

	ret
	
; --------------------------------
; Button was pressed event handler
; --------------------------------
; A = button identifier
; --------------------------------
export ButtonWasPressed
ButtonWasPressed:

	cp BUTTON_A
	jr z,.a_was_pressed
	ret

.a_was_pressed:
	
	; Fire a shot
	ld hl,PlayerX
	ld d,[hl]
	ld hl,PlayerY
	ld e,[hl]
	call AddShot
		
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
	ret
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