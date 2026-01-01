INCLUDE "hardware.inc"

SECTION "Sprite workspace", WRAM0

def AnimationStateInactive      equ 0
def AnimationStatePlayLooped    equ 1
def AnimationStatePlayOnce      equ 2
def AnimationStatePlayAndRemove equ 3

export AnimationStateInactive
export AnimationStatePlayLooped
export AnimationStatePlayOnce
export AnimationStatePlayAndRemove

def SizeOfSpriteAnimation	   equ 8 ; size of each sprite animation entry in bytes

SpriteAnimations:
	; Sprite animation entry format:
	; 8 bytes each: 
	; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 3 current remaining delay (counts down)
	; 6 delay between frames (in game loops)
	; 2 curent frame,
	; 5 number of total frames
	; 4 tile data index 
	; 1 sprite_index, (index of the GB OAM sprite to animate)
	; 7 reserved

	ds 40 * SizeOfSpriteAnimation


SECTION "Sprite routines", ROM0

EXPORT SpriteSetPosition
EXPORT SpritesClear
EXPORT SpriteHide

EXPORT SetupDMACopy
EXPORT ExecuteDMACopy

EXPORT SpriteAnimationsInit
EXPORT SpriteAnimationAdd
EXPORT SpriteAnimationsUpdate
EXPORT SpriteAnimationFindByState
EXPORT SpriteAnimationFindBySpriteIndex

; -----------------------------
; Initialize Sprite Animations
; Set all SpriteAnimation states to zero
; -----------------------------
SpriteAnimationsInit:

	push hl
	push bc
	push af

	ld hl, SpriteAnimations
	ld bc, 40 * SizeOfSpriteAnimation ; 40 sprite animations, 8 bytes each
	.clearSpriteAnimLoop
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or a, c
	jp nz, .clearSpriteAnimLoop

	pop af
	pop bc
	pop hl

	ret

; -------------------------------------------------------
; Find SpriteAnimation with a given sprite index
; -------------------------------------------------------
; Inputs:
; B = desired sprite index to find
; Returns:
; HL = ptr to sprite animation entry, or 0 if none found
; -------------------------------------------------------

SpriteAnimationFindBySpriteIndex:

	push af
	push bc
	push de

	ld hl, SpriteAnimations
	ld c, 40                 ; total number of entries
.findSpriteLoop
	ld de,6
	add hl, de               ; point to sprite index byte
	ld a, [hl]               ; Get sprite index byte of current entry
	cp b					 ; Does it match the sprite index we are searching for?
	jr z, .foundIt           ; If yes: we are done!
	inc hl
	inc hl                   ; point to next entry
	dec c
	ld a, c
	cp 0                     ; have we checked all entries (counted down to zero)?
	jr nz, .findSpriteLoop   ; if not, continue searching
	ld hl,0 ; no free sprites available. Return 0

.foundIt

	ld de,-6
	add hl, de                ; point back to the state byte of the found sprite animation

	pop de
	pop bc
	pop af

	ret

	; -----------------------------
; Find SpriteAnimation with a given state
; Inputs:
; B = desired state to find (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove )
; Returns:
; HL = ptr to free slot in SpriteAnimations, or 0 if none available
; -----------------------------

SpriteAnimationFindByState:

	push bc
	push af
	push de

	ld hl, SpriteAnimations
	ld c, 40 ; total number of entries
	ld de,SizeOfSpriteAnimation ; size of each sprite animation entry

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
; Add Sprite Animation
; ======================================================================
; Add a sprite animation to the SpriteAnimations array
;
; Sprite definitions
; Format:
; 0: Tile data index (starting tile number in VRAM)
; 1: Number of frames
; 2: delay between frames (in game loops)
; 3: reserved (set to 0)

; Inputs:
; a = OAM sprite index to animate
; b = Play mode (1 = play_looped, 2 = play_once, 3 = play_and_remove)
; de = pointer to source sprite definition (4 bytes)
; Returns:
; hl = pointer to the sprite animation entry created

; ======================================================================
SpriteAnimationAdd:

	push bc

	ld c,b ; save play mode in C

	ld b,AnimationStateInactive
	call SpriteAnimationFindByState ; return hl = pointer to free slot in SpriteAnimations

	push hl


	; todo : check if hl = 0 (no free slot)

	ld [hl], c  ; set state
	ld b, a

	; Sprite animation entry format:
	; 8 bytes each: 
	; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 3 current remaining delay (counts down)
	; 6 delay between frames (in game loops)
	; 2 curent frame,
	; 5 number of total frames
	; 4 tile data index (index of frame 0 in VRAM, does not change during animation, instead the current frame is added to it and set on the shadow OAM entry)
	; 1 sprite_index, (index of the GB OAM sprite to animate)
	; 7 reserved

	
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

	; set remaining delay
	; inc de
	; inc de     ; point to delay byte in sprite definition
	; ld a,[de]  ; get delay value from sprite definition
	; ld [hl], a ; set delay value in animation entry
	; dec de
	; dec de     ; point back to start of sprite definition
	; inc hl

	inc hl     ; point to sprite index in animation entry
	ld [hl], b ; set sprite index in animation entry

	pop hl ; restore hl to point to state byte of the sprite animation entry
	pop bc

	ret 

