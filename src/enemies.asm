INCLUDE "hardware.inc"

SECTION "Enemies variable", WRAM0

def MAX_PLAYER_SHOTS = 5
def PLAYER_SHOT_SPEED = 2

PlayerShotsCount:  ds 1                 ; Number of active player shots
PlayerShotsX:      ds MAX_PLAYER_SHOTS  ; X positions of player shots
PlayerShotsY:      ds MAX_PLAYER_SHOTS  ; Y positions of player shots
PlayerShotsActive: ds MAX_PLAYER_SHOTS  ; Active flags for player shots

export PlayerShotsSpritesPtr
PlayerShotsSpritesPtr: ds 2 ; Pointer to the sprites used in shadow OAM

SECTION "Enemies routines", ROM0

export ShotsInit
ShotsInit:
    ; Initialize player shots data
    ld d, h
    ld e, l
    ld hl,PlayerShotsSpritesPtr
    ld [hl],e
    inc hl
    ld [hl],d
    call ResetShots
    ret


; ==========================================
; Reset Shots
; ==========================================

export ResetShots
ResetShots:

    ; Initialize all player shots to inactive
    ld hl, PlayerShotsActive
    ld c, MAX_PLAYER_SHOTS
.reset_loop:
    ld [hl], 0          ; Set active flag to 0 (inactive)
    inc hl
    dec c
    jr nz, .reset_loop

    ld hl, PlayerShotsCount
    ld [hl], 0  ; Set shot count to 0

    ret

; ==========================================
; AddShot
;
; Adds a new player shot if there is an available slot
;
; Inputs:
;   D - X position of the shot
;   E - Y position of the shot
;
; Outputs:
;   A - 1 if shot added successfully, 0 if no slot available
; ==========================================

export AddShot
AddShot:

    push bc
    push hl

    ld hl,PlayerShotsCount
    ld a,[hl]
    cp MAX_PLAYER_SHOTS
    jr z, .no_slot_available

    ; Find an inactive shot slot
    ld hl, PlayerShotsActive
    ld c, 0
.find_slot:
    ld a, [hl]
    cp 0
    jr z, .slot_found
    inc hl
    inc c
    ld a,c
    cp MAX_PLAYER_SHOTS
    jr c, .find_slot

    ; No available slot, return 0
.no_slot_available:
    ld a,0
    jp .done

.slot_found:
 
    ; C now contains the index of the available slot
    
    ld [hl], 1              ; Mark shot as active
    ld hl, PlayerShotsX
    ld b,0
    add hl, bc
    ld [hl], d              ; Set X position
    ld hl, PlayerShotsY
    add hl, bc
    ld [hl], e              ; Set Y position

    ld hl,PlayerShotsCount
    inc [hl]               ; Increment shot count
    ld a,1                 ; Indicate shot added successfully

.done
    pop hl
    pop bc
    ret

; ==========================================
; UpdateShots
; ==========================================

export UpdateShots
UpdateShots:

    push hl
    push bc
    push de

    ld hl, PlayerShotsCount
    ld a, [hl]
    cp 0
    jr z, .no_shots ; If no active shots, skip update

    ld bc,0

.update_loop

    ld hl,PlayerShotsActive
    add hl, bc
    ld a, [hl]         ; Check if current shot is active..
    cp 1
    jr nz, .next_shot ; If not, skip

    ; ld hl,PlayerShotsX
    ; add hl, bc
    ; ld a, [hl]
    ; sub PLAYER_SHOT_SPEED
    ; ld [hl], a ; Update X position

    ld hl,PlayerShotsY
    add hl, bc
    ld a, [hl]
    cp 8                ; Check if shot is off-screen
    jr nc, .move_shot
    
.deactivate_shot:

    ld hl,PlayerShotsActive
    add hl, bc
    ld [hl], 0 ; Mark shot as inactive
    ld hl,PlayerShotsCount
    dec [hl] ; Decrement shot count
    jp .next_shot
    
.move_shot

    sub PLAYER_SHOT_SPEED
    ld [hl], a ; Update X position
        
.next_shot
    
    inc c
    ld hl,PlayerShotsActive
    add hl, bc
    ld a,c
    cp MAX_PLAYER_SHOTS
    jr c, .update_loop

.no_shots

    pop de
    pop bc
    pop hl

    ret

; ==========================================
; DrawShots
; 
; ==========================================
export DrawShots
DrawShots:

    ld bc,0 ; number of shot sprites processed

    .next_shot_draw:
    
    ; find active shots
    ld hl,PlayerShotsActive
    add hl, bc
    ld a,[hl]
    cp 1
    jr z,.draw_shot

.hide_shot:

    ld hl,PlayerShotsY
    add hl, bc      
    ld [hl], 0 ; off-screen Y position
    jp .update_shot_sprite

.draw_shot:
    ; draw shot sprite
    ld hl,PlayerShotsX
    add hl, bc
    ld d,[hl] ; X position
    ld hl,PlayerShotsY
    add hl, bc      
    ld e,[hl] ; Y position

.update_shot_sprite:

    push bc ; save index counter

    ; Get shadow OAM pointer
    ld a,[PlayerShotsSpritesPtr]
    ld l,a
    ld a,[PlayerShotsSpritesPtr+1]
    ld h,a
    ; calculate OAM entry offset
    sla c
    sla c    ; bc = index * 4
    add hl, bc
    ; Write Y position
    ld [hl], e
    inc l
    ; Write X position
    ld [hl], d
    inc l
    ; Write  Tile Number (assuming tile number 0x02 for shots)
    ; TODO: Move this to init method
    ld [hl], 0x02
    
    pop bc ; restore index counter



    inc c
    ld a, c
    cp MAX_PLAYER_SHOTS
    jr c, .next_shot_draw
    
    ret

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
