// Locality: server -- addWaypoint, setBehaviour and setPos are ignored unless the group is local to
// the machine issuing them (docs/info/arma_engine_gotchas.md); every caller spawns server-side.
//
// usage: [_group, _posture, _centre, _radius, _anchors] call fnc_apply_posture
//
// A group's standing orders, held apart from what the group is made of. These were a column on
// DUWS_teamRosters read by a switch inside fnc_spawn_team, which welded a roster to one set of
// orders: fielding the same five men dug in rather than patrolling meant a second roster row with an
// identical roster. A composition names a posture and a team independently instead, so one roster
// covers both and the orders are a property of the ground rather than of the men.
//
// Shared by the zone band, the town garrison, the mission patrol builders and the base guards, which
// is why it takes a group already standing rather than raising one: a vehicle crew and a rifle
// section are ordered the same way and are spawned very differently.
//
// _anchors is hqpatrol's alone -- the points that posture walks. Every other posture is radial off
// _centre, which is why the list is an argument rather than something derived here: only the caller
// knows which towers, gates or corners its circuit is meant to visit.
params ["_group", "_posture", "_centre", "_radius", ["_anchors", []]];
if (isNull _group) exitWith {};

// Every posture is SAFE, set once here rather than per branch so a new posture cannot forget it.
// A garrison at rest until something happens to it is the read the mission wants, and the engine
// promotes a group out of SAFE by itself the moment it detects anything -- so AWARE only ever
// bought men who were already alert before the player had done anything to alert them.
_group setBehaviour "SAFE";

private _patrolRadius = round (_radius / 1.25);
// A mounted group cannot walk into a house or hold a tower, so the two postures that place men
// inside a structure answer differently for one. Read off the leader's vehicle rather than off the
// token that asked, because the engine's own answer cannot disagree with what was actually spawned.
private _leader = leader _group;
private _mounted = vehicle _leader != _leader;
private _isAir = (vehicle _leader) isKindOf "Air";

// How far out a garrison looks for something to hold. Deliberately not the zone radius: a squad sent
// 1200 m to a shed is not garrisoning the objective, and the point of holding buildings is that the
// middle of the zone has to be dug out.
#define GARRISON_REACH 300

// Usable building positions a house must offer before a squad will hold it. Keeps a garrison out of
// sheds and doorways, where a squad has nowhere to fire from and reads as men standing in a hut.
#define GARRISON_POSITIONS 5