; -----------------------------
; Update Sprite Animations
; Update all active sprite animations
; -----------------------------



SpriteAnimationsUpdate:
	push af
	push bc
	push de
	push hl

	ld hl, SpriteAnimations
	ld c, 40 ; total number of entries

.nextSpriteLoop
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
	cp AnimationStatePlayAndRemove
	jr z, .hideSpriteAndSetInactive ; if play_and_remove, hide sprite and set to inactive
	; animation has reached the end

.hideSpriteAndSetInactive

	; TODO: hide sprite

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

	                            ; a = current frame
	inc hl                      ; point to tile data index
	inc hl
	ld b, [hl]                  ; b = tile data index
	
	add b                       ; a = tile_data_index + current_frame
	
	; Now a is the new tile number to set on the sprite.
	; Next, get the sprite index and set the tile number in shadow OAM
	inc hl                      ; point to sprite index
	ld e, [hl]                  ; c = sprite index
	sla e                       ; multiply by 4 (size of each oam sprite entry)
	sla e

	push hl					; save hl (points to sprite index byte in animation entry)

	ld hl, ShadowOAMData
	ld d,0
	add hl, de                  ; point to sprite entry in shadow OAM
	inc hl					    
	inc hl                      ; point to tile number byte in OAM entry
	ld [hl], a                  ; set new tile number in shadow OAM

	pop hl						; restore hl

	ld de,-7 ; rewind hl back to beginning of current animation entry
	add hl, de
	jr .skipCurrentAnimation


.skipCurrentAnimationSub1

	dec hl
	
.skipCurrentAnimation
	ld de,SizeOfSpriteAnimation ; size of each sprite animation entry
	add hl, de                  ; increase pointer to next sprite entry
	dec c                       ; decrease loop counter
	ld a, c 
	cp 0                        ; have we checked all entries (counted down to zero)?
	jr nz, .nextSpriteLoop  ; if not, continue searching
	
	ld hl,0 ; no free sprites available. Return 0

	.done
	; hl now points to the state byte of the free sprite

	pop hl
	pop de
	pop bc
	pop af

	ret


; -----------------------------
; Set Sprite Position
;
; A = spriteNum, D = xPos, E = yPos

; -----------------------------
SpriteSetPosition:
	; multiply by 4 (size of each sprite entry)
	push hl
	push bc

	sla a
	sla a
	ld hl, ShadowOAMData

	xor b ; BC = A
	ld c, a
	
	add hl, bc ; point to sprite entry
	ld a, e ; Y position
	ld [hl], a
	inc hl
	ld a, d ; X position
	ld [hl], a

	pop bc
	pop hl
	
	ret


; -----------------------------
; Clear Sprites
;
; Set all OAM data to 0
; -----------------------------

SpritesClear:

	push hl
	push bc
	push af

	ld hl, ShadowOAMData
	ld bc, 4 * 40 ; 40 sprites, 4 bytes each
	.clearSpriteLoop
	xor a
	ld [hli], a
	dec bc
	ld a, b
	or a, c
	jp nz, .clearSpriteLoop

	pop af
	pop bc
	pop hl

	ret

; -----------------------------
; Hide Sprite 
;
; A = spriteNum
;
; Hide a sprite by setting its Y position to 0
; -----------------------------

SpriteHide:

    push hl 
    push bc
    
	sla a ; multiply by 4 (size of each sprite entry)
	sla a
	ld hl, ShadowOAMData

	xor b ; BC = A
	ld c, a

	add hl, bc ; point to sprite entry
	ld a, 0 ; Y = 0 (out of screen)
	ld [hl], a

    pop bc
    pop hl

    ret


; -----------------------------
; Sprite DMA Transfer
; -----------------------------
;
; Copy the DMARoutine to HRAM, which is the only place we can safely run code during a DMA transfer
;
; Call this once during initialization

SetupDMACopy:

	push hl
	push bc
	push af

	ld  hl, ROM_ExecuteDMACopy
	ld  b, ROM_ExecuteDMACopyEnd - ROM_ExecuteDMACopy ; Number of bytes to copy
	ld  c, LOW(ExecuteDMACopy) ; Low byte of the destination address

.copy

	ld  a, [hli]
	ldh [c], a
	inc c
	dec b
	jr  nz, .copy

	pop af
	pop bc
	pop hl

	ret

; This routine is copied to HRAM and does the following:
; - Starts a DMA transfer of OAM shadow ram
; - Waits 160us before returning, to ensure the DMA transfer is complete

ROM_ExecuteDMACopy:
	di
	ldh [rDMA], a
	ld  a, 40
.wait
	dec a
	jr  nz, .wait
	ei
	ret
ROM_ExecuteDMACopyEnd:

SECTION "OAM DMA", HRAM

; --------------------------------
; Execute DMA Copy
; 
; Calls the DMA routine copied to HRAM
; A = HIGH(ShadowOAMData)
; --------------------------------

ExecuteDMACopy::
	ds (ROM_ExecuteDMACopyEnd - ROM_ExecuteDMACopy) ; Reserve space to copy the routine to
  