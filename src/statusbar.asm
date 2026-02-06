INCLUDE "hardware.inc"

SECTION "Status bar variables", WRAM0

export StatusBarHealthValue
export StatusBarAmmoValue
export StatusBarScoreValue

StatusBarHealthValue: db 
StatusBarAmmoValue: db 
StatusBarScoreValue: db

def TileIndexWithFirstNumber = 0x11 ; Tile index for '0' character

SECTION "Status bar section", ROM0


export StatusbarTileMap
StatusbarTileMap:
	db 0xb,0xf,0xf,0xf,0xd,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xf,0xe,0xf,0x10

export ShowStatusBar
ShowStatusBar:
	; Set window Y position
	ld a, 144-8
	ld [rWY], a
	; Set window X position
	ld a, 7 ; X position is offset by 7
	ld [rWX], a

    ret

; =================================================
; StatusBarSetNumber
; =================================================
;
; Input: 
; A = number to display (0-99)
; E = destination offset in window (dst = $9C00 + E)
; Updates the status bar number display
;
; Assumptions:
; Tile bar map starts at $9C00
; '0' tile is 0x10
; =================================================
export StatusBarSetNumber
StatusBarSetNumber:

    push hl
    push bc
    push de

    ; Calculate tens and ones digits
    call CalculateTensAndOnes
    ; B = tens digit, C = ones digit
    
    ld a,b
    add TileIndexWithFirstNumber ; Convert digit to tile numbers (assuming '0' tile is 0x10)

    ; Set tile STATUSBAR_X + offset to tens digit (a)
    ld d,0
    ld hl, 0x9c00
    add hl, de
    ld [hl], a ; Write to VRAM
    
    inc hl
    
    ld a,c
    add TileIndexWithFirstNumber ; Convert digit to tile numbers (assuming '0' tile is 0x10)
    
    ld [hl], a ; Write to VRAM

    pop de
    pop bc
    pop hl
    
    ret

; =================================================
; StatusBarUpdate
; =================================================
; Input: None
; Updates the status bar display based on current values

export StatusBarUpdate
StatusBarUpdate:
    
    ; Update Movement Value
    
	; ld a,[PlayerHealth]
	; ld e,1 ; offset in status bar
	; call StatusBarSetNumber

    ; update Ammo Value

	ld a,[PlayerShotsLeft]
	ld e,2 ; offset in status bar
	call StatusBarSetNumber

    ; update Gem Value

	ld a,[PlayerScore]
	ld e,15 ; offset in status bar
	call StatusBarSetNumber

    ret