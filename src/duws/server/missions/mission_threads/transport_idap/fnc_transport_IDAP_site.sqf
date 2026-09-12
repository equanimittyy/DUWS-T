// Site-finder for Recover Humanitarian Supply Truck. The mission is gated on its destination -- the IDAP crew
// wait in a neutral/BLUFOR town the aid truck is driven to -- so rather than accept a dot only when a town
// happens to sit within reach, this guarantees one: it snaps the truck onto the nearest delivery town's reach
// ring, toward the surveyed dot so the truck still sits in contested ground. A dot already within reach is kept.
// No neutral town anywhere means no hand-over point, so reject. Client-side in the picker, so it reads only
// broadcast state: duws_town_circles and DUWS_enemy_town_pos (empty circles -- civilians off -- reject every
// dot). The thread re-derives the nearest such town.
//
// Contract: [_candidatePos] -> [] reject, or [_snappedPos] accept.
params ["_pos"];

#define DELIVER_REACH 3000

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

// Delivery towns = circles whose centre is not in the enemy-band list (an OPFOR-band town is no hand-over
// point); nearest to the dot wins.
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _towns = (_circles select { _x params ["_c", ""]; (_enemyTowns findIf { _x distance2D _c < 5 }) < 0 }) apply { _x select 0 };
if (_towns isEqualTo []) exitWith { [] };
private _near = [_towns, [], { _pos distance2D _x }, "ASCEND"] call BIS_fnc_sortBy select 0;

// Pull an out-of-reach dot onto the 0.9x ring toward it, so the truck sits in contested ground yet a delivery
// town stays within reach for a real but bounded drive.
private _spawn = _pos;
private _gap = _pos distance2D _near;
if (_gap > DELIVER_REACH) then {
    private _dx = (_pos select 0) - (_near select 0);
    private _dy = (_pos select 1) - (_near select 1);
    private _d = DELIVER_REACH * 0.9;
    _spawn = [(_near select 0) + _dx / _gap * _d, (_near select 1) + _dy / _gap * _d, 0];
};
[_spawn]
