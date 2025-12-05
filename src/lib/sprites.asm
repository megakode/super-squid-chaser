INCLUDE "hardware.inc"

SECTION "Sprite workspace", WRAM0

def AnimationStateInactive      equ 0
def AnimationStatePlayLooped    equ 1
def AnimationStatePlayOnce      equ 2
def AnimationStatePlayAndRemove equ 3

SpriteAnimations:
	; Sprite animation entry format:
	; 8 bytes each: 
	; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 1 sprite_index, (index of the GB OAM sprite to animate)
	; 2 curent frame,
	; 3 current remaining delay (counts down)
	; 4 tile data index (starting tile number in VRAM, 0x8000 + index)
	; 5 number of total frames
	; 6 delay between frames (in game loops)
	; 7 reserved

	ds 40 * 8


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

; -----------------------------
; Initialize Sprite Animations
; Set all SpriteAnimation states to zero
; -----------------------------
SpriteAnimationsInit:

	push hl
	push bc
	push af

	ld hl, SpriteAnimations
	ld bc, 40 * 8 ; 40 sprite animations, 8 bytes each
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
	ld de,8 ; size of each sprite animation entry

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

; -----------------------------
; Add Sprite Animation
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
; de = pointer to source sprite definition (4 bytes)

; -----------------------------
SpriteAnimationAdd:

	ld b,AnimationStateInactive
	call SpriteAnimationFindByState ; return hl = pointer to free slot in SpriteAnimations


	; Sprite animation entry format:
	; 8 bytes each: 
	; 0 state , (0 = inactive, 1 = play_looped, 2 = play_once, 3 = play_and_remove ),
	; 1 sprite_index, (index of the GB OAM sprite to animate)
	; 2 curent frame,
	; 3 current remaining delay (counts down)
	; 4 tile data index 
	; 5 number of total frames
	; 6 delay between frames (in game loops)
	; 7 reserved

	push bc

	ld b, a
	ld a, 1     ; state = play_looped
	ld [hl], a  ; set state
	inc hl
	ld [hl], b  ; set sprite index
	inc hl
	ld a, 0
	ld [hl], a  ; start current frame to 0
	inc hl

	; set remaining delay
	inc de
	inc de     ; point to delay byte in sprite definition
	ld a,[de]  ; get delay value from sprite definition
	ld [hl], a ; set delay value in animation entry
	dec de
	dec de     ; point back to start of sprite definition
	inc hl

	; copy 3 bytes of sprite definition data to animation entry
	ld a,[de]
	ld [hl], a  
	inc de
	inc hl

	ld a,[de]
	ld [hl], a 
	inc de
	inc hl

	ld a,[de]
	ld [hl], a
	inc hl

	pop bc

	ret 

; -----------------------------
; Update Sprite Animations
; Update all active sprite animations
; -----------------------------

SpriteAnimationsUpdate:
	; TODO
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
	ld hl, STARTOF(WRAM0)

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

	ld hl, STARTOF(WRAM0)
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
; Sprite Macros
; ---------------------------
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
	ld hl, STARTOF(WRAM0)

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
	ldh [rDMA], a
	ld  a, 40
.wait
	dec a
	jr  nz, .wait
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
  