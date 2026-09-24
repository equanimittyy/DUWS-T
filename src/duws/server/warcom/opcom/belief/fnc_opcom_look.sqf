// Locality: server. The arrival look: one guaranteed reveal of the ground a unit stands on, taken when it reaches
// where it was sent. Every BLUFOR group within _k Chebyshev cells is stamped for certain, the reach reads
// swept-clear (fnc_opcom_cover_stamp), and belief the look disproves clears (fnc_opcom_cover_clear).
//
// The reach is the caller's: an interceptor takes OPCOM_INTERCEPT_K, because a hunt has to find a group that moved
// off the fix it was sent to, and a scouting combatant takes 0, its own cell, because a rifle squad is no recon.
//
// It is a recon's sweep bought at one point instead of along a route (fnc_opcom_recon_sense), which is the whole
// difference between a recon and a combatant on the same Scout: the recon updates belief every tick it travels, so
// it is valued on its route, and a combatant sees nothing on the way and is valued on that one cell
// (opcom_plan.md, Value).
//
// -> the netId of the closest group found, or "": an interceptor hunts it, a scout drops it.
if (isNil "DUWS_opcom_grid_w") exitWith { "" };
params ["_point", "_k"];

[_point, _k] call fnc_opcom_cover_stamp;
private _best = "";
private _bd = 1e12;
{
    private _l = [_x] call DUWS_fnc_opcom_sightLead;
    if (!isNull _l) then {
        private _lp = getPosASL _l;
        if (([_lp, _point] call DUWS_fnc_opcom_cellDist) <= _k) then {
            [netId _x, [_lp select 0, _lp select 1, 0], [_x] call DUWS_fnc_opcom_sightStr] call fnc_opcom_belief_upsert;
            private _d = _point distance2D _lp;
            if (_d < _bd) then { _bd = _d; _best = netId _x };
        };
    };
} forEach (allGroups select { side _x == west });
[_point, _k] call fnc_opcom_cover_clear;
_best
