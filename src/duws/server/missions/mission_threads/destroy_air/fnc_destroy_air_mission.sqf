// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

if (!([19, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 5000;
private _site = [_MissionPos, _radius, 19, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// The aircraft is whatever the side can field: a jet once it has reached the Air tier (AP 600), else the
// attack helicopter it earned at Armor. Both tokens carry their own AP and AttackHeli gates, so tokenClass
// answers "" when the side cannot field one. The site-finder proved the gunship available at offer time,
// but the side may have dropped below the tier since, or field no armed-air role at all, so guard both
// empty and abort rather than spawn nothing.
private _jet   = ["plane"] call DUWS_fnc_tokenClass;
private _class = if (_jet != "") then { _jet } else { ["attackheli"] call DUWS_fnc_tokenClass };
if (_class == "") exitWith {
    [19, _requester, "no_air_asset: OPFOR fields neither jet nor gunship"] call fnc_mission_abort;
};

// +10 CP when the side fields the jet (Air tier) over the attack helicopter (Armor tier); AP flat. An
// unadvertised completion bonus -- the briefing and map print the base, built at fnc_mission_begin
// before this rolls. Safe to bump in place: one mission runs at a time.
if (_jet != "") then { DUWS_curReward set [0, (DUWS_curReward select 0) + 10] };

private _taskId = format ["destroyair%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// fnc_spawn_vehicle flies air in from off the map, crews and dresses it. Posture "none" leaves the
// circuit to this file below: the shared widepatrol default (bis_fnc_taskPatrol) can neither hold every
// leg inside the ring nor set the airframe's altitude, both of which this mission needs. Claiming the
// group stamps the crew and hull, so the token sweep collects the wreck and any crew that bailed.
private _grp = [_class, _randomPos, _radius, "none"] call fnc_spawn_vehicle;
if (isNull _grp) exitWith {
    [19, _requester, "air_spawn_failed"] call fnc_mission_abort;
};
[_grp] call fnc_mission_claim;
private _veh = vehicle (leader _grp);

// Altitude follows the airframe: the jet cruises high, the attack helicopter works lower. Keyed on the
// hull, not the token, so it matches what actually spawned. Reset both the off-map entry altitude and
// the loiter height (fnc_spawn_vehicle enters every airframe at one fixed height) to the airframe's.
private _altitude = [300, 700] select (_veh isKindOf "Plane");
_veh flyInHeight _altitude;
_veh setPosATL [(getPosATL _veh) select 0, (getPosATL _veh) select 1, _altitude];

// A fast, alert circuit drawn strictly inside the mission ring, so the player runs the asset down
// rather than chasing a loiter that drifts off the map. Each leg sits on the outer half of the radius
// (position getPos keeps every pick well inside it) and the cycle returns through centre.
//
// Height jitters +/-200m off the airframe's base per leg, so the asset never flies one flat altitude the
// player can pre-lay a shot on. flyInHeight is above-ground-level, so the floor at 100m keeps the low end
// clear of terrain. The statement runs on the waypoint before its leg, retargeting the height as the
// aircraft turns onto that leg.
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_grp setSpeedMode "FULL";
for "_i" from 1 to 5 do {
    private _leg = _randomPos getPos [(_radius * 0.45) + random (_radius * 0.4), random 360];
    private _legAlt = (_altitude + (200 - random 400)) max 100;
    private _wp = _grp addWaypoint [_leg, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointCompletionRadius 500;
    _wp setWaypointStatements ["true", format ["(vehicle this) flyInHeight %1", _legAlt]];
};
private _cycle = _grp addWaypoint [_randomPos, 0];
_cycle setWaypointType "CYCLE";
_cycle setWaypointBehaviour "AWARE";
_cycle setWaypointSpeed "FULL";
_cycle setWaypointStatements ["true", format ["(vehicle this) flyInHeight %1", (_altitude + (200 - random 400)) max 100]];

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_DESTROY_AIR_DESC", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_destroyair_letsdothis", 8], ["STR_DUWS_T_actionteam", "STR_DUWS_T_destroyair_copy", 0]]
] call fnc_mission_present;

private _deadline = DUWS_curDeadlineAt;

// Allseer's fix marker on the aircraft, moved on the report cadence below. Created lazily on the first
// report so a kill before then leaves nothing to delete.
private _trackMarker = "";
private _nextReportAt = time + (150 + random 60);
// Far from every player the global ten-minute resupply (fnc_AI_Master_Control) never reaches the asset,
// so a long patrol runs the tank dry and the objective falls out of the sky before the player finds it.
// Keep it fuelled and armed on its own clock, unconditional on player proximity.
private _nextResupplyAt = time + 300;

// One-shot handoff from ring patrol to active hunt. The circuit above flies AWARE/YELLOW; the engine flips
// the crew to COMBAT on contact, and that transition is the trigger to drop the loiter and prosecute the
// nearest known enemy, so the asset closes on the player instead of flying its circuit past the fight.
private _engaging = false;

private _outcome = "";
waitUntil {
    sleep 5;
    if (!alive _veh) exitWith { _outcome = "WIN"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };

    if (!_engaging && {behaviour (leader _grp) == "COMBAT"}) then {
        private _tgt = _veh findNearestEnemy _veh;
        if (!isNull _tgt) then {
            for "_i" from (count (waypoints _grp) - 1) to 0 step -1 do { deleteWaypoint ((waypoints _grp) select _i) };
            _grp setCombatMode "RED";
            private _sad = _grp addWaypoint [getPosATL _tgt, 0];
            _sad setWaypointType "SAD";
            _sad setWaypointBehaviour "COMBAT";
            _sad setWaypointSpeed "FULL";
            _engaging = true;
        };
    };

    if (time > _nextResupplyAt) then {
        _veh setFuel 1;
        _veh setVehicleAmmo 1;
        _nextResupplyAt = time + 300;
    };

    // A periodic fix, not a live blip: Allseer jumps the marker onto the asset and calls it in, so the
    // player closes on a fast mover without the intercept being handed to them frame by frame.
    if (time > _nextReportAt) then {
        if (_trackMarker == "") then {
            _trackMarker = format ["destroyairtrk%1", _taskId];
            deleteMarker _trackMarker;   // a reused mission name can collide with a prior run's leftover
            createMarker [_trackMarker, getPosATL _veh];
            _trackMarker setMarkerType "o_air";
            _trackMarker setMarkerColor "ColorEAST";
            _trackMarker setMarkerText (getText (configFile >> "CfgVehicles" >> _class >> "displayName"));
        };
        _trackMarker setMarkerPos (getPosATL _veh);
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_destroyair_track"] remoteExec ["fnc_duws_dialogue", 0];
        _nextReportAt = time + (150 + random 60);
    };
    false
};

if (_trackMarker != "") then { deleteMarker _trackMarker };

if (_outcome == "WIN") then {
    [_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_destroyair_end"], true] call fnc_mission_finish;
} else {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker]] call fnc_mission_finish;
};
