// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([2, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _deadline = DUWS_curDeadlineAt;

// fnc_hvt_dest_pick already proved a reachable OPFOR-held haven (3-10 km out, clear corridor) at offer time.
// Empty here means the AO flipped since (haven captured, or friendly ground crossed the corridor) -> abort.
private _dest = [_MissionPos] call fnc_hvt_dest_pick;
if (_dest isEqualTo []) exitWith {
    [2, _requester, "dest_zone_missing: no OPFOR-held zone 3 km+ out with a clean corridor"] call fnc_mission_abort;
};
private _destPos = _dest select 0;
private _destName = _dest select 1;

// Convoys start spread on separate roads and fork at a mid-route point, so the player cannot cover all three.
private _spawnR    = 400;   // plus the 250 m fallback settle, stays inside _radius so every start sits in the search ellipse
private _viaSpread = 1200;
private _viaCone   = 45;
private _startCone = 40;
private _startSep  = 250;
private _arrive    = 80;

// Hold scales inversely with run length: a short run has little road to intercept, so it waits longer
// (_holdNear); a long run waits only _holdFar, since the drive itself is the window.
private _holdNear     = 75;
private _holdFar      = 25;
private _holdNearDist = 3000;
private _holdFarDist  = 10000;

// Escort tier is gated by OPFOR's earned Army Power (low AP fields cars, high can field tanks); armed-car
// floor when nothing is earned, so a convoy is never unescorted.
private _escTokens = ["car", "ifv", "tank"] select { ([_x, "OPF"] call DUWS_fnc_tokenClass) != "" };
private _rollEsc = {
    if (_escTokens isEqualTo []) exitWith { opfor_ARMED_CAR1_X };
    private _c = [selectRandom _escTokens, "OPF"] call DUWS_fnc_tokenClass;
    if (_c == "") then { opfor_ARMED_CAR1_X } else { _c }
};

// HVT rides the odd unarmed car among armed escorts, the tell. No named unarmed-car role in the faction
// vocab, so CfgVehicles is scanned once per faction and cached; falls back to armed car, then transport truck.
private _fac = getText (configFile >> "CfgVehicles" >> opfor_SOLDIER_X >> "faction");
private _cacheKey = format ["DUWS_hvtCarPool_%1", _fac];
private _carPool = missionNamespace getVariable [_cacheKey, []];
if (_carPool isEqualTo []) then {
    // Scope/faction filtered engine-side, so only this faction's public vehicles (a few dozen) reach the loop.
    private _cond = format ["getNumber (_x >> 'scope') == 2 && {getText (_x >> 'faction') == '%1'}", _fac];
    private _cars = [];
    {
        private _c = configName _x;
        if (_c isKindOf "Car" && {!([_c] call DUWS_fnc_classIsArmed)}) then {
            _cars pushBack [_c, 1 + getNumber (_x >> "transportSoldier")];
        };
    } forEach (_cond configClasses (configFile >> "CfgVehicles"));
    _carPool = (_cars select { (_x select 1) >= 4 && (_x select 1) <= 6 }) apply { _x select 0 };
    if (_carPool isEqualTo []) then { _carPool = _cars apply { _x select 0 } };
    if (_carPool isEqualTo []) then {
        private _fallback = opfor_ARMED_CAR1_X;
        if (_fallback == "") then { _fallback = opfor_TRANS_TRUCK_X };
        _carPool = [_fallback];
    };
    missionNamespace setVariable [_cacheKey, _carPool];
    ["INFO", "MISSION", format ["hvt convoy: %1 unarmed cars for faction %2", count _carPool, _fac]] call fnc_log;
};
private _hvtCarClass = selectRandom _carPool;
private _vehName = getText (configFile >> "CfgVehicles" >> _hvtCarClass >> "displayName");

