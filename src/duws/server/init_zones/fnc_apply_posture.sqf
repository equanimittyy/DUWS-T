// Locality: server -- addWaypoint, setBehaviour and setPos are ignored unless the group is local to
// the machine issuing them (docs/info/architecture/arma_engine_gotchas.md); every caller spawns server-side.
//
// A group's standing orders, held apart from what it is made of: a composition names a posture and a
// team independently, so one roster works under any posture and the orders are a property of the
// ground rather than of the men.
//
// Shared by the zone band, town garrison, mission patrol builders and base guards, so it takes a
// group already standing rather than raising one -- a vehicle crew and a rifle section are ordered
// the same way despite being spawned very differently.
//
// _anchors is hqpatrol's alone (the points that posture walks); every other posture is radial off
// _centre. It is an argument rather than derived here because only the caller knows which towers,
// gates or corners its circuit is meant to visit.
params ["_group", "_posture", "_centre", "_radius", ["_anchors", []]];
if (isNull _group) exitWith {};

// Every posture is SAFE, set once here (not per branch) so a new posture cannot forget it. A
// garrison at rest is the read the mission wants; the engine promotes a group out of SAFE itself
// the moment it detects anything -- so setting AWARE here only ever alerted men before the player
// had done anything to alert them.
_group setBehaviour "SAFE";

// Circuit radius follows the posture, from the same DUWS_postureBands the spawn band reads, so a wide
// patrol's waypoints reach the ring it spawned on. A posture the table does not name falls back to 0.8
// of the radius -- what every posture walked before the bands split close from wide.
private _patrolFrac = (DUWS_postureBands getOrDefault [_posture, [0, 0, 0.8]]) select 2;
private _patrolRadius = round (_radius * _patrolFrac);
// A mounted group cannot walk into a house or hold a tower, so the two postures that place men
// inside a structure answer differently for one. Read off the leader's vehicle rather than the
// token that asked: the engine's own answer cannot disagree with what actually spawned.
private _leader = leader _group;
private _mounted = vehicle _leader != _leader;
private _isAir = (vehicle _leader) isKindOf "Air";

// How far out a garrison looks for something to hold. Deliberately not the zone radius: a squad sent
// 1200 m to a shed isn't garrisoning the objective -- holding buildings is about digging out the
// zone's middle.
#define GARRISON_REACH 300

// Usable building positions a house must offer before a squad will hold it. Keeps a garrison out of
// sheds and doorways, where a squad has nowhere to fire from and reads as men standing in a hut.
#define GARRISON_POSITIONS 5

// A foot patrol's whole roster spawns on one BIS_fnc_spawnGroup point, so it jams stacked until the
// men path apart -- ring them out first. The roaming foot postures only: garrison spreads into
// buildings itself, hunt charges, mounted keeps hull spacing. hqpatrol is safe to include because its
// anchors are waypoints, not the spawn point. Leader holds as the anchor; water and occupied rejected.
if (!_mounted && {_posture in ["closepatrol", "widepatrol", "hqpatrol"]}) then {
    private _origin = getPos _leader;
    private _reach = 6 max (2.5 * count units _group);
    {
        if (_x != _leader) then {
            private _spot = [_origin, 3, _reach, 3, 0, 0.6, 0] call BIS_fnc_findSafePos;
            if (_spot isNotEqualTo [] && {!surfaceIsWater _spot} && {_spot distance2D _origin <= _reach * 2}) then {
                _x setPos _spot;
            };
        };
    } forEach units _group;
};

switch (_posture) do {
    case "closepatrol": {
        // Engages what it walks into without abandoning the circuit. Set once here, not per
        // waypoint, because it's the group's disposition rather than one order.
        _group setCombatMode "YELLOW";
        {
            // One leg of a foot patrol's circuit ends inside a building rather than on open ground,
            // so a patrol that owns a settlement is actually in it when the player arrives. A
            // mounted group gets an ordinary leg instead: it cannot go inside, and pathing a
            // vehicle at a building's centre parks it against a wall.
            private _inBuilding = _x == 3 && {!_mounted};
            private _wp = if (_inBuilding) then {
                private _here = getPos _leader;
                private _spot = [(_here select 0) + (random _patrolRadius) - (random _patrolRadius),
                                 (_here select 1) + (random _patrolRadius) - (random _patrolRadius)];
                _group addWaypoint [getPos (nearestBuilding _spot), 0]
            } else {
                // Keep the open leg on land: addWaypoint's own radius pick doesn't water-check, so
                // a coastal closepatrol can drop a leg in the sea and walk the group in. findSafePos
                // waterMode 0 draws a random ring point clear of water; fall back to the raw pick
                // when none is found, leaving an inland zone's waypoints unchanged.
                private _land = [_centre, 0, _patrolRadius, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
                private _w = if (_land isEqualTo [] || {surfaceIsWater _land}) then {
                    _group addWaypoint [_centre, _patrolRadius]
                } else {
                    _group addWaypoint [_land, 0]
                };
                _w setWaypointCompletionRadius 100;
                _w
            };
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointSpeed "LIMITED";
            // The building leg is a long stay; the open legs are a walk-through. An aircraft holds
            // no leg at all -- one loitering on a waypoint is a stationary target.
            if (!_isAir) then {
                _wp setWaypointTimeout ([[60, 120, 180], [300, 450, 600]] select _inBuilding);
            };
        } forEach [1, 2, 3];

        private _cycle = _group addWaypoint [_centre, 30];
        _cycle setWaypointType "CYCLE";
        _cycle setWaypointBehaviour "SAFE";
        _cycle setWaypointSpeed "LIMITED";
    };

    case "widepatrol": {
        [_group, _centre, _patrolRadius] call bis_fnc_taskPatrol;
    };

    case "garrison": {
        // One group, one structure. This replaced three placers that each raised their own men from a
        // hardcoded role list and ordered them in the same breath (houses, towers, bunkers), so a
        // composition could not ask for those men under any other orders. What they had in common was
        // holding a fixed post; what differed was the class list and the leash, both now decided here
        // from what the group actually claimed.
        //
        // nearestObjects, not nearestTerrainObjects: this has to include what the zone prefab placed as
        // well as what the map shipped. V1 and V3 variants are listed because modern prefabs build
        // those and the old list only named V2, leaving a zone's own guard towers empty while the
        // map's were manned. Safe to keep extending -- the positions test below drops anything with
        // no interior.
        private _posts = [];
        if (!_mounted) then {
            {
                _posts append (nearestObjects [_centre, [_x], GARRISON_REACH]);
            } forEach ["Land_GuardTower_02_F", "Land_Bunker_01_tall_F",
                       "Land_Cargo_Tower_V1_F", "Land_Cargo_Tower_V2_F",
                       "Land_Cargo_Patrol_V1_F", "Land_Cargo_Patrol_V2_F", "Land_Cargo_Patrol_V3_F",
                       "Land_BagBunker_Tower_F", "Land_BagBunker_Large_F"];
        };

        // A fixed floor rather than one position per man. A garrison slot is a squad of about five
        // whatever the campaign settings say -- the enemy multiplier adds slots, not men -- so a
        // requirement tracking group size would only move with a roster edit, and a demanding one
        // prices small houses out and drops the squad to the patrol fallback.
        private _houses = if (_mounted) then { [] } else {
            [_centre, GARRISON_POSITIONS, GARRISON_REACH] call fnc_usableBuildings
        };

        private _candidates = [];
        { _candidates pushBackUnique _x } forEach (_posts + _houses);
        // Sorted as one pool rather than posts-then-houses, so a garrison fills outward from the
        // middle whatever kind of structure happens to be nearest it.
        _candidates = [_candidates, [_centre], { _input0 distance _x }, "ASCEND"] call BIS_fnc_sortBy;

        // Claimed on the structure itself, not in a list the caller holds: the slots of one
        // composition are raised five seconds apart by DUWS_fnc_raiseGarrison and never see each
        // other, and a zone, a town and a side mission can all be reaching into the same street. A
        // claim held by a group that has since been collected reads as null, so the building frees
        // itself with nothing having to sweep up after it.
        //
        // Positions are checked as well as the claim, and lazily, so the lookup is only paid until
        // one candidate matches. A prefab or mod can put a bunker-shaped prop with no positions
        // inside it -- fnc_spreadIntoBuildings places nobody there and says nothing -- so claiming
        // it would silently strand the squad wherever it spawned and burn the slot.
        private _i = _candidates findIf {
            isNull (_x getVariable ["DUWS_garrisonedBy", grpNull])
            && {count ([_x] call BIS_fnc_buildingPositions) > 0}
        };

        if (_i < 0) then {
            // Nothing left to hold. Sent out to patrol rather than left standing where it spawned:
            // a squad with no building is a squad with no orders, and patrolling is what the rest
            // of the garrison is already doing.
            //
            // Logged because the two ways of getting here look identical in play: a zone whose
            // garrison all patrols reads the same whether nothing holdable stands there or every
            // candidate was refused. The count disambiguates -- zero means bare ground, non-zero
            // means the claim or positions test took them all.
            ["INFO", "ZONES", format ["%1 found no free post; %2 candidates within %3 m",
                groupId _group, count _candidates, GARRISON_REACH]] call fnc_log;
            [_group, selectRandom ["closepatrol", "widepatrol"], _centre, _radius]
                call fnc_apply_posture;
        } else {
            private _building = _candidates select _i;
            _building setVariable ["DUWS_garrisonedBy", _group];
            // Every garrison holds via a doMove loop between the building's positions with pathing
            // left on, so it works the building and fights. Disabling pathing instead froze the
            // squad mid-firefight -- no repositioning, no breaking for cover. A withdrawal releases
            // the loop (DUWS_fnc_zoneSendOff clears it and re-enables PATH), so the hold never
            // outlives a later order. Stance still splits on structure type: a post stands (UP), a
            // house takes what the fight calls for (AUTO). A tower guard can now walk between its
            // own platform slots and may occasionally strand itself at the base -- accepted cost of
            // not freezing it.
            private _isPost = _building in _posts;
            [_group, [_building], count units _group, ["AUTO", "UP"] select _isPost]
                call fnc_spreadIntoBuildings;
        };
    };

    case "hqpatrol": {
        // A fixed circuit through points the caller names, rather than a radius to wander: the base
        // guards walk their own towers and the FOB pair walks its corners, neither of which is a
        // shape derivable from a centre and a distance.
        if (_anchors isEqualTo []) then {
            ["WARN", "ZONES", format ["hqpatrol needs anchors; %1 stands with no orders",
                groupId _group]] call fnc_log;
        } else {
            {
                private _wp = _group addWaypoint [_x, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointSpeed "LIMITED";
            } forEach _anchors;
            // Back to the first leg. Without the cycle the group stops on the last anchor and
            // stands there.
            private _cycle = _group addWaypoint [_anchors select 0, 0];
            _cycle setWaypointType "CYCLE";
            _cycle setWaypointBehaviour "SAFE";
            _cycle setWaypointSpeed "LIMITED";
        };
    };

    case "hunt": {
        // A reinforcement wave, not a garrison: it runs at the players and engages rather than settling
        // into a circuit. AWARE and speed FULL carry that urgency -- a reinforcement runs, it does not
        // stroll -- overriding the SAFE set above for this posture alone. Works unchanged for a mounted
        // group or an aircraft: each hunts at its own speed.
        //
        // The SAD target is the zone centre, not the player: the wave's job is to retake the objective,
        // so it drives onto the middle and engages whatever holds it -- the player while still on it,
        // the ground itself once they pull off. Aiming at the player's spawn-time position instead
        // walked the reserve off the zone on withdrawal, leaving the objective taken and the
        // counterattack chasing empty ground. Spawned on the far side, a centre destination still
        // crosses the group through the players on the way in.
        private _target = _centre;
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setSpeedMode "FULL";
        private _wp = _group addWaypoint [_target, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointSpeed "FULL";
        private _cycle = _group addWaypoint [_target, 30];
        _cycle setWaypointType "CYCLE";
        _cycle setWaypointBehaviour "AWARE";
        _cycle setWaypointSpeed "FULL";
    };

    // The caller places the group and orders it directly. Matched here rather than left to the
    // default below, so a posture nobody implements is still reported.
    case "none": {};

    default {
        ["WARN", "ZONES", format ["%1 is not a posture; %2 stands with no orders",
            _posture, groupId _group]] call fnc_log;
    };
};
