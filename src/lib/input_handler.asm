INCLUDE "hardware.inc"

SECTION "Input handler variables", WRAM0


def BUTTON_LEFT = 1
def BUTTON_RIGHT = 2
def BUTTON_UP = 4
def BUTTON_DOWN = 8
def BUTTON_A = 16
def BUTTON_B = 32
def BUTTON_START = 64
def BUTTON_SELECT = 128

export BUTTON_A
export BUTTON_B
export BUTTON_START
export BUTTON_SELECT        
export BUTTON_UP
export BUTTON_DOWN
export BUTTON_LEFT
export BUTTON_RIGHT
export InputHandlerInit
export InputHandlerUpdate

export button_left_was_pressed_flag
export button_left_is_down_flag
export button_left_was_released_flag
export button_right_was_pressed_flag
export button_right_is_down_flag
export button_right_was_released_flag
export button_up_was_pressed_flag
export button_up_is_down_flag
export button_up_was_released_flag
export button_down_was_pressed_flag
export button_down_is_down_flag
export button_down_was_released_flag
export button_a_was_pressed_flag
export button_a_is_down_flag
export button_a_was_released_flag
export button_b_was_pressed_flag
export button_b_is_down_flag    
export button_b_was_released_flag
export button_start_was_pressed_flag
export button_start_is_down_flag
export button_start_was_released_flag
export button_select_was_pressed_flag
export button_select_is_down_flag
export button_select_was_released_flag

input_flags:

button_left_was_pressed_flag: db
button_left_is_down_flag: db
button_left_was_released_flag: db

button_right_was_pressed_flag: db
button_right_is_down_flag: db
button_right_was_released_flag: db

button_up_was_pressed_flag: db
button_up_is_down_flag: db
button_up_was_released_flag: db

button_down_was_pressed_flag: db
button_down_is_down_flag: db	
button_down_was_released_flag: db

button_a_was_pressed_flag: db
button_a_is_down_flag: db
button_a_was_released_flag: db

button_b_was_pressed_flag: db
button_b_is_down_flag: db
button_b_was_released_flag: db

button_start_was_pressed_flag: db
button_start_is_down_flag: db
button_start_was_released_flag: db

button_select_was_pressed_flag: db
button_select_is_down_flag: db
button_select_was_released_flag: db

SECTION "Input Handler routines", ROM0

; =========================================================================================
; Initialize input handler
; =========================================================================================

InputHandlerInit:
	; Reset input flags
	xor a
	ld hl,input_flags
    ld c,24
.clear_flags_loop:
	ld [hli], a
    dec c
    jr nz, .clear_flags_loop
    
    ret 

; =========================================================================================
;
; Update input handler
;
; =========================================================================================
; Polls input data from joypad register and calls event handlers as needed: 
;
; ButtonWasPressed
; ButtonIsDown
; ButtonWasReleased
;
; Handlers receive the button identifier in register A. 
; identifiers are defined as:
;
; BUTTON_LEFT   = 1
; BUTTON_RIGHT  = 2
; BUTTON_UP     = 4
; BUTTON_DOWN   = 8
; BUTTON_A      = 16
; BUTTON_B      = 32
; BUTTON_START  = 64
; BUTTON_SELECT = 128
;
; NOTE: All three methods needs to be declared as EXPORTs somewhere in the codebase, for input handler to be able to call them.
;
;; =========================================================================================
InputHandlerUpdate:

    ; Get input
	ld a,JOYP_GET_DPAD
	ld [rJOYP],a ; read joypad state
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	cpl ; invert bits (so pressed = 1)
	and 0x0F ; mask to only D-Pad bits
	ld b,a ; store input in B

	; Check right button

	; checked scenarios:
	; X no press (no flags af)
	; - new press (set pressed flag, set is_down flag)
	; - held press (clear pressed flag)
	; - released (clear is_down flag, clear pressed flag, set released flag)

	ld a,0
	ld hl,button_right_was_released_flag
	ld [hl], a ; clear released flag at start of check
	ld hl,button_left_was_released_flag
	ld [hl], a ; clear released flag at start of check
	ld hl,button_up_was_released_flag
	ld [hl], a ; clear released flag at start of check
	ld hl,button_down_was_released_flag
	ld [hl], a ; clear released flag at start of check
	

; ----------------------------------
; Check RIGHT button
; ----------------------------------

.button_right_check:

	ld a,b ; load current input
	cp JOYPF_RIGHT
	jr z,.button_right_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_right_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_right_check_done ; button was not previously pressed, skip released event
	; right was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_right_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_right_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_RIGHT
	call ButtonWasReleased

	jp .button_right_check_done

