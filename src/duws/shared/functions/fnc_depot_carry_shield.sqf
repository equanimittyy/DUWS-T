// Locality: every machine -- lifts the men it owns out of collision with a depot vehicle on the R3F
// carry, for as long as the carry runs (`fnc_depot_place_r3f` owns the flag).
//
// The carried hull is frozen and its damage is shielded, but a frozen body still has geometry: swept
// through a soldier it throws him off his feet. `disableCollisionWith` is machine-local and the shove
// resolves where the *unit* lives, so the sweep runs everywhere and filters to local men.
params ["_vehNet", "_carrierNet"];
private _veh = objectFromNetId _vehNet;
private _carrier = objectFromNetId _carrierNet;
if (isNull _veh || {isNull _carrier}) exitWith {};

private _shielded = [];
// A carrier who disconnects mid-carry never clears the flag, so his player object is the second exit.
while { !isNull _veh && {!isNull _carrier} && {_veh getVariable ["DUWS_depot_placing", false]} } do {
    {
        if !(_x in _shielded) then {
            _x disableCollisionWith _veh;
            _shielded pushBack _x;
        };
    } forEach ((_veh nearEntities ["CAManBase", 50]) select {local _x});
    sleep 1;
};

{ if (!isNull _x) then { _x enableCollisionWith _veh }; } forEach _shielded;
