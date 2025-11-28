INCLUDE "hardware.inc"

SECTION "Sprite routines", ROM0

EXPORT SpriteSetPosition
EXPORT SpritesClear
EXPORT SpriteHide

EXPORT SetupDMACopy
EXPORT ExecuteDMACopy

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
  