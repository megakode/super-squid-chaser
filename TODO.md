# TODO

Statusbar

- [x] GFX: Statusbar tiles
- [x] GFX: draw numbers for statusbar
- [x] draw statusbar window
- [x] draw numbers


====================================================================
Space miner draft
====================================================================

Objective:

Collect enough ore to repair your mothership, and progress to next level.

Turns:

Each turn consists of the following phases:

- Player movement / mining / combat
- Enemy movement

On each turn the player has X movement points. 
Movement points can be used for:

- moving around the map
- mining ore from an asteroid
- Fighting enemies

Moving around

While moving around the map, always make sure to end your turn within range of a nearby beacon. Ending a turn within the dark void, will result in loosing the game.

Mining ore

Mined ore from asteroids can be used to craft items:

1 x Ore -> 1 x Ammo
3 x Ore -> 1 x Beacon


Beacons

Beacons are vital for navigating in space. Always make sure to end your turn within range of one. Your ship can navigate outside beacon range, but it is a calculated risk, and when you run out of movement points, you either have to had build a new beacon, or navigate back within an existing beacons range.

New beacons can be crafted by mining ore.

Enemies

You will encounter enemies throughout your journey. These can be fought by navigating the ship onto the square they occupy, and thus using ammo for a space combat.