INCLUDE "hardware.inc"
INCLUDE "config.inc"

SECTION "Enemy variable", WRAM0

EnemyCount:  ds 1              ; Number of active enemies
EnemyX:      ds MAX_ENEMIES    ; X positions of sprite
EnemyY:      ds MAX_ENEMIES    ; Y positions of sprite
EnemyIsActive: ds MAX_ENEMIES  ; Active flags for sprites (1 = active, 0 = inactive)

export EnemySpritesPtr
EnemySpritesPtr: ds 2 ; Pointer to the sprites used in shadow OAM

SECTION "Enemy routines", ROM0

export EnemiesInit
EnemiesInit:
    ; Initialize enemy data
    ld d, h
    ld e, l
    ld hl,EnemySpritesPtr
    ld [hl],e
    inc hl
    ld [hl],d

    ; Set sprite indexes
    ld a,[EnemySpritesPtr]
    ld l,a
    ld a,[EnemySpritesPtr+1]
    ld h,a
    ld c,0
.init_loop:
    ld a, 0
    ld [hl], a ; Set Y
    inc hl
    ld [hl], a ; Set X
    inc hl
    ld [hl], 0x08 ; Set Tile number for sprite
    inc hl
    ld [hl], 0 ; Attributes
    inc hl
    inc c
    ld a,c
    cp MAX_ENEMIES
    jr c, .init_loop

    call ResetEnemies
    ret

; ==========================================
; Check collission between player and enemies
; Assumes PlayerX and PlayerY contain player position
; ==========================================
export CheckPlayerEnemyCollision
CheckPlayerEnemyCollision:

    ld b,0 ; enemy index
    ld c,0xff

.next_enemy_check:

    inc c
    ld a,c
    cp MAX_ENEMIES
    jr z, .done ; If all enemies checked, exit

    ld hl,EnemyIsActive
    add hl, bc
    ld a, [hl]         ; Check if current enemy is active..
    cp 1
    jr nz, .next_enemy_check ; If not, skip

    ; Get enemy position
    ld hl,EnemyY
    add hl, bc
    ld d,[hl] ; D = enemy Y

    ld hl,PlayerY
    ld a,[hl] ; A = player Y
    add 3 ; adjust to hitbox center

    cp d
    jr c, .next_enemy_check ; if player Y < enemy Y, skip

    ld e,a ; E = player Y
    ld a,d ; A = enemy Y
    add 7 ; enemy height
    cp e
    jr c, .next_enemy_check

    ; we hit in Y axis, check X axis

    ld hl,EnemyX
    add hl, bc
    ld d,[hl] ; enemy X

    ld hl,PlayerX
    ld a,[hl] ; A = player X
    add 3 ; adjust to hitbox center

    cp d
    jr c, .next_enemy_check ; if player X < enemy X, skip

    ld e,a ; E = player X
    ld a,d ; A = enemy X
    add 7 ; enemy width
    cp e
    jr c, .next_enemy_check

    ; HIT !!!

    ; input: C - enemy index
    call KillEnemy
    ld hl,PlayerScore
    inc [hl] ; increase player score


.done

    ret

; ==========================================
; Kill enemy
; Input:
; C - enemy index to kill
; ==========================================

export KillEnemy
KillEnemy:

    push hl
    push bc

    ld hl,EnemyIsActive
    ld b,0
    add hl, bc
    ld [hl], 0 ; Mark enemy as inactive
    ld hl,EnemyCount
    dec [hl] ; Decrement enemy count

    pop bc
    pop hl

    ret

; ==========================================
; Reset Enemies
; ==========================================

export ResetEnemies
ResetEnemies:

    ; Initialize all enemies to inactive
    ld hl, EnemyIsActive
    ld c, MAX_ENEMIES
.reset_loop:
    ld [hl], 0          ; Set active flag to 0 (inactive)
    inc hl
    dec c
    jr nz, .reset_loop

    ld hl, EnemyCount
    ld [hl], 0  ; Set enemy count to 0

    ret

; ==========================================
; Spawn enemy if needed
; ==========================================
export SpawnEnemyIfNeeded
SpawnEnemyIfNeeded:

    ld hl,EnemyCount
    ld a,[hl]
    cp MAX_ENEMIES
    jr z, .done ; If max enemies reached, skip spawn

    call GetPseudoRandomByte
	and `111             ; limit to 0-31 tile indices
	; compare A with 10 and jump if less than 10
	cp `111
    jr nz, .done ; 1 in 16 chance to spawn enemy

    call GetPseudoRandomByte
    cp 160 ; limit to screen width
    jr c, .dont_subtract
    sub 160
.dont_subtract
    ld d,a ; D = X position for enemy
    

    ld e, 50  ; Y position (for example purposes)

    call AddEnemy

.done

    ret

; ==========================================
; AddEnemy
;
; Adds a new enemy if there is an available slot
;
; Inputs:
;   D - X position of the sprite
;   E - Y position of the sprite
;
; Outputs:
;   A - 1 if an enemy is added successfully, 0 if no slot available
; ==========================================

export AddEnemy
AddEnemy:

    push bc
    push hl

    ld hl,EnemyCount
    ld a,[hl]
    cp MAX_ENEMIES
    jr z, .no_slot_available

    ; Find an inactive enemy slot
    ld hl, EnemyIsActive
    ld c, 0
.find_slot:
    ld a, [hl]
    cp 0
    jr z, .slot_found
    inc hl
    inc c
    ld a,c
    cp MAX_ENEMIES
    jr c, .find_slot

    ; No available slot, return 0
.no_slot_available:
    ld a,0
    jp .done

.slot_found:
 
    ; C now contains the index of the available slot
    
    ld [hl], 1              ; Mark enemy as active
    ld hl, EnemyX
    ld b,0
    add hl, bc
    ld [hl], d              ; Set X position
    ld hl, EnemyY
    add hl, bc
    ld [hl], e              ; Set Y position

    ld hl,EnemyCount
    inc [hl]               ; Increment enemy count
    ld a,1                 ; Indicate enemy added successfully

.done
    pop hl
    pop bc
    ret

; ==========================================
; UpdateEnemies
; ==========================================

export UpdateEnemies
UpdateEnemies:

    push hl
    push bc
    push de

    ld hl, EnemyCount
    ld a, [hl]
    cp 0
    jr z, .no_enemies ; If no active enemies, skip update

    ld bc,0

.update_loop

    ld hl,EnemyIsActive
    add hl, bc
    ld a, [hl]         ; Check if current enemy is active..
    cp 1
    jr nz, .next_enemy ; If not, skip

    ; ld hl,EnemyX
    ; add hl, bc
    ; ld a, [hl]
    ; sub ENEMIES_SPEED
    ; ld [hl], a ; Update X position

    ld hl,EnemyY
    add hl, bc
    ld a, [hl]
    cp 8                ; Check if enemy is off-screen
    jr nc, .move_enemy
    
.deactivate_enemy:

    ld hl,EnemyIsActive
    add hl, bc
    ld [hl], 0 ; Mark enemy as inactive
    ld hl,EnemyCount
    dec [hl] ; Decrement enemy count
    jp .next_enemy
    
.move_enemy

    sub ENEMIES_SPEED
    ld [hl], a ; Update X position
        
.next_enemy
    
    inc c
    ld hl,EnemyIsActive
    add hl, bc
    ld a,c
    cp MAX_ENEMIES
    jr c, .update_loop

.no_enemies

    pop de
    pop bc
    pop hl

    ret

; ==========================================
; DrawEnemies
; Draws active enemies to shadow OAM (EnemySpritesPtr)
; ==========================================
export DrawEnemies
DrawEnemies:

    ld bc,0 ; number of enemy sprites processed

    .next_enemy_draw:
    
    ; find active enemies
    ld hl,EnemyIsActive
    add hl, bc
    ld a,[hl]
    cp 1
    jr z,.draw_enemy

.hide_enemy:

    ; ld hl,EnemyY
    ; add hl, bc      
    ; ld [hl], 0 ; off-screen Y position
    ld d,0
    ld e,0
    jp .update_enemy_sprite

.draw_enemy:
    ; draw enemy sprite
    ld hl,EnemyX
    add hl, bc
    ld d,[hl] ; X position
    ld hl,EnemyY
    add hl, bc      
    ld e,[hl] ; Y position

.update_enemy_sprite:

    push bc ; save index counter

    ; Get shadow OAM pointer
    ld a,[EnemySpritesPtr]
    ld l,a
    ld a,[EnemySpritesPtr+1]
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
    
    pop bc ; restore index counter



    inc c
    ld a, c
    cp MAX_ENEMIES
    jr c, .next_enemy_draw
    
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
