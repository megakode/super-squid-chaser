INCLUDE "hardware.inc"
INCLUDE "config.inc"

SECTION "Mines variable", WRAM0

def MAX_MINES = 10
def MINE_TRIGGER_RADIUS = 4

MineCount:          ds 1         ; Number of active mines
MineIsActive:       ds MAX_MINES ; Active flags for mines (1 = active, 0 = inactive)
MineTriggered:      ds MAX_MINES ; Triggered flags for mines (1 = triggered, 0 = not)
MineX:              ds MAX_MINES ; X positions of mine
MineY:              ds MAX_MINES ; Y positions of mine
MineCountDownTimer: ds MAX_MINES ; Countdown timers for mines

export MineSpritesPtr
MineSpritesPtr: ds 2 ; Pointer to the sprites used in shadow OAM

PlayerTileX: ds 1 ; Player's tile X position
PlayerTileY: ds 1 ; Player's tile Y position

SECTION "Mines routines", ROM0

; ==========================================
; MinesInit
; Initializes mine data
;
; Inputs:
; HL - Pointer to Shadow
; ==========================================
export MinesInit
MinesInit:
    ; Initialize mine data
    ld bc, 0
    ld hl,MineCount
    ld [hl], 0 ; Set mine count to 0
.init_loop:
    ld a, 0
    ld hl,MineX
    add hl,bc
    ld [hl], a ; Set X
    ld hl,MineY
    add hl,bc
    ld [hl], a ; Set Y
    ld hl,MineIsActive
    add hl,bc
    ld [hl], a ; Set inactive
    ld hl,MineCountDownTimer
    add hl,bc
    ld [hl], a ; Set timer to 0
    ld hl,MineTriggered
    add hl,bc
    ld [hl], a ; Set not triggered

    inc c
    ld a,c
    cp MAX_MINES
    jr c, .init_loop

    ret

; ==========================================
; MineAdd
; Adds a new mine if there is an available slot
; Inputs:
;   D - Y position of the mine
;   E - X position of the mine
; Outputs:
;   A - 1 if a mine is added successfully, 0 if no slot available
; ==========================================
export MineAdd
MineAdd:
    push af
    push bc
    push hl

    ld hl,MineIsActive
    ld bc,0
.find_slot:
    ld a, [hl]
    cp 0
    jr z, .slot_found
    inc hl
    inc c
    ld a,c
    cp MAX_MINES
    jr nz, .find_slot

.slot_found:
    ; Mark mine as active
    ld [hl], 1

    ; Set mine position
    ld hl,MineX
    add hl,bc
    ld [hl], e
    ld hl,MineY
    add hl,bc
    ld [hl], d

    ; Reset countdown timer
    ld hl,MineCountDownTimer
    add hl,bc
    ld [hl], MINE_COUNTDOWN_AMOUNT

    ; Mark mine as not triggered
    ld hl,MineTriggered
    add hl,bc
    ld [hl], 0

    ; Increment mine count
    ld hl,MineCount
    inc [hl]

    ; Add to tile map

    ld a,MineTilesOffset
    call SetBGTileByXY ; e=x, d=y, a=TILE_MINE


    
.done:

    pop hl
    pop bc
    pop af

    ret

; ======================================================================
; Mines Update
; Updates mine countdown timers and handles explosions

; ======================================================================
export MinesUpdate
MinesUpdate:

    ld a,[PlayerX]
	add 3 ; adjust for ship hotspot
	ld d,a
	ld a,[PlayerY]
    add 3 ; adjust for ship hotspot
	ld e,a

    ; in: 
    ; d = Player pixel Y
    ; e = Player pixel X
    ; out:
    ; d = Player tile X
    ; e = Player tile Y
    call ConvertSpriteXYToTileXY
    
    ld a,d
    ld [PlayerTileX], a
    ld a,e
    ld [PlayerTileY], a
    
    ; Loop through all mines and:
    ld bc,0x00ff ; so that the first 'inc c' sets bc to 0

