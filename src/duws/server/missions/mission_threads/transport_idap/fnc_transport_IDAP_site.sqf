// Site-finder for Recover Humanitarian Supply Truck. The IDAP crew wait in a neutral or BLUFOR town and
// the recovered aid truck is driven to them, so the offer needs such a town within delivery reach of the
// sited truck. With none, there is nowhere to hand the truck over, so the candidate is rejected and the
// offer dropped rather than sited on a recovery that cannot be completed.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only broadcast
// state: duws_town_circles (town centres + radii, published by fnc_civ_init_Tomata) and DUWS_enemy_town_pos
// (the OPFOR-band town centres, rebuilt and broadcast by fnc_enemy_towns_refresh on every band crossing).
// Civilians off leaves duws_town_circles empty, which rejects every candidate -- a delivery with no towns
// has nowhere to go.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.
params ["_pos"];

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

// A neutral/BLUFOR town is any whose centre is not in the broadcast enemy-town list (rep > -10). Accept
// only when one sits within delivery reach of the truck, so the drive stays a real leg without dragging
// the hand-over across the map; the thread re-derives the nearest such town from the same broadcast state.
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _DELIVER_REACH = 3000;
private _ok = _circles findIf {
    _x params ["_c", ""];
    (_c distance2D _pos <= _DELIVER_REACH) && {(_enemyTowns findIf { _x distance2D _c < 5 }) < 0}
};
if (_ok < 0) exitWith { [] };

[_pos]
