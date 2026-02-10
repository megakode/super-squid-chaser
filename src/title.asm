INCLUDE "hardware.inc"

SECTION	"VBlank Handler",ROM0[$40]

VBlankHandler::	; 40 cycles
    call VBlank
    reti


SECTION	"HBlank Handler",ROM0[$48]
HBlankHandler::	; 40 cycles
	push	af		    ; 4


	ldh	a,[rLY]		    ; 3
    cp 70              ; 2
    jr nz, .check_line_0 ; 3

    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BG9800 | LCDCF_BLK21
    ld [rLCDC], a


.check_line_0:

    cp 143             ; 2
    jr nz, .done       ; 3

    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BG9800 | LCDCF_BLK01
    ld [rLCDC], a

.done


	pop	af		; 3
	reti	

SECTION "Title screen assets", ROM0

VBlank:
    push af
    push bc
    push de
    push hl

    ; call hUGE_dosound

    pop	hl
    pop	de
    pop	bc
    pop	af
    ret


TitleScreenTiles:
    INCBIN "assets/title.2bpp"
TitleScreenTilesEnd:
def TitleScreenTilesLen = TitleScreenTilesEnd - TitleScreenTiles


export ShowTitleScreen
ShowTitleScreen:

    ; enable sound
	; ld a, $80
	; ld [rAUDENA], a
	; ld a, $FF
	; ld [rAUDTERM], a
	; ld a, $77
	; ld [rAUDVOL], a

	; ld hl,song_title
	; call hUGE_init


    call ScreenOff

    ; ld a, `11100100
    ld a, `01000011
	ld [rBGP], a

    ld hl,TitleScreenTiles

    ; Copy BG tile data to VRAM $9000

	ld de, TitleScreenTiles
	ld hl, $8000
	ld bc, TitleScreenTilesLen
	call Memcopy

    ; setup map with title screen layout (tiles 0-255)\
    ld hl, $9800
    ld d,0 ; tile id
    ld b,0 ; Y
    ld c,0 ; X


.loop_x
    ld [hl], d
    inc d   ; tile id
    inc hl  ; dst
    inc c   ; X

    ld a,c
    cp 20
    jr nz, .loop_x

.loop_y
    inc b   ; Y
    ld c,0  ; X

    push de
    ld de,12
    add hl,de
    pop de

    ld a,b
    cp 18
    jr nz, .loop_x


    ; Setup LCD STAT register for HBlank interrupts
    ld a,STATF_MODE00
    ld [rSTAT], a

	; enable the interrupts
	ld	a,IEF_STAT | IEF_VBLANK
	ldh	[rIE],a
	xor	a
	ei
	ldh	[rIF],a

    ; configure and turn on LCD
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BG9800 | LCDCF_BLK01
    ld [rLCDC], a


.loop:

    call WaitVBlank
    ; call hUGE_dosound
    call InputHandlerUpdate

    ld a,[button_start_was_pressed_flag]
    cp 1
    jr nz, .loop

    di 

    ; Mute all channels to stop music/sound effects immediately
    ; ld b,0
    ; ld c,1
    ; CALL hUGE_mute_channel
    ; ld b,1
    ; ld c,1
    ; CALL hUGE_mute_channel
    ; ld b,2
    ; ld c,1
    ; CALL hUGE_mute_channel
    ; ld b,3
    ; ld c,1
    ; CALL hUGE_mute_channel

    ld a,0
    ld [rSTAT], a ; disable LCD interrupts

    ld a,0
    ldh	[rIE],a

    ret