.next_mine:

    ; Check if we've processed all mines
    inc c
    ld a,c
    cp MAX_MINES
    jp z, .done
    
    ; .update_loop:
    
    ld hl,MineIsActive
    add hl,bc
    ld a, [hl]
    cp 0
    jr z, .next_mine ; Skip inactive mines

    ; If triggered, decrement countdown timer

    ld hl,MineTriggered
    add hl,bc
    ld a, [hl]
    cp 1
    jr nz, .check_if_within_player_radius ; Not triggered, skip timer decrement
    
    ; Decrement timer. If timer reaches 0, do explosion

    ld hl,MineCountDownTimer
    add hl,bc
    ld a, [hl]
    dec a
    ld [hl], a
    cp 0
    jr nz, .next_mine ; Timer not zero yet, skip explosion

    ; Handle explosion
    ld hl,MineIsActive
    add hl,bc
    ld [hl], 0 ; Set mine as inactive
    
    ld hl,MineCount
    dec [hl] ; Decrement mine count

    ; input: c = mine index
    call MineRemove
    call MineExplode
    jr .next_mine

.check_if_within_player_radius:


    ; Check if player is within trigger radius
    ; if yes and not already triggered: set triggered flag

    ; check if PlayerTileX/Y is within MINE_TRIGGER_RADIUS of MineX/Y
    ld hl,MineX
    add hl,bc
    ld d, [hl]
    ld a,[PlayerTileX]
    ld e,a

    ; D = Minx  
    ; E = PlayerTileX
    
    ; compute abs(d - e)

    ld a,d
    sub e
    call ABS

    ; a = abs(MineX - PlayerTileX)

    cp MINE_TRIGGER_RADIUS
    jr c, .check_y ; Within radius
    jr .next_mine ; Outside radius

.check_y:

    ld hl,MineY
    add hl,bc
    ld d, [hl]
    ld a,[PlayerTileY]
    ld e,a

    ; D = MineY  
    ; E = PlayerTileY
    ld a, d
    sub e
    call ABS

    ; a = abs(MineY - PlayerTileY)

    cp MINE_TRIGGER_RADIUS
    jr nc, .next_mine ; outside radius

    ; Set mine as triggered
    ld hl,MineTriggered
    add hl,bc
    ld [hl], 1


	; input: d = mine tile y, e = mine tile x
    ; output: hl = address in BG map
    ld hl,MineY
    add hl,bc
    ld d, [hl]
    ld hl,MineX
    add hl,bc
    ld e, [hl]
    call GetMapIndexFromTileXY
    
    ld b,1
	ld de, MineAnim
	call TileAnimationAdd
    ld b,0

    jp .next_mine

.done:     
    
    ret


; ==========================================
; MineExplode
; Handles mine explosion effects
; Inputs:
; c - mine index
; ==========================================

MineExplode:   
    ; TODO implement this.
    ; - remove mine tile from BG map
    ; - create explosion animation at mine location
    ; - deal damage to player if within explosion radius
    ret 


; =================================================
; MineRemove
;
; Removes a mine
;
; - disables it in the mine list
; - removes its tile from the BG map
; - stop any ongoing tile animation
;
; Inputs:
;   C = mine index to remove
; =================================================
export MineRemove
MineRemove:
    push bc
    push hl
    push af
    
    ; Disable mine
    ld b,0
    ld hl,MineIsActive
    add hl,bc
    ld [hl], b ; Set inactive

    ld hl,MineY
    add hl,bc
    ld d, [hl]
    ld hl,MineX
    add hl,bc
    ld e, [hl]

    ; Stop any ongoing tile animation
    call GetMapIndexFromTileXY ; in: d=y, e=x; out:  HL = tile map Index
    
    ; Clear tile
    ld a,0 ; tile 0 = clear
    call SetBGTileByXY ; input d=y, e=x, a=tile (0 to clear)
    
    ; Stop tile animation
    ld d,h
    ld e,l ; de = tile map index
    call TileAnimationFindByTileMapIndex ; in: de = tile map index

    jr nc, .no_animation_found

    ; Animation found, remove it
    ld [hl],0 ; mark as inactive


.no_animation_found:

    pop af
    pop hl
    pop bc
    ret