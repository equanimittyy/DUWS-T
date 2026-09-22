// Locality: server -- a placement query for the ambient random events.
//
// Candidate roads out past _anchor, narrowed to those no nearby player can see. The events used a blind
// selectRandom over nearRoads, so on open ground a car popped in in plain view; the shared line-of-sight
// test (fnc_duws_posSeenBy) keeps the spawn behind cover and it drives into view instead. Never blocks the
// event: falls back to the full set when all are exposed, and to any road when no player is near.
//
// [_anchor] -> array of road objects (empty when no road is within reach)
params ["_anchor"];

private _roads = _anchor nearRoads 500;
// Out from the anchor: the event is come upon, not dropped in the player's lap.
private _far = _roads select { (_anchor distance _x) > 150 };
if !(_far isEqualTo []) then { _roads = _far };
if (_roads isEqualTo []) exitWith { [] };

// Bound the line checks to players near the anchor; a distant one can't see the spawn anyway.
private _players = (call BIS_fnc_listPlayers) select { alive _x && {(_x distance2D _anchor) < 600} };
if (_players isEqualTo []) exitWith { _roads };

// Sample a handful rather than raycast every road by every player -- enough to find cover where it exists.
// Inner _x is the player (findIf rebinds it); _rp is the road point, captured before the rebind.
private _sample = (_roads call BIS_fnc_arrayShuffle) select [0, 16 min (count _roads)];
private _hidden = _sample select {
    private _rp = getPosATL _x;
    (_players findIf { [_rp, _x] call fnc_duws_posSeenBy }) < 0
};
if !(_hidden isEqualTo []) exitWith { _hidden };
_roads
