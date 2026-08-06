// Locality: server -- every mission thread and both patrol builders run there.
/*
    Files living entities under the mission that raised them, so the teardown collects by ownership
    rather than by proximity: a guard ring patrols out to its own radius and a spawned car drives, so
    what a radius sweep caught depended on where the AI had wandered by the time it ran.

    Accepts groups or units, one or many. Props are not claimed here -- fnc_duws_keep tracks them by
    composition key and refuses living entities, the mirror image.

    Never claim what a mission hands the player -- a rescued squad, a recruited civilian, a captured
    vehicle. A claim is a deletion order.

    The token defaults to the running mission's: only fnc_mission_begin advances it, and it cannot run
    while Mission_available is false.
*/

if (!isServer) exitWith {};
params [["_things", []], ["_token", missionNamespace getVariable ["DUWS_mission_token", 0]]];

if !(_things isEqualType []) then { _things = [_things] };

{
    // Vehicle stamped with its crew: crew die, and an APC whose last gunner was shot would
    // otherwise be an unowned wreck-in-waiting.
    {
        _x setVariable ["DUWS_missionOwner", _token];
        if (vehicle _x != _x) then { (vehicle _x) setVariable ["DUWS_missionOwner", _token] };
    } forEach (if (_x isEqualType grpNull) then { units _x } else { [_x] });
} forEach _things;
