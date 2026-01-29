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

	ld a,[PlayerY]
    add 3 ; adjust for ship hotspot
	ld d,a
    ld a,[PlayerX]
	add 3 ; adjust for ship hotspot
	ld e,a

    ; in: 
    ; d = Player pixel Y
    ; e = Player pixel X
    ; out:
    ; d = Player tile X
    ; e = Player tile Y
    call ConvertSpriteXYToTileXY
    
    ld a,e
    ld [PlayerTileX], a
    ld a,d
    ld [PlayerTileY], a

    ; Check if any mines are within trigger radius of player
    ; input d = player tile y, e = player tile x
    ; output: carry set if mine found, c = mine index
    call FindMineWithinRadius

    jr nc, .no_mine_close_to_player

    ; Mine found within radius, trigger it
    ; input: c = mine index
    call MineTrigger

.no_mine_close_to_player:
    
    ld bc,0x00ff ; so that the first 'inc c' sets bc to 0
    
    ; Loop through all mines and update timers:

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

    ; Check if out of bounds, if yes, remove mine

    ld a,[rSCY]
    ld d,a         ; D = SCY

    ld hl,MineY
    add hl,bc
    ld a, [hl]    ; A = mine_y
    sla a
    sla a
    sla a
    
    ; A = mine_y
    ; D = SCY c
    ; a = mine_y*8 - rscy

    sub a, d
    srl a
    srl a
    srl a

    ; A is now the row in the visible window where the mine is located (0-18)

    cp 18
    jr nz, .decrement_timer

    call MineRemove
    jr .next_mine

    ; If triggered, decrement countdown timer

.decrement_timer:

    ld hl,MineTriggered
    add hl,bc
    ld a, [hl]
    cp 1
    jr nz, .next_mine ; Not triggered, skip timer decrement
    
    ; Decrement timer. If timer reaches 0, do explosion

    ld hl,MineCountDownTimer
    add hl,bc
    ld a, [hl]
    dec a
    ld [hl], a
    cp 0
    jr nz, .next_mine ; Timer not zero yet, skip explosion

    ; input: c = mine index
    call MineRemove
    call MineExplode
    jr .next_mine

.done:     
    
    ret

; ==========================================
; MineTrigger
; Sets a mine as triggered, and starts its animation
; Inputs:
;  C - mine index
; ==========================================

MineTrigger:

    push af
    push hl
    push de
    push bc

    ; Set mine as triggered
    ld hl,MineTriggered
    add hl,bc
    ld [hl], 1


    ld hl,MineY
    add hl,bc
    ld d, [hl]
    ld hl,MineX
    add hl,bc
    ld e, [hl]
	; input: d = mine tile y, e = mine tile x
    ; output: hl = address in BG map
    call GetMapIndexFromTileXY
    
    ld b,1
	ld de, MineAnim
    ; input: b=play mode, de=pointer to sprite definition, hl=tile map index
	call TileAnimationAdd 
    ld b,0

    pop bc
    pop de
    pop hl
    pop af

    ret


; ==========================================
; FindMineWithinRadius
; Checks if a mine is within a certain radius of a point
; Inputs:
;  D - Y position to check
;  E - X position to check
; Outputs:
;  Carry set if within radius, reset if not
;  C = index of the mine
; ==========================================

FindMineWithinRadius:

    push hl

    ld bc,0x00ff
    
.next_mine:

    ; loop check
    inc c
    ld a,c
    cp MAX_MINES
    jp z, .done_no_mines_within_radius

    ; TODO: check it active and not triggered already

    ld hl,MineIsActive
    add hl,bc
    ld a, [hl]
    cp 0
    jr z, .next_mine ; Inactive mine, skip

    ld hl,MineTriggered
    add hl,bc
    ld a, [hl]
    cp 1
    jr z, .next_mine ; Already triggered, skip

    ; Check Y distance

    ld hl,MineY
    add hl,bc
    ld a, [hl]   ; A = MineY
    sub d        ; compute abs(a - d)
    call ABS

    ; a = abs(MineY - CheckY)

    cp MINE_TRIGGER_RADIUS
    jr c, .check_x ; Within radius
    jr .next_mine ; Outside radius

.check_x:

    ld hl,MineX
    add hl,bc
    ld a, [hl] ; A = MineX
    sub e      ; compute abs(a - e)
    call ABS

    ; a = abs(MineX - CheckX)

    cp MINE_TRIGGER_RADIUS
    jr nc, .next_mine ; outside radius

    ; Mine found within radius
    ; C = mine index
    scf ; set carry to indicate found
    jr .done

.done_no_mines_within_radius:     
    
    scf 
	ccf ; clear carry to indicate nothing found

.done:

    pop hl
    ret


; ==========================================
; MineExplode
; Handles mine explosion effects
; Inputs:
; c - mine index
; ==========================================

MineExplode:   

    ; TODO: deal damage to player if within explosion radius

    push bc
    push de
    push hl
    ld b,0

    ld hl,MineY
    add hl,bc
    ld d, [hl]
    ld hl,MineX
    add hl,bc
    ld e, [hl]

    ; TODO: check if other mines are within explosion radius and chain explode them
.find_other_mines:
    call FindMineWithinRadius
    jr nc, .did_not_find_mines
    call MineRemove
    call MineExplode
    jp .find_other_mines
.did_not_find_mines

    
    ; Explode a 5x5 area centered on the mine
    
    ; calculate starting position (top-left of 5x5 area)
    dec e
    dec e
    dec d
    dec d

    ; store row starting positions
    ld c, e

    REPT 5
        ld e,c
        REPT 5
            call MineExplosionAtXY ; in: d=tile y, e=tile x
            inc e
        ENDR

        inc d
    ENDR
    
    pop hl
    pop de
    pop bc

    ret 

; in: d = tile y, e = tile x
MineExplosionAtXY:

    push de

    ; bounds check 
    ld a,e
    cp 32
    jr nc, .out_of_bounds
    ; ld a,d
    ; cp 32
    ; jr nc, .out_of_bounds

    ; wrap to 0-31
    ld a,d
    and 31
    ld d,a
    ld a,e
    and 31
    ld e,a 

    ; Check if Player is on this tile - if yes, deal damage
    ld a,[PlayerTileX]
    cp e
    jr nz, .player_not_hit
    ld a,[PlayerTileY]
    cp d
    jr nz, .player_not_hit

    ; Player hit - deal damageh
    call PlayerTakeExplosionDamage

.player_not_hit:

    call GetMapIndexFromTileXY ; input: D=y, E=x,  Returns hl = tile map index

    ; - create explosion animation at mine location

    ld b,2 ; play_once
    ld de,TileAnimExplosion
    call TileAnimationAdd ; input: b=play mode, de=pointer to sprite definition

    .out_of_bounds:

    pop de

    ret 


; =================================================
; MineRemove
;
; Removes a mine
;
; - disables it in the mine list
; - removes its tile from the BG map
; - stop any ongoing tile animation
; - decrease mine count
; Inputs:
;   C = mine index to remove
; =================================================
export MineRemove
MineRemove:
    push bc
    push hl
    push af

    ld hl,MineCount
    dec [hl] ; Decrement mine count
    
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

; =================================================
; PlayerTakeExplosionDamage
; =================================================
; Deals damage to the player from an explosion
; =================================================
export PlayerTakeExplosionDamage
PlayerTakeExplosionDamage:
    ; For now, just reduce player health by a fixed amount
    ld hl,PlayerHealth
    ld a,[hl]
    sub PLAYER_EXPLOSION_DAMAGE ; fixed damage amount
    ld [hl], a


    ret 