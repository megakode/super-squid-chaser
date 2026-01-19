INCLUDE "hardware.inc"

SECTION "TileAnim variables", WRAM0

def AnimationStateInactive      equ 0
def AnimationStatePlayLooped    equ 1
def AnimationStatePlayOnce      equ 2
def AnimationStatePlayAndRemove equ 3

export AnimationStateInactive
export AnimationStatePlayLooped
export AnimationStatePlayOnce
export AnimationStatePlayAndRemove

def SizeOfTileAnimation	   equ 8 ; size of each sprite animation entry in bytes
def MAX_TILE_ANIMATIONS       equ 40 ; maximum number of simultaneous tile animations

TileAnimations:

	; Tile animation entry format:
	; 8 bytes each: 

	; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 1 current remaining delay (counts down)
	; 2 delay between frames (in game loops)
	; 3 curent frame,
	; 4 number of total frames
	; 5 tile data index ; index of the first tile in the animation sequence
	; 6 tile map offset (low byte), offset into the TileMap where the tile to animate is located
	; 7 tile map offset (high byte)

	ds MAX_TILE_ANIMATIONS * SizeOfTileAnimation

    ; Base address of the tile map being animated (can be anywhere in WRAM or VRAM)
    ; The "tile address" stored in each TileAnimation entry is an offset into this base address.
TileMapAddress:
    ds 2


SECTION "TileAnim routines", ROM0

EXPORT TileAnimationsInit
EXPORT TileAnimationFindByState
EXPORT TileAnimationAdd
EXPORT TileAnimationsUpdate

; -----------------------------
; Initialize Tile Animations
; Set all TileAnimation states to zero
; inputs:
; - HL = pointer to tile map base address (TileMapAddress)
; -----------------------------
TileAnimationsInit:


	push bc
	push af

    ld a, l
    ld [TileMapAddress], a
    ld a,h
    ld [TileMapAddress + 1], a

	ld hl, TileAnimations
	ld bc, MAX_TILE_ANIMATIONS * SizeOfTileAnimation ; 40 sprite animations, 8 bytes each
	.clearTileAnimLoop
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or a, c
	jp nz, .clearTileAnimLoop

	pop af
	pop bc

	ret

; -----------------------------
; Find TileAnimation with a given state
; Inputs:
; B = desired state to find (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove )
; Returns:
; HL = ptr to free slot in TileAnimations, or 0 if none available
; -----------------------------

TileAnimationFindByState:

	push bc
	push af
	push de

	ld hl, TileAnimations
	ld c, MAX_TILE_ANIMATIONS ; total number of entries
	ld de,SizeOfTileAnimation ; size of each sprite animation entry

	.findFreeSpriteLoop
	ld a, [hl]                 ; Get state byte of current entry
	cp b					   ; Does it match the state we are searching for?	
	jr z, .done                ; If yes: we are done!
	add hl, de                 ; increase pointer to next sprite entry
	dec c                      ; decrease loop counter
	ld a, c 
	cp 0                       ; have we checked all entries (counted down to zero)?
	jr nz, .findFreeSpriteLoop ; if not, continue searching
	
	ld hl,0 ; no free sprites available. Return 0

	.done
	; hl now points to the state byte of the free sprite

	pop de
	pop af
	pop bc

	ret

; ======================================================================
; Find Tile Animation by tile map index
;
; Inputs:
; de = tile map index (0-4095) of the tile to animate
; Returns:
; HL = ptr to tile animation entry in TileAnimations
; Carry flag set if found, reset if not found
; ======================================================================
export TileAnimationFindByTileMapIndex
TileAnimationFindByTileMapIndex:

	; TODO : implement this function, its garbage right now

	push bc
	
	ld hl, TileAnimations
	
	ld b,0
	ld c, MAX_TILE_ANIMATIONS ; total number of entries

	
.findAnimationLoop

	ld a,[hl]				; get state byte
	inc hl
	inc hl
	inc hl
	inc hl
	inc hl
	inc hl ; point to tile map offset low byte
	cp 0 				    ; is the state in 'a' inactive?
	jr z, .nextAnimationAddOneToHL    ; if yes, skip to next animation
	
	
	ld a, [hl]                ; get tile map offset low byte
	cp a, e
	inc hl
	jr nz, .nextAnimation
	ld a, [hl]				  ; get tile map offset high byte
	cp a, d
	jr nz, .nextAnimation

	; found it!

	ld bc, -7
	add hl, bc ; point back to state byte of found animation
	scf 
	jp .done
	
.nextAnimationAddOneToHL
	inc hl

.nextAnimation

	dec c
	inc hl
	ld a,c
	cp 0
	jr nz, .findAnimationLoop

	; no more entries = not found

	ld hl,0
	scf 
	ccf ; clear carry to indicate not found

	.done

		pop bc

	ret

; ======================================================================
; Add Tile Animation
; ======================================================================
; Add a tile animation to the TileAnimations array
;
; Tile definitions
; Format:
; 0: Tile data index (starting tile number in VRAM)
; 1: Number of frames
; 2: delay between frames (in game loops)
; 3: reserved (set to 0)

; Inputs:

; b = Play mode (1 = play_looped, 2 = play_once, 3 = play_and_remove)
; de = pointer to source sprite definition (4 bytes)
; hl = tile map index (0-4095) of the tile to animate. The base address if added later in the TileAnimationsUpdate routine.
; Returns:
; None

; ======================================================================
TileAnimationAdd:

	push bc
    
    push hl ; save hl (points to memory location to animate)

	ld c,b ; save play mode in C

	ld b,AnimationStateInactive
	call TileAnimationFindByState ; return hl = pointer to free slot in TileAnimations

	; todo : check if hl = 0 (no free slot)

	ld [hl], c  ; set state
	ld b, a

	; Tile animation entry format:
    ; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 1 current remaining delay (counts down)
	; 2 delay between frames (in game loops)
	; 3 current frame,
	; 4 number of total frames
	; 5 tile data index ; index of the first tile in the animation sequence
	; 6 tile address (low byte), (index of the GB OAM sprite to animate)
	; 7 tile address (high byte)
	
	inc hl     ; hl = &animation.remaining_delay
	inc de
	inc de     ; de = &sprite_definition.delay_between_frames
	ld a,[de]  ; a =  *de
	ld [hl], a ; set current remaining delay in sprite animation entry
	inc hl     ; point to delay between frames in animation entry
	ld [hl], a ; set delay between frames in animation entry
	
	inc hl ; point to current frame in animation entry
	ld a, 0
	ld [hl], a ; set current frame to 0
	
	inc hl     ; point to total frames in animation entry
	dec de     ; point back to total frames in sprite definition
	ld a,[de]  ; get total frames from sprite definition
	ld [hl], a ; set total frames in animation entry

	dec de     ; point back to tile data index in sprite definition
	ld a,[de]  ; get tile data index from sprite definition
	inc hl	 ; point to tile data index in animation entry
	ld [hl], a ; set tile data index in animation entry

	pop de ; restore pointer to memory location to animate
	
    inc hl     ; point to tile address (low byte) in animation entry
	ld [hl], e ; set tile address (low byte) in animation entry
    inc hl
    ld [hl], d ; set tile address (high byte) in animation entry

	pop bc

	ret 

; -----------------------------
; Update Tile Animations
; Update all active tile animations
; -----------------------------

TileAnimationsUpdate:
	push af
	push bc
	push de
	push hl

	ld hl, TileAnimations
	ld c, MAX_TILE_ANIMATIONS   ; total number of entries

.nextAnimationLoop
	ld a, [hl]                  ; Get state byte of current entry
	ld b,a 						; save state in B
	
	cp 0					    ; IS the current animation inactive?
	jr z, .skipCurrentAnimation ; If yes: skip it

	; Active animation - process it

	; get current delay
	; decrement current remaining delay
	; compare to zero
	; if not zero: skip to next animation
	; set current remaining delay to delay between frames
	; get current frame
	; increment frame
	; compare to total frames
	; if less than total frames: {
	;    increment current frame 
	; } else {
	;    if play_looped: {
	;        set current frame to 0
	;    } else if play_once: {
	;        set state to inactive
	;    } else if play_and_remove: {
	;        hide sprite
	;        set state to inactive
	;    }
	; }
	; calculate new tile number: tile data index + current frame
	; update tile number in Shadow OAM

	inc hl; skip 1 bytes ahead to current remaining delay
	ld a, [hl]                  ; Get current delay
	dec a                       ; Decrease delay
	ld [hl], a                  ; Store updated delay
	cp 0 					    ; Has the delay reached zero?
	jr nz, .skipCurrentAnimationSub1 ; If not, skip to next animation (skip 3 bytes back to state)

	; delay has reached zero - set it to delay between frames
	inc hl                      ; skip 1 byte ahead to delay between frames
	ld a, [hl]                  ; Get delay between frames
	dec hl                      ; skip back to current delay
	ld [hl], a                  ; set current remaining delay to delay between frames


	inc hl ; 
	inc hl ; point to current_frame
	;ld CurrentFramePtr, hl

	ld a, [hl]                  ; Get current frame
	inc a                       ; Increase current frame
	inc hl					    ; point to total frames
	ld d, [hl]                  ; Get total frames
	cp d                        ; Compare current frame with total frames
	dec hl                      ; point back to current_frame
	jr c, .incrementCurrentFrame; If current frame < total frames, update frame
	; current frame >= total frames

	; state should be in B
	ld a,b
	cp AnimationStatePlayLooped
	jr z, .rewindToFrameZero    ; if play_looped, rewind to frame 0
	cp AnimationStatePlayOnce
	jr z, .setInactive          ; if play_once, set to inactive
	; animation has reached the end

.setInactive:
	ld de,-3
	add hl, de                ; rewind hl back to beginning of current animation entry
	ld a, AnimationStateInactive
	ld [hl], a                ; set state to inactive (rewind hl to state byte)
	jr .currentFrameWasUpdated
	
.rewindToFrameZero:
	ld a,0
	ld [hl], a                  ; Set current frame to 0
	jr .currentFrameWasUpdated
	
.incrementCurrentFrame
	ld a, [hl]                  ; Get current frame
	inc a
	ld [hl], a                  ; Store updated current frame
	
.currentFrameWasUpdated

                                ; hl = pointer to current_frame
	                            ; a = current frame
	inc hl                      ; point to tile data index
	inc hl
	ld b, [hl]                  ; b = tile data index
	add b                       ; a = current_frame + tile_data_index
    ld b,a                      ; b = new tile index number
	
	; Now a is the new tile index number to set in the tile map.
	; Next, get the tile address to update
	inc hl                      ; point to tile address (low byte)
	ld e, [hl]                  ; e = tile address (low byte)
	inc hl                      ; point to tile address (high byte)
    ld d, [hl]                  ; d = tile address (high byte)

    push hl ; save tile animation pointer

    ld a, [TileMapAddress]       ; get base address low byte
    ld l,a
    ld a, [TileMapAddress + 1]   ; get base address high byte
    ld h,a
    add hl,de                    ; hl = full tile address in tile map
    ld [hl],b                    ; update tile number at tile address

    ; mark BG map row as dirty in ShadowTileMapDirtyRows?

    ; first extract row number from tile offset in DE

    ; SRL D shifts D right, moving bit 0 into carry
    ; RR E rotates E right through carry, pulling the bit from D
    srl d
    rr  e

    srl d
    rr  e

    srl d
    rr  e

    srl d
    rr  e

    srl d
    rr  e

    ; DE = DE / 32
    ld a, e
    and `00011111 ; mask to get row index (0-19)

    ; a = dirty row index
    ld hl,ShadowTileMapDirtyRows
    ld d,0
    ld e,a
    add hl,de
    ld [hl], 1 ; mark row as dirty

    pop hl ; restore tile animation pointer

	ld de,-7 ; rewind hl back to beginning of current animation entry
	add hl, de
	jr .skipCurrentAnimation


.skipCurrentAnimationSub1

	dec hl
	
.skipCurrentAnimation
	ld de,SizeOfTileAnimation ; size of each sprite animation entry
	add hl, de                  ; increase pointer to next sprite entry
	dec c                       ; decrease loop counter
	ld a, c 
	cp 0                        ; have we checked all entries (counted down to zero)?
	jr nz, .nextAnimationLoop  ; if not, continue searching
	
	ld hl,0 ; no free sprites available. Return 0

	.done
	; hl now points to the state byte of the free sprite

	pop hl
	pop de
	pop bc
	pop af

	ret