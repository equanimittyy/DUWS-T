// Server-only: addWaypoint, setBehaviour and setPos are no-ops unless the group is local to the
// machine issuing them (docs/info/architecture/arma_engine_gotchas.md); every caller spawns server-side.
// Orders live apart from roster, shared by zone bands, town garrisons, patrol and base-guard builders:
// it takes a group already standing rather than raising one, so a vehicle crew and a rifle section are
// ordered identically here despite spawning very differently.
// _anchors is hqpatrol's alone (the points that posture walks); every other posture is radial off
// _centre. It's an argument, not derived, because only the caller knows which towers, gates or
// corners its circuit is meant to visit.
params ["_group", "_posture", "_centre", "_radius", ["_anchors", []]];
if (isNull _group) exitWith {};

// SAFE is set once here, not per branch, so a new posture can't forget it. The engine promotes a
// group out of SAFE the moment it detects a threat, so setting AWARE here only ever alerted men
// before the player had done anything to alert them.
_group setBehaviour "SAFE";

// Circuit radius follows the posture, from the same DUWS_postureBands the spawn band reads, so a wide
// patrol's waypoints reach the ring it spawned on. Unlisted postures fall back to 0.8 of the radius --
// what every posture walked before the bands split close from wide.
private _patrolFrac = (DUWS_postureBands getOrDefault [_posture, [0, 0, 0.8]]) select 2;
private _patrolRadius = round (_radius * _patrolFrac);
// A mounted group can't enter a building or hold a tower, so garrison and closepatrol answer
// differently for it. Read off the leader's vehicle, not the token that asked: the engine's own
// answer can't disagree with what actually spawned.
private _leader = leader _group;
private _mounted = vehicle _leader != _leader;
private _isAir = (vehicle _leader) isKindOf "Air";

// Deliberately not the zone radius: a squad sent 1200 m to a shed isn't garrisoning the objective --
// holding buildings is about digging out the zone's middle.
#define GARRISON_REACH 300

// Keeps a garrison out of sheds and doorways, where a squad has nowhere to fire from and reads as
// men standing in a hut.
#define GARRISON_POSITIONS 5

