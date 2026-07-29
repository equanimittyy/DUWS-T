// Locality: server -- both waypoints and ambient poses are ignored unless the group is local.
/*
    fnc_civ_wp_Tomata.sqf
    Gives a freshly spawned crowd something to do: part of it stands and poses, the rest walks a
    short circuit near where it spawned. Params: [_groups, _buildings].
*/
if (!isServer) exitWith {};

// Share of the crowd that poses instead of walking. A town where everyone is in motion reads as
// an evacuation; one where nobody is reads as a waxworks.
#define IDLE_SHARE 0.45

// How far a walker's circuit reaches from where it spawned. Wide enough that two neighbours do
// not trace the same path, short enough to keep the crowd in the cluster the spawn packed it
// into -- waypoints drawn across the whole town are what had civilians jogging between postcodes.
#define ROAM_RADIUS 60

params ["_groups", "_buildings"];

_buildings = _buildings select {!isNull _x && {_x isKindOf "Building"}};

// Poses that need no prop. The crowd is placed by findSafePos and by building positions, so a
// pose wanting a chair or a table would be played on open ground.
//
// Names are exact and unvalidated by the engine: BIS_fnc_ambientAnim has no SMOKING set and no
// bare WATCH, only WATCH1 and WATCH2, and an unknown name leaves the civilian standing in the
// default stance with nothing logged. The STAND_U variants are the unarmed idles, which is what
// a civilian should be playing.
private _idlePoses = ["STAND", "STAND_IA", "STAND_U1", "STAND_U2", "STAND_U3", "LEAN", "WATCH1", "WATCH2"];

// Water is the one surface worth rejecting: an unreachable waypoint inland is left behind by the
// timeout, but a coastal town will happily walk someone into the sea.
private _fnc_strollPos = {
    params ["_origin"];
    private _pos = _origin;
    for "_i" from 1 to 6 do {
        private _try = _origin getPos [10 + random (ROAM_RADIUS - 10), random 360];
        if (!surfaceIsWater _try) exitWith { _pos = _try };
    };
    _pos
};

// Zombies keep the building-to-building hunt this function used to give everyone: a walking pace
// and a smoke break are what a living town looks like, and neither reads as undead.
private _fnc_hunt = {
    params ["_group", "_buildings"];
    if !(_buildings isEqualTo []) then {
        for "_i" from 1 to 2 do {
            private _building = selectRandom _buildings;
            private _positions = [_building] call BIS_fnc_buildingPositions;
            if (count _positions == 0) then { continue };
            private _wp = _group addWaypoint [_building buildingPos (floor random count _positions), 2];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "NORMAL";
            _wp setWaypointBehaviour "STEALTH";
            _wp setWaypointCombatMode "GREEN";
            _wp setWaypointTimeout [60, 90, 120];
            _wp setWaypointCompletionRadius 15;
        };
    };
    private _cycle = _group addWaypoint [getPos leader _group, 2];
    _cycle setWaypointType "CYCLE";
    _cycle setWaypointSpeed "NORMAL";
    _cycle setWaypointBehaviour "STEALTH";
    _cycle setWaypointCombatMode "GREEN";
    _cycle setWaypointCompletionRadius 15;
};

{
    private _group = _x;
    private _unit = leader _group;
    if (isNull _unit) then { continue };

    if (_unit getVariable ["civ_isZombie", false]) then {
        [_group, _buildings] call _fnc_hunt;
        continue;
    };

    // SAFE and LIMITED are the whole difference from the jog this replaces. SAFE keeps them
    // upright instead of moving tactically, LIMITED is the walk; the pair was STEALTH and NORMAL,
    // which is a crouching sprint and the reason the crowd looked panicked before anyone fired.
    _group setBehaviour "SAFE";
    _group setSpeedMode "LIMITED";

    // Rolled once per civilian and then remembered. This function is what re-issues orders after
    // a conversation and after a panic, and re-rolling each time meant someone who had stood on
    // the same corner all afternoon wandered off the moment they were spoken to. The share above
    // therefore decides the composition of a town once, at its fill, rather than every time
    // anything happens to anyone in it.
    private _idler = _unit getVariable "civ_idler";
    if (isNil "_idler") then {
        _idler = random 1 < IDLE_SHARE;
        _unit setVariable ["civ_idler", _idler];
    };

    if (_idler) then {
        // Ambient poses rather than a raw switchMove: BIS_fnc_ambientAnim installs the handlers
        // that break the animation on death, where a hand-rolled pose leaves the corpse standing
        // upright and shrugging off hits. It owns the unit's AI until terminated, which is why
        // the call-over has to release it before a doMove will take.
        [_unit, selectRandom _idlePoses] call BIS_fnc_ambientAnim;
        // Our own flag, not one of the function's internals: the call-over and the panic sweep
        // both have to know whether there is a pose to release, and keying that on a variable
        // BI sets privately would break silently the day it is renamed.
        _unit setVariable ["civ_posed", true];
        continue;
    };

    private _origin = getPos _unit;
    private _first = [];
    for "_i" from 1 to (2 + floor random 2) do {
        private _wp = _group addWaypoint [[_origin] call _fnc_strollPos, 0];
        if (_first isEqualTo []) then { _first = _wp };
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "GREEN";
        // Short and varied next to the flat minute the old waypoints held: the pause is what
        // makes a walker read as someone going somewhere rather than a patrol on a loop.
        _wp setWaypointTimeout [10, 30, 60];
        _wp setWaypointCompletionRadius 5;
    };

    private _cycle = _group addWaypoint [_origin, 0];
    _cycle setWaypointType "CYCLE";
    _cycle setWaypointSpeed "LIMITED";
    _cycle setWaypointBehaviour "SAFE";
    _cycle setWaypointCombatMode "GREEN";
    _cycle setWaypointCompletionRadius 5;

    // The call-over ends on a doStop so the civilian stands still to be spoken to, and a stopped
    // unit ignores its group's waypoints until it is given a move of its own -- new orders do not
    // release it. Every civilian is its own group leader, so the stop held the whole circuit and
    // anyone the player talked to stood where the conversation ended. Harmless on the fill path,
    // where the first leg is where they were headed anyway.
    _unit doMove (waypointPosition _first);
} forEach _groups;
