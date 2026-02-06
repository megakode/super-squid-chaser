
; *** Player movement ****************

def PLAYER_THRUST = 2
def PLAYER_DEACCELERATION = 1
export PLAYER_THRUST
export PLAYER_DEACCELERATION

; *** Pickups *************************

def PICKUP_AMMO_AMOUNT = 10

; *** Enemies *************************

def MAX_ENEMIES = 1
def ENEMIES_SPEED = 2
export MAX_ENEMIES
export ENEMIES_SPEED

; Mines ****************************

def MAX_MINES = 5
def MINE_TRIGGER_RADIUS = 4

def MINE_COUNTDOWN_AMOUNT = 40 ; Frames until mine explodes after triggered
export MINE_COUNTDOWN_AMOUNT

export PLAYER_EXPLOSION_DAMAGE
def PLAYER_EXPLOSION_DAMAGE = 1

; *** Game settings ********************

def FRAMES_BETWEEN_SCROLL = 2
export FRAMES_BETWEEN_SCROLL

def DEFAULT_HEALTH_VALUE = 1
def DEFAULT_AMMO_VALUE = 10
def DEFAULT_SCORE_VALUE = 0

export DEFAULT_SCORE_VALUE
export DEFAULT_AMMO_VALUE
export DEFAULT_HEALTH_VALUE