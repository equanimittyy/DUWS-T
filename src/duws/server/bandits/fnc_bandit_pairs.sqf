// Locality: server. The caller claims the groups for teardown.
//
// Contract: [_pos, _count] -> _groups (two riflemen each, on widepatrol round _pos)
if (!isServer) exitWith { [] };
params ["_pos", "_count"];

// Inside the civilian mission site's 300 m clearance from every zone, so a pair's route stays out of them.
#define PAIR_RADIUS 250

(DUWS_postureBands get "widepatrol") params ["_minF", "_maxF"];
private _groups = [];
for "_i" from 1 to _count do {
    private _at = [_pos, _maxF * PAIR_RADIUS, _minF * PAIR_RADIUS, 5, 0.5] call fnc_safe_pos;
    private _grp = [_at, ["rifleman", "rifleman"]] call fnc_bandit_spawn;
    if (isNull _grp) then { continue };
    [_grp, "widepatrol", _pos, PAIR_RADIUS] call fnc_apply_posture;
    _groups pushBack _grp;
};
_groups