private _taskId = format ["hvtconvoy%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// fnc_convoy_slots seats one road-facing slot per vehicle along the route so hulls form a real column, not
// a scatter. Route stashed on the group for the driver's first leg; loot on crew so a search reads this faction.
private _spawnLine = {
    params ["_classes", "_route", "_behaviour", "_speed"];
    private _slots = [_route, count _classes, 22] call fnc_convoy_slots;
    private _grp = createGroup EAST;
    private _vehs = [];
    {
        (_slots select _forEachIndex) params ["_sp", "_sd"];
        _sp = [_sp, _x] call fnc_convoy_fit;
        private _r = [_sp, _sd, _x, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _sd;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    } forEach _classes;
    _grp setBehaviour _behaviour;
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode _speed;
    _grp setFormation "COLUMN";
    _grp deleteGroupWhenEmpty true;
    _grp setVariable ["DUWS_convoy_route0", _route];
    { [_x] call fnc_addRandomLoot } forEach units _grp;
    [_grp, _vehs]
};

// Destination pick already guarantees the 3-10 km run and a clean corridor, so the spawn just sits at the
// offered point and the columns aim straight in.
private _dirZone = [_MissionPos, _destPos] call BIS_fnc_dirTo;
private _legHalf = (_MissionPos distance2D _destPos) * 0.5;

// Bearing from a connected road, not object heading, so a via snap aligns along the route, not across it.
private _roadBearing = {
    params ["_road"];
    private _conn = roadsConnectedTo _road;
    if (_conn isEqualTo []) exitWith { direction _road };
    _road getDir (_conn select 0)
};
// Undirected angle (0-90): a road and its reverse read the same. The +540 keeps the mod dividend positive --
// SQF mod takes the dividend's sign, so a bare (a-b+180) would mis-wrap for a<b.
private _axisOffset = {
    params ["_a", "_b"];
    private _d = abs ((((_a - _b) + 540) mod 360) - 180);
    _d min (180 - _d)
};

// Three-pass fallback (route-aligned road -> any nearby road -> safe-pos point) guarantees three start roads
// even where alignment or road density fails, _startSep apart so columns never share one.
private _startRoads = [];
private _near = _MissionPos nearRoads _spawnR;
{
    private _rp = getPosATL _x;
    private _rb = [_x] call _roadBearing;
    if (
        ([_rb, _dirZone] call _axisOffset) <= _startCone
        && {(_startRoads findIf { _rp distance2D (_x select 0) < _startSep }) < 0}
    ) then {
        // The run is undirected; point it at the zone (the end within 90 deg of the destination bearing).
        private _hd = if ((abs ((((_rb - _dirZone) + 540) mod 360) - 180)) <= 90) then { _rb } else { (_rb + 180) mod 360 };
        _startRoads pushBack [_rp, _hd];
    };
    if (count _startRoads >= 3) exitWith {};
} forEach _near;
{
    private _rp = getPosATL _x;
    if ((_startRoads findIf { _rp distance2D (_x select 0) < _startSep }) < 0) then { _startRoads pushBack [_rp, _dirZone] };
    if (count _startRoads >= 3) exitWith {};
} forEach _near;
while { count _startRoads < 3 } do {
    private _lat = count _startRoads;
    // findSafePos can return the map origin in a road-thin, cluttered corner, seating a column out at sea.
    // fnc_safe_pos falls back to the raw offered point so the start stays where it belongs.
    private _cand = _MissionPos getPos [_spawnR, _dirZone + ([-45, 0, 45] select _lat)];
    _startRoads pushBack [[_cand, 250, 0, 8] call fnc_safe_pos, _dirZone];
};

private _hvtIdx = floor random 3;
private _groups = []; // index-aligned with _vias and _convoyStarts throughout
private _vias   = [];
private _convoyStarts = []; // three start markers, so the HVT's column is never singled out
private _hvt = objNull;
private _car = objNull;
private _hvtColGrp = grpNull;
private _carGrp = grpNull;

for "_i" from 0 to 2 do {
    private _lat = [-1, 0, 1] select _i;
    (_startRoads select _i) params ["_start"];
    // Via point offset to one side of the midpoint so each column takes its own way in (centre column runs
    // direct); snapped to a road within _viaCone of the destination bearing so it never points the wrong way.
    private _vCand = (_MissionPos getPos [_legHalf, _dirZone]) getPos [abs _lat * _viaSpread, _dirZone + (90 * _lat)];
    private _vRoads = _vCand nearRoads 900;
    private _viaRoad = objNull;
    {
        if (([[_x] call _roadBearing, _dirZone] call _axisOffset) <= _viaCone) exitWith { _viaRoad = _x };
    } forEach _vRoads;
    if (isNull _viaRoad && {!(_vRoads isEqualTo [])}) then { _viaRoad = _vRoads select 0 };
    private _via = if (!isNull _viaRoad) then { getPosATL _viaRoad } else { _vCand };
    // Column is seated directly on this route, so hulls spawn already in trail order instead of scattered.
    // The driver reuses it as DUWS_convoy_route0 for leg one, with the via as that leg's waypoint.
    private _route0 = [_start, _via] call fnc_convoy_path;
    _convoyStarts pushBack _start;

    if (_i == _hvtIdx) then {
        // HVT column: escorts front/back, unarmed car mid-column on one road -- the tell. Single group at spawn;
        // the monitor peels the car into its own CARELESS group on first contact so it commits to the run
        // instead of halting to fight, forcing the player to stop the car itself, not just spook the column.
        private _slots = [_route0, 3, 22] call fnc_convoy_slots;
        _hvtColGrp = createGroup EAST;
        {
            (_slots select _x) params ["_sp", "_sd"];
            private _ec = call _rollEsc;
            _sp = [_sp, _ec] call fnc_convoy_fit;
            private _r = [_sp, _sd, _ec, EAST] call BIS_fnc_spawnVehicle;
            (_r select 0) setDir _sd;
            (_r select 2) deleteGroupWhenEmpty true;
            (_r select 1) joinSilent _hvtColGrp;
        } forEach [0, 2];
        (_slots select 1) params ["_cp", "_cd"];
        _cp = [_cp, _hvtCarClass] call fnc_convoy_fit;
        _car = createVehicle [_hvtCarClass, _cp, [], 0, "NONE"];
        _car setDir _cd;
        private _driver = _hvtColGrp createUnit [opfor_SOLDIER_X, _cp, [], 0, "NONE"];
        _driver moveInDriver _car;
        _hvt = _hvtColGrp createUnit [opfor_OFFICER_X, _cp, [], 0, "NONE"];
        _hvt moveInCargo _car;
        // Keep the HVT in the car -- a commander on foot breaks the hunt. No single call holds an AI in, so
        // three layers: lock (blocks the player, not an AI exit), setUnloadInCombat false (no bail on COMBAT),
        // and a GetOut handler that reseats him into a live car if the engine ejects him anyway (a destroyed
        // car lets the eject stand). moveInCargo re-enters past the lock without impeding the driver.
        _car lock true;
        _car setUnloadInCombat [false, false];
        _hvt addEventHandler ["GetOutMan", {
            params ["_unit", "", "_veh"];
            if (alive _unit && {alive _veh}) then { _unit moveInCargo _veh };
        }];
        _hvt addHeadgear "H_Beret_blk";
        // SAFE so the column cruises relaxed; the engine promotes it to COMBAT natively on contact, which is
        // what the monitor's peel reads (behaviour == COMBAT) to break the car away and send it running.
        _hvtColGrp setBehaviour "SAFE";
        _hvtColGrp setCombatMode "YELLOW";
        _hvtColGrp setSpeedMode "LIMITED";
        _hvtColGrp setFormation "COLUMN";
        _hvtColGrp deleteGroupWhenEmpty true;
        _hvtColGrp setVariable ["DUWS_convoy_route0", _route0];
        { [_x] call fnc_addRandomLoot } forEach units _hvtColGrp;
        _groups pushBack _hvtColGrp;
        _vias pushBack _via;
    } else {
        ([[call _rollEsc, call _rollEsc, call _rollEsc], _route0, "SAFE", "LIMITED"] call _spawnLine) params ["_grp"];
        _groups pushBack _grp;
        _vias pushBack _via;
    };
};

// Claim the columns before the spawn-check so an abort's token sweep bins them: fnc_mission_claim stamps
// each with this mission's token, and fnc_mission_abort tears down by that token.
{ [_x] call fnc_mission_claim } forEach _groups;

if (isNull _hvt) exitWith {
    // The officer class never crewed -- an exotic faction naming no officer role. Bail rather than leave a
    // mission that can never be won; the claimed columns go to the sweep through the abort's token teardown.
    [2, _requester, "hvt_spawn_failed: no officer class"] call fnc_mission_abort;
};

// DEBUG trace (only at duws_log_level 4) resolves the "killed the HVT, nothing happened" ambiguity: with one
// of three columns carrying him, index/car id at spawn plus the peel and outcome tell a decoy hit apart from the officer surviving his car's destruction, from an RPT alone.
["DEBUG", "MISSION", format ["hvt debug: hvtIdx=%1 car=%2 carClass=%3 hvt=%4 starts=%5", _hvtIdx, netId _car, _hvtCarClass, netId _hvt, _convoyStarts]] call fnc_log;

[_taskId, format [localize "STR_DUWS_T_HVT_CONVOY_TASK", _destName, _vehName], _mission_name, _MissionPos, "kill"] call fnc_missionTaskCreate;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_hvtletsdothis", _destName, _vehName]] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_hvtcopy"] remoteExec ["fnc_duws_dialogue", 0];

// Search ellipse over the convoy start cluster (where the player is sent), with a fixed marker per start --
// one-shot, since nothing tracks the convoys live, or there would be no hunt.
private _radius = 800;
private _marker = [_MissionPos, _radius] call fnc_missionMarkerData;
private _startMarkers = [];
{
    private _mn = format ["hvtconvoy_%1_%2", round (_x select 0), round (_x select 1)];
    deleteMarker _mn;   // a rounded-position name can collide with a prior mission's leftover
    createMarker [_mn, _x];
    _mn setMarkerShape "ICON";
    _mn setMarkerType "mil_arrow";
    _mn setMarkerColor "ColorEAST";
    // Points the way this column drives off the start -- its heading toward its own via point, so the
    // player reads the three routes apart and picks one to run down.
    _mn setMarkerDir (_x getDir (_vias select _forEachIndex));
    _mn setMarkerSize [1.1, 1.1];
    _mn setMarkerAlpha 0.8;
    _mn setMarkerText "Convoy";
    _startMarkers pushBack _mn;
} forEach _convoyStarts;

// The safe-haven zone the convoys run for, marked so the player reads the direction of the race and can cut
// a column off short of it. Rounded-position marker name, cleared with the rest at mission end.
private _destMarker = format ["hvtconvoydest_%1_%2", round (_destPos select 0), round (_destPos select 1)];
deleteMarker _destMarker;
createMarker [_destMarker, _destPos];
_destMarker setMarkerShape "ICON";
_destMarker setMarkerType "mil_end";
_destMarker setMarkerColor "ColorEAST";
_destMarker setMarkerText "Destination";

// Departure gate: columns hold until BLUFOR enters the search radius or the hold timer runs out, whichever
// comes first, so they never sit forever waiting for the player. Then ordered out together via their own mid-route points, so the three take separate roads in.
private _holdMax = linearConversion [_holdNearDist, _holdFarDist, _MissionPos distance2D _destPos, _holdNear, _holdFar, true];
private _holdUntil = time + _holdMax;
// Outcome can resolve during the hold, before the columns ever move: HVT killed in his parked car (WIN), or
// the deadline passing with the convoy still parked (TIMEOUT). Declared here, not after departure, so the
// gate and the monitor below share the same variable, and a hold-phase result skips the drive-out and the monitor entirely.
private _outcome = "";
waitUntil {
    sleep 1;
    if (!alive _hvt) exitWith { _outcome = "WIN"; true };
    if ([_deadline] call fnc_time_expired) exitWith { _outcome = "TIMEOUT"; true };
    (time > _holdUntil) || {[_MissionPos, _radius] call fnc_duws_bluforNear}
};
// Skipped when the hold already resolved the mission (HVT killed in his parked car, or the deadline passed):
// the columns must not move, and the monitor below early-exits, so teardown runs straight away.
if (_outcome == "") then {
    {
        private _via = _vias select _forEachIndex;
        private _wpVia = _x addWaypoint [_via, 0];
        _wpVia setWaypointType "MOVE";
        _wpVia setWaypointCompletionRadius 60;
        private _wpEnd = _x addWaypoint [_destPos, 0];
        _wpEnd setWaypointType "MOVE";
        _wpEnd setWaypointCompletionRadius 40;
    } forEach _groups;
    // Self-routing driver per column: computes the road route and holds spacing so no follower wedges cutting
    // its corner into the zone. Spawned only now, after the grace hold, so it never drives columns still parked;
    // stopped at teardown via DUWS_convoy_stop.
    { [_x] spawn fnc_convoy_drive } forEach _groups;
    // Allseer calls the move the instant the columns are ordered out, so the player reads the race as
    // starting rather than watching for it.
    [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_hvtmoveout", _destName]] remoteExec ["fnc_duws_dialogue", 0];
};

private _split = false;
// Midpoint intel: after a rolled 30-60s hold, Allseer marks each via point so the player reads where the
// routes bend and can cut one short. Run in the monitor, not a side thread, so an early kill or arrival leaves _viaMarkers empty and teardown deletes nothing.
private _viaMarkers = [];
private _revealAt = time + (30 + round random 30);
private _revealed = false;
// Allseer's running track: at a rolled cadence, jumps a symbol onto each column -- a periodic fix, not
// continuous tracking, so the intercept stays the player's. _trackMarkers is index-aligned with _groups, "" until placed; the peeled HVT car gets its own marker (below).
private _nextReportAt  = time + (120 + round random 60);
private _trackMarkers  = ["", "", ""];
private _hvtMarker     = "";
waitUntil {
    if (_outcome != "") exitWith { true };
    sleep 2;
    if (!_revealed && {time > _revealAt}) then {
        _revealed = true;
        {
            private _mn = format ["hvtconvoyvia_%1_%2", round (_x select 0), round (_x select 1)];
            deleteMarker _mn;   // a rounded-position name can collide with a prior mission's leftover
            createMarker [_mn, _x];
            _mn setMarkerShape "ICON";
            _mn setMarkerType "mil_arrow";
            _mn setMarkerColor "ColorEAST";
            _mn setMarkerDir (_x getDir _destPos);
            _mn setMarkerSize [1.1, 1.1];
            _mn setMarkerAlpha 0.8;
            _viaMarkers pushBack _mn;
        } forEach _vias;
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_hvtmidpoint"] remoteExec ["fnc_duws_dialogue", 0];
    };
    // Symbol tracks the column's lead (cv_lead); a jammed hull's cv_lead may be a corpse (leadership migrates
    // on death before the drive loop re-pins it), so fall back to the first live drivable hull. Marker commands are global from server.
    if (time > _nextReportAt) then {
        {
            private _grp = _x;
            private _i   = _forEachIndex;
            private _lead = _grp getVariable ["cv_lead", objNull];
            if (isNull _lead || {!alive _lead}) then {
                _lead = objNull;
                { private _v = vehicle _x; if (_v != _x && {alive _v} && {canMove _v}) exitWith { _lead = _v } } forEach units _grp;
            };
            private _mn = _trackMarkers select _i;
            if (isNull _lead) then {
                if (_mn != "") then { deleteMarker _mn; _trackMarkers set [_i, ""] };
            } else {
                if (_mn == "") then {
                    _mn = format ["hvtconvoytrk_%1_%2", _taskId, _i];
                    deleteMarker _mn;   // a reused mission name can collide with a prior run's leftover
                    createMarker [_mn, getPosATL _lead];
                    _mn setMarkerType "o_motor_inf";
                    _mn setMarkerColor "ColorEAST";
                    _mn setMarkerText "Convoy";
                    _trackMarkers set [_i, _mn];
                };
                _mn setMarkerPos (getPosATL _lead);
            };
        } forEach _groups;
        if (_split && {_hvtMarker != ""} && {alive _car}) then { _hvtMarker setMarkerPos (getPosATL _car) };
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_hvttrack"] remoteExec ["fnc_duws_dialogue", 0];
        _nextReportAt = time + (120 + round random 60);
    };
    // Peels the car into its own CARELESS group on first real contact (BLUFOR within 300 m, so a convoy
    // fender-bender doesn't trigger it) rather than halting to fight; crew keep their original claim stamp for teardown.
    if (!_split && alive _car
        && {
            (!isNull _hvtColGrp && {count units _hvtColGrp > 0} && {behaviour (leader _hvtColGrp) == "COMBAT"})
            || damage _car > 0
        }
        && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D _car < 300} }) >= 0}) then {
        _split = true;
        ["DEBUG", "MISSION", format ["hvt debug: car split (carDmg=%1 hvtAlive=%2)", damage _car, alive _hvt]] call fnc_log;
        _carGrp = createGroup EAST;
        [_hvt, driver _car] joinSilent _carGrp;
        _carGrp setBehaviour "CARELESS";
        _carGrp setSpeedMode "FULL";
        _carGrp deleteGroupWhenEmpty true;
        private _wp = _carGrp addWaypoint [_destPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 40;
        // Hands the car to native AI so it can flee CARELESS at full speed on its own waypoint. The convoy
        // driver only reverses its per-hull control at its own teardown, so without this call the car would
        // keep crawling at the forced convoy cruise -- slow enough for the player to just walk it down.
        [_car] call fnc_convoy_release_hull;
        // The reveal the hunt is built around: only once he's committed to his own run does Allseer call him
        // out by name and mark the car, so the player finally knows which hull is his.
        _hvtMarker = format ["hvtconvoyhvt_%1", _taskId];
        deleteMarker _hvtMarker;   // a reused mission name can collide with a prior run's leftover
        createMarker [_hvtMarker, getPosATL _car];
        _hvtMarker setMarkerType "mil_warning";
        _hvtMarker setMarkerColor "ColorEAST";
        _hvtMarker setMarkerText "HVT";
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_hvtflee"] remoteExec ["fnc_duws_dialogue", 0];
    };
    if (!alive _hvt) exitWith { _outcome = "WIN"; true };
    if (_hvt distance2D _destPos < _arrive) exitWith { _outcome = "ESCAPED"; true };
    if ([_deadline] call fnc_time_expired) exitWith { _outcome = "TIMEOUT"; true };
    false
};

