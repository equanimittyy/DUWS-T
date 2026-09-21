// Locality: server -- called by mission threads only, all server-side.
/*
    Tears a finished side mission down: releases its composition to the map cleanup and stamps a
    delete order on everything it claimed. The continuous sweep does the rest, deleting each unit,
    corpse and vehicle once no player is within its keep-radius and the deadline has passed. Nothing
    is deleted here and now, so nothing blinks out in front of a player, and an intel corpse is held
    exactly as long as someone stays near it.

    Reached through fnc_mission_end, which owns the rest of a thread's exit and takes the same
    arguments; call it directly only for a teardown that is not a mission ending.

    _compKey  composition to release, or "" for a mission that owns no built objects.
    _token    which mission instance this is tearing down, from fnc_mission_begin.

    _targetpos, _radius and _sweepFriendly are retained for signature stability across the 27 callers
    but not read: ownership (fnc_mission_claim) reaches every mission's units wherever they wandered, and
    the keep-radius the sweep already applies covers their deletion.
*/

if (!isServer) exitWith {};
params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false], ["_token", -1]];
["INFO", "MISSION", format ["cleanup: composition %1, token %2",
    ["none", _compKey] select (_compKey != ""), _token]] call fnc_log;

if (_compKey != "") then { [_compKey] call fnc_duws_release };

// Flag only: the sweep stamps the default lifetime on first sight, as it does the released props, so men
// and the props they stood among expire together. Dead owned men ride the sweep's allDeadMen census, so
// only the living flag here.
if (_token >= 0) then {
    // isEqualTo, not ==: a unit the sweep deleted this frame lingers non-null in the census with its
    // variable space already gone, so getVariable hands back nil, not the -1 default, and nil == _token
    // throws, aborting the select. isEqualTo reads the type mismatch as false instead.
    private _owned = (allUnits + vehicles) select {(_x getVariable ["DUWS_missionOwner", -1]) isEqualTo _token};
    { _x setVariable ["DUWS_binMe", true] } forEach _owned;
    ["INFO", "MISSION", format ["token %1: %2 claimed entities flagged for cleanup", _token, count _owned]] call fnc_log;
};
