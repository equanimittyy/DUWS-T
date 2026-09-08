// Locality: any (broadcast). Returns a building's openable door animation sources -- the plain door_N
// rotate/user sources, dropping the locked, handle and glass siblings. animationNames reads the model,
// where these sources actually live; the CfgVehicles AnimationSources config does not carry them, so a
// config lookup finds nothing. Empty when the building has no openable door.
//
// Contract: [_building] -> [source names].
params ["_building"];
(animationNames _building) select {
    private _n = toLower _x;
    (_n find "door_" == 0) && {_n find "locked" < 0} && {_n find "handle" < 0}
}
