// Site-finder for Recover Humanitarian Supply Truck. The mission is gated on its destination -- the IDAP crew
// wait in a non-enemy town the truck reaches -- so rather than accept only a dot that happens to have a town in
// reach, it guarantees one: fnc_site_town picks the nearest deliverable town, then the truck snaps onto that
// town's reach ring toward the dot, so it still starts in contested ground. A dot already in reach is kept.
//
// Contract: [_candidatePos] -> [] reject, or [_snappedPos] accept.
params ["_pos"];

#define DELIVER_REACH 3000

private _town = [_pos, 1e9] call fnc_site_town;
if (_town isEqualTo []) exitWith { [] };
private _near = _town select 0;

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
