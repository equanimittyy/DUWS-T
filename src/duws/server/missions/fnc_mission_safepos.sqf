// Locality: any (pure placement query); mission-thread callers are server-side.
//
// Fallback-on-failure placement helper: for an ADDITIONAL placement that must not fail the mission
// (reinforcement spawn, debus point, LZ, convoy road anchor), return clear land near _pos, or _fallback (a
// caller-vetted point) on failure. BIS_fnc_findSafePos returns the map origin ([0,0] or [0,0,0], open sea off
// Altis' SW corner), not [], when it cannot settle -- a bare result seats at sea. Objective siting instead runs
// at offer time (fnc_mission_findSite), which returns [] so the picker drops the type or the thread aborts.
//
// [_pos, _radius, _minDist, _objDist, _grad, _fallback] -> land pos | _fallback
params ["_pos", ["_radius", 200], ["_minDist", 0], ["_objDist", 5], ["_grad", 0.5], ["_fallback", []]];
if (_fallback isEqualTo []) then { _fallback = _pos };
private _p = [_pos, _minDist, _radius, _objDist, 0, _grad, 0] call BIS_fnc_findSafePos;
if (_p isEqualTo [] || {(_p select 0) == 0 && {(_p select 1) == 0}} || {surfaceIsWater _p}) exitWith { _fallback };
_p