switch (_posture) do {
    case "closepatrol": {
        // Engages what it walks into without abandoning the circuit. Set here rather than per
        // waypoint because it is the group's disposition, not one order.
        _group setCombatMode "YELLOW";
        {
            // One leg of a foot patrol's circuit ends inside a building rather than on open ground,
            // so a patrol that owns a settlement is actually in it when the player arrives. A
            // mounted group gets an ordinary leg: it cannot go inside, and pathing a vehicle at a
            // building's centre parks it against a wall.
            private _inBuilding = _x == 3 && {!_mounted};
            private _wp = if (_inBuilding) then {
                private _here = getPos _leader;
                private _spot = [(_here select 0) + (random _patrolRadius) - (random _patrolRadius),
                                 (_here select 1) + (random _patrolRadius) - (random _patrolRadius)];
                _group addWaypoint [getPos (nearestBuilding _spot), 0]
            } else {
                private _w = _group addWaypoint [_centre, _patrolRadius];
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
        // One group, one structure. This replaced three placers that each raised their own men from
        // a hardcoded role list and ordered them in the same breath -- houses, towers and bunkers --
        // so a composition could not ask for those men under any other orders. What they had in
        // common was holding a fixed post; what differed was the class list and the leash, and both
        // are decided here from what the group actually claimed.
        // nearestObjects, not nearestTerrainObjects: these have to include what the zone prefab put
        // down as well as what the map shipped. The V1 and V3 variants are here because the modern
        // prefabs build those and the list only named V2, so a zone's own guard towers stood empty
        // while the map's were manned. Safe to keep extending: the positions test below drops
        // anything that turns out to have no interior.
        private _posts = [];
        if (!_mounted) then {
            {
                _posts append (nearestObjects [_centre, [_x], GARRISON_REACH]);
            } forEach ["Land_GuardTower_02_F", "Land_Bunker_01_tall_F",
                       "Land_Cargo_Tower_V1_F", "Land_Cargo_Tower_V2_F",
                       "Land_Cargo_Patrol_V1_F", "Land_Cargo_Patrol_V2_F", "Land_Cargo_Patrol_V3_F",
                       "Land_BagBunker_Tower_F", "Land_BagBunker_Large_F"];
        };

        // A fixed floor rather than one position per man: enemyunitMultiplier can double or treble a
        // squad, and a requirement that tracked it would price every house on the map out at x3 and
        // drop the whole garrison through to the patrol fallback below.
        private _houses = if (_mounted) then { [] } else {
            [_centre, GARRISON_POSITIONS, GARRISON_REACH] call fnc_usableBuildings
        };

        private _candidates = [];
        { _candidates pushBackUnique _x } forEach (_posts + _houses);
        // Sorted as one pool rather than posts-then-houses, so a garrison fills outward from the
        // middle whatever kind of structure happens to be nearest it.
        _candidates = [_candidates, [_centre], { _input0 distance _x }, "ASCEND"] call BIS_fnc_sortBy;

        // Claimed on the structure itself, not in a list the caller holds. The slots of one
        // composition are raised five seconds apart by DUWS_fnc_raiseGarrison and never see each
        // other, and a zone, a town and a side mission can all be reaching into the same street. A
        // claim held by a group that has since been collected reads as null, so the building frees
        // itself without anything having to sweep up after it.
        //
        // Positions are checked as well as the claim, and lazily, so the lookup is only paid until
        // one candidate matches. A prefab or a mod can put a bunker-shaped prop on the ground with
        // no positions inside it: fnc_spreadIntoBuildings places nobody in one and says nothing, so
        // claiming it would strand the squad wherever it spawned and burn the slot silently.
        private _i = _candidates findIf {
            isNull (_x getVariable ["DUWS_garrisonedBy", grpNull])
            && {count ([_x] call BIS_fnc_buildingPositions) > 0}
        };

        if (_i < 0) then {
            // Nothing left to hold. Sent out rather than left standing on the spot they spawned:
            // a squad with no building is a squad with no orders, and patrolling is what the rest
            // of the garrison is already doing.
            //
            // Logged because the two ways of getting here are indistinguishable in play: a zone
            // whose garrison all patrols looks the same whether nothing holdable stands there or
            // every candidate was refused. The count separates them -- zero means the ground is
            // bare, non-zero means the claim or the positions test took them all.
            ["INFO", "ZONES", format ["%1 found no free post; %2 candidates within %3 m",
                groupId _group, count _candidates, GARRISON_REACH]] call fnc_log;
            [_group, selectRandom ["closepatrol", "widepatrol"], _centre, _radius]
                call fnc_apply_posture;
        } else {
            private _building = _candidates select _i;
            _building setVariable ["DUWS_garrisonedBy", _group];
            // Pinned, house and tower alike. Letting a house garrison roam between its own building
            // positions read as men milling about indoors rather than holding the place, and a man
            // walking is a man the player watches walk -- so the whole posture is now place, hold,
            // done. The only thing a structure's kind still decides is stance: a guard on a catwalk
            // stands, where a house garrison takes whatever the fight calls for.
            private _isPost = _building in _posts;
            [_group, [_building], count units _group, ["AUTO", "UP"] select _isPost, "PIN"]
                call fnc_spreadIntoBuildings;
        };
    };

    case "hqpatrol": {
        // A fixed circuit through points the caller names, rather than a radius to wander. The base
        // guards walk their own towers and the FOB pair walks its corners, and neither is a shape
        // that can be derived from a centre and a distance.
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

    // The caller places the group and gives it orders itself. Matched rather than left to the
    // default below, so a posture nobody implements is still reported.
    case "none": {};

    default {
        ["WARN", "ZONES", format ["%1 is not a posture; %2 stands with no orders",
            _posture, groupId _group]] call fnc_log;
    };
};