.button_right_is_down:

	ld hl,button_right_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_right_was_already_pressed
	; right was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_right_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_RIGHT
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_right_check_done
	
.button_right_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_right_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_RIGHT
	call ButtonIsDown

.button_right_check_done:

; ----------------------------------
; Check left button
; ----------------------------------

.button_left_check:

	ld a,b ; load current input
	cp JOYPF_LEFT
	jr z,.button_left_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_left_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_left_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_left_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_left_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_LEFT
	call ButtonWasReleased

	jp .button_left_check_done

.button_left_is_down:

	ld hl,button_left_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_left_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_left_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_LEFT
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_left_check_done
	
.button_left_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_left_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_LEFT
	call ButtonIsDown

.button_left_check_done:


; ----------------------------------
; Check DOWN button
; ----------------------------------

.button_down_check:

	ld a,b ; load current input
	cp JOYPF_DOWN
	jr z,.button_down_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_down_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_down_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_down_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_down_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_DOWN
	call ButtonWasReleased

	jp .button_down_check_done

.button_down_is_down:

	ld hl,button_down_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_down_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_down_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_DOWN
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_down_check_done
	
.button_down_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_down_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_DOWN
	call ButtonIsDown

.button_down_check_done:


; ----------------------------------
; Check UP button
; ----------------------------------

.button_up_check:

	ld a,b ; load current input
	cp JOYPF_UP
	jr z,.button_up_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_up_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_up_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_up_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_up_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_UP
	call ButtonWasReleased

	jp .button_up_check_done

.button_up_is_down:

	ld hl,button_up_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_up_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_up_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_UP
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_up_check_done
	
.button_up_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_up_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_UP
	call ButtonIsDown

.button_up_check_done:


; ----------------------------------
; Check A button
; ----------------------------------

.button_a_check:

	ld a,b ; load current input
	cp JOYPF_A
	jr z,.button_a_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_a_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_a_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_a_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_a_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_A
	call ButtonWasReleased

	jp .button_a_check_done

.button_a_is_down:

	ld hl,button_a_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_a_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_a_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_A
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_a_check_done
	
.button_a_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_a_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_A
	call ButtonIsDown

.button_a_check_done:

; ----------------------------------
; Check B button
; ----------------------------------

.button_b_check:

	ld a,b ; load current input
	cp JOYPF_B
	jr z,.button_b_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_b_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_b_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_b_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_b_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_B
	call ButtonWasReleased

	jp .button_b_check_done

.button_b_is_down:

	ld hl,button_b_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_b_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_b_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_DOWN
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_b_check_done
	
.button_b_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_b_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_B
	call ButtonIsDown

.button_b_check_done:

; ----------------------------------
; Check START button
; ----------------------------------

.button_start_check:

	ld a,b ; load current input
	cp JOYPF_START
	jr z,.button_start_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_start_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_start_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_start_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_start_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_START
	call ButtonWasReleased

	jp .button_start_check_done

.button_start_is_down:

	ld hl,button_start_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_start_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_start_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_START
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_start_check_done
	
.button_start_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_start_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_START
	call ButtonIsDown

.button_start_check_done:


; ----------------------------------
; Check SELECT button
; ----------------------------------

.button_select_check:

	ld a,b ; load current input
	cp JOYPF_SELECT
	jr z,.button_select_is_down
	; button is not pressed... was it previously pressed?
	ld hl,button_select_is_down_flag
	ld a, [hl]
	cp 1
	jr nz,.button_select_check_done ; button was not previously pressed, skip released event
	; button was previously pressed...
	ld a,0 
	ld [hl], a                            ; Reset is_down flag
	ld hl,button_select_was_pressed_flag
	ld [hl], a                            ; Reset pressed flag
	ld a, 1
	ld hl,button_select_was_released_flag  ; Set released flag
	ld [hl], a
	ld a,BUTTON_SELECT
	call ButtonWasReleased

	jp .button_select_check_done

.button_select_is_down:

	ld hl,button_select_is_down_flag
	ld a, [hl]
	cp 1
	jr z,.button_select_was_already_pressed
	; button was not previously pressed, now is pressed, set flag
	ld a,1
	ld [hl],a ; set is_down flag
	ld hl,button_select_was_pressed_flag
	ld [hl], a ; set pressed flag
	; call any press event handlers here
	ld a,BUTTON_START
	call ButtonWasPressed 
	call ButtonIsDown
	jp .button_select_check_done
	
.button_select_was_already_pressed:

	; clear pressed flag, as it is not a new press
	ld hl,button_select_was_pressed_flag
	ld a,0
	ld [hl],a

	ld a,BUTTON_START
	call ButtonIsDown

.button_select_check_done:

jr .done_handling_input

.done_handling_input:

	ret