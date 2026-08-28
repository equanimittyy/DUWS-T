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
    but no longer read: the blunt radius pass is gone -- ownership (fnc_mission_claim) reaches every
    mission's units wherever they wandered -- and the keep-radius the sweep already applies is strictly
    more protective than the old announce-and-countdown was.
*/

if (!isServer) exitWith {};
params ["_targetpos", "_radius", ["_compKey", ""], ["_sweepFriendly", false], ["_token", -1]];
["INFO", "MISSION", format ["cleanup: composition %1, token %2",
    ["none", _compKey] select (_compKey != ""), _token]] call fnc_log;

// Props to the sweep on the shared keep-radius clock: release drops protection and sets a deadline,
// so the objective's buildings go once the player is clear rather than in their face.
if (_compKey != "") then { [_compKey] call fnc_duws_release };

// The mission's living units and vehicles carry a delete order, not an instant deletion. Crew and
// vehicle were both stamped by fnc_mission_claim, so both flag here; the sweep bins them under its
// keep-radius and the deadline. binAt matches the released composition's ~5-minute clock so the men
// and the props they stood among expire together. Dead owned men are already collected by the
// sweep's allDeadMen census -- keep-radius protected, so corpse intel stays reachable.
if (_token >= 0) then {
    // isNull guard first, short-circuited: allUnits + vehicles can hand back a null reference, and
    // getVariable on a null object returns nil, not the -1 default -- nil == _token then throws a
    // generic error that aborts the whole select, so nothing gets flagged and the mission never cleans up.
    private _owned = (allUnits + vehicles) select {!isNull _x && {_x getVariable ["DUWS_missionOwner", -1] == _token}};
    {
        _x setVariable ["DUWS_binMe", true];
        _x setVariable ["DUWS_binAt", time + 300];
    } forEach _owned;
    ["INFO", "MISSION", format ["token %1: %2 claimed entities flagged for cleanup", _token, count _owned]] call fnc_log;
};
