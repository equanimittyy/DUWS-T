// Locality: server -- every mission thread and both patrol builders run there.
/*
    NAME: missions\fnc_mission_claim.sqf

    DESCRIPTION:
    Files living entities a side mission raised under the mission that raised them, so the teardown
    can collect them by ownership instead of by proximity. Proximity was never a sound test here: a
    guard ring patrols out to its own radius and a spawned car drives, so what the sweep caught
    depended on where the AI had wandered by the time it ran. That is how a rescue left a man and a
    car standing on the map after its cleanup had already finished.

    USAGE: groups or units, one or many.
        [_group] call fnc_mission_claim;
        [[_grpA, _grpB]] call fnc_mission_claim;

    Props are deliberately not claimed here. They belong to a composition and fnc_duws_keep already
    tracks them by key; that function refuses living entities for the mirror-image reason, their
    presence being owned by their own spawn and despawn logic.

    Never claim what a mission hands the player. A rescued squad, a recruited civilian and a
    captured vehicle are all meant to outlive the mission, and a claim is a deletion order.

    The token defaults to the running mission's because only one side mission holds the slot at a
    time: fnc_mission_begin is the only thing that advances it, and it cannot run while
    Mission_available is false.
*/

if (!isServer) exitWith {};
params [["_things", []], ["_token", missionNamespace getVariable ["DUWS_mission_token", 0]]];

if !(_things isEqualType []) then { _things = [_things] };

{
    // The vehicle is stamped alongside its crew rather than left to be inferred at teardown: crew
    // die, and an APC whose last gunner was shot would otherwise be an unowned wreck-in-waiting.
    {
        _x setVariable ["DUWS_missionOwner", _token];
        if (vehicle _x != _x) then { (vehicle _x) setVariable ["DUWS_missionOwner", _token] };
    } forEach (if (_x isEqualType grpNull) then { units _x } else { [_x] });
} forEach _things;