// A foot patrol's whole roster spawns stacked on one BIS_fnc_spawnGroup point -- ring them out first.
// Roaming foot postures only: garrison spreads into buildings itself, hunt charges, mounted keeps hull
// spacing; hqpatrol is safe to include since its anchors are waypoints, not the spawn point.
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
        _group setCombatMode "YELLOW";
        {
            // One leg ends inside a building so a patrol that owns a settlement is actually in it.
            // Mounted groups get an ordinary leg instead -- they can't go inside, and pathing to a
            // building's centre parks them against a wall.
            private _inBuilding = _x == 3 && {!_mounted};
            private _wp = if (_inBuilding) then {
                private _here = getPos _leader;
                private _spot = [(_here select 0) + (random _patrolRadius) - (random _patrolRadius),
                                 (_here select 1) + (random _patrolRadius) - (random _patrolRadius)];
                _group addWaypoint [getPos (nearestBuilding _spot), 0]
            } else {
                // addWaypoint's own radius pick doesn't water-check, so a coastal patrol can drop a leg
                // in the sea; findSafePos waterMode 0 finds a ring point clear of water, falling back
                // to the raw pick (inland zones unaffected) when none is found.
                private _land = [_centre, _patrolRadius, 0, 5, 0.5, []] call fnc_safe_pos;
                private _w = if (_land isEqualTo []) then {
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
            // Building leg is a long stay, open legs are a walk-through; aircraft skip the timeout --
            // one loitering on a waypoint is a stationary target.
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
        // One group, one structure. Replaces three placers that each hardcoded a role list and orders
        // together, so a composition couldn't ask for those men under any other orders -- post vs.
        // house is now decided from what the group actually claimed.
        // nearestObjects, not nearestTerrainObjects, to include what the zone prefab placed as well as
        // what the map shipped. V1/V3 variants are listed because modern prefabs use them where the old
        // list only named V2; safe to extend since the positions test below drops anything with no
        // interior.
        private _posts = [];
        if (!_mounted) then {
            {
                _posts append (nearestObjects [_centre, [_x], GARRISON_REACH]);
            } forEach ["Land_GuardTower_02_F", "Land_Bunker_01_tall_F",
                       "Land_Cargo_Tower_V1_F", "Land_Cargo_Tower_V2_F",
                       "Land_Cargo_Patrol_V1_F", "Land_Cargo_Patrol_V2_F", "Land_Cargo_Patrol_V3_F",
                       "Land_BagBunker_Tower_F", "Land_BagBunker_Large_F"];
        };

        // Fixed floor, not one position per man -- a garrison slot is ~5 men regardless of campaign
        // settings (the multiplier adds slots, not men). Tracking group size would only shift with a
        // roster edit, and pricing demand would drop small houses to the patrol fallback.
        private _houses = if (_mounted) then { [] } else {
            [_centre, GARRISON_POSITIONS, GARRISON_REACH] call fnc_usableBuildings
        };

        private _candidates = [];
        { _candidates pushBackUnique _x } forEach (_posts + _houses);
        // One pool, not posts-then-houses, so a garrison fills outward from the middle whatever
        // structure is nearest.
        _candidates = [_candidates, [_centre], { _input0 distance _x }, "ASCEND"] call BIS_fnc_sortBy;

        // Claimed on the structure itself, not a list the caller holds: composition slots raise five
        // seconds apart via DUWS_fnc_raiseGarrison and never see each other, and a zone/town/side
        // mission can reach the same street. A claim held by a since-collected group reads null, so
        // the building frees itself with nothing to sweep up.
        // Positions are checked lazily alongside the claim, so the lookup is only paid until one
        // candidate matches. A prefab/mod can shape a bunker prop with no interior positions --
        // fnc_spreadIntoBuildings would silently strand the squad there and burn the slot.
        private _i = _candidates findIf {
            isNull (_x getVariable ["DUWS_garrisonedBy", grpNull])
            && {count ([_x] call BIS_fnc_buildingPositions) > 0}
        };

        if (_i < 0) then {
            // Nothing left to hold: sent to patrol rather than left standing, since a squad with no
            // building is a squad with no orders.
            // Logged with the candidate count because bare ground and every candidate refused look
            // identical in play -- zero means bare ground, non-zero means the claim or positions test
            // took them all.
            ["INFO", "ZONES", format ["%1 found no free post; %2 candidates within %3 m",
                groupId _group, count _candidates, GARRISON_REACH]] call fnc_log;
            [_group, selectRandom ["closepatrol", "widepatrol"], _centre, _radius]
                call fnc_apply_posture;
        } else {
            private _building = _candidates select _i;
            _building setVariable ["DUWS_garrisonedBy", _group];
            // Holds via a doMove loop between the building's positions with pathing left on, so it
            // works the post and fights -- disabling pathing froze the squad mid-firefight. Stance splits
            // by structure: a post stands (UP), a house takes what the fight calls for (AUTO); a tower
            // guard can occasionally strand itself walking between platform slots -- accepted cost of
            // not freezing it.
            private _isPost = _building in _posts;
            [_group, [_building], count units _group, ["AUTO", "UP"] select _isPost]
                call fnc_spreadIntoBuildings;
        };
    };

    case "hqpatrol": {
        // A fixed circuit through caller-named points, not a radius to wander: base guards walk their
        // own towers and the FOB pair walks its corners, neither derivable from a centre and a distance.
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
            // Cycles back to the first leg -- without it the group stops on the last anchor and stands there.
            private _cycle = _group addWaypoint [_anchors select 0, 0];
            _cycle setWaypointType "CYCLE";
            _cycle setWaypointBehaviour "SAFE";
            _cycle setWaypointSpeed "LIMITED";
        };
    };

    case "hunt": {
        // A reinforcement wave, not a garrison: runs at the players and engages rather than settling
        // into a circuit. AWARE and FULL override the SAFE set above -- a reinforcement runs, it
        // doesn't stroll -- for mounted and air alike, each hunting at its own speed.
        // SAD targets the zone centre, not the player, since the wave's job is to retake the objective
        // -- engaging whoever holds it, player or empty ground. Targeting the player's spawn-time
        // position instead walked the reserve off the zone on withdrawal, leaving the objective taken
        // and the counterattack chasing empty ground.
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

    // Matched explicitly, not left to the default below, so a posture nobody implements is still reported.
    case "none": {};

    default {
        ["WARN", "ZONES", format ["%1 is not a posture; %2 stands with no orders",
            _posture, groupId _group]] call fnc_log;
    };
};