["DEBUG", "MISSION", format ["hvt debug: outcome=%1 hvtAlive=%2 carAlive=%3 carDmg=%4", _outcome, alive _hvt, alive _car, damage _car]] call fnc_log;

// End every convoy watchdog. Only the column groups run one; the peeled car was released to native AI at
// breakaway (no driver on _carGrp), so it needs no stop.
{ _x setVariable ["DUWS_convoy_stop", true] } forEach _groups;

[_marker] call fnc_missionMarkerClear;
{ deleteMarker _x } forEach _startMarkers;
{ deleteMarker _x } forEach _viaMarkers;
{ if (_x != "") then { deleteMarker _x } } forEach _trackMarkers;
if (_hvtMarker != "") then { deleteMarker _hvtMarker };
deleteMarker _destMarker;

if (_outcome == "WIN") then {
    [_mission_name, _taskId, "SUCCEEDED", _destPos, _radius, [], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hvtend"], true] call fnc_mission_finish;
} else {
    // ESCAPED speaks its own hint (the haven the HVT reached); TIMEOUT falls back to finish's generic notice.
    if (_outcome == "ESCAPED") then {
        [[_destName], { params ["_z"]; hint format [localize "STR_DUWS_T_HVT_CONVOY_ESCAPED", _z] }] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    };
    [_mission_name, _taskId, "FAILED", _destPos, _radius, [], [], false, "", false, (_outcome != "ESCAPED")] call fnc_mission_finish;
};
