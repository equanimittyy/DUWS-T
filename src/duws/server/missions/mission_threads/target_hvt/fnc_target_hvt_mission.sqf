// Locality: server -- callers remoteExec to target 2.
//
// Convoy hunt. An HVT flees to an OPFOR-held zone in one of three armed road convoys, each on its own
// approach; exactly one carries him in a single unarmed car -- the odd hull among armed escorts, its type
// named to the player -- so the hunt is to spot the right column and stop it before it arrives. Win: the
// HVT dies. Fail: his car reaches the zone, or the deadline passes.
//
// Off the fnc_mission_run spine on purpose: the win is a race, not a one-shot predicate polled at a fixed
// spot (see that header), so this owns its site pick, spawn and monitor like the informant hunt and IDAP run.
params ["_MissionPos", "_mission_name"];
if (!([2, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// Destination: the OPFOR-held haven the convoys flee to, from the spawn via fnc_hvt_dest_pick (nearest held
// zone 3-10 km out, corridor crossing no water, clear of BLUFOR ground). The spawn is the offer point the
// site-finder ejected 3-10 km from a zone (fnc_target_hvt_site), so the map icon is the column start and the
// haven a real zone the far side. The site-finder proved one reachable, so this normally succeeds; only an
// AO that flipped between offer and accept (haven captured, or friendly ground advanced across the corridor)
// leaves none -> abort, releasing gate and slot.
private _dest = [_MissionPos] call fnc_hvt_dest_pick;
if (_dest isEqualTo []) exitWith {
    [2, "STR_DUWS_T_crtzxs0j", "dest_zone_missing: no OPFOR-held zone 3 km+ out with a clean corridor"] call fnc_mission_abort;
};
private _destPos = _dest select 0;
private _destName = _dest select 1;

// The convoys start spread across the area, each on its own road, then run to the zone via a divergent
// mid-route point so the approaches split and the player cannot cover them all. TUNABLE: spawnR the radius
// the three start roads are drawn from; startSep the minimum gap between starts so each gets its own road;
// viaSpread the lateral offset of the mid-route point (bigger = wider fork); viaCone the widest a via road's
// run may sit off the destination bearing before it is skipped; startCone the same limit for a START road to
// count as route-aligned (preferred, so a column spawns down-route not perpendicular); arrive the zone-edge
// fail band.
private _spawnR    = 700;
private _viaSpread = 1200;
private _viaCone   = 45;
private _startCone = 40;
private _startSep  = 250;
private _arrive    = 80;

// Departure hold: fallback seconds the columns wait before rolling when no player reaches the start
// cluster, scaled inversely with run length -- a short run has little road to intercept on so waits the long
// _holdNear, a long run waits only _holdFar (the drive is the window). Same shape as deny-armour's repair race.
private _holdNear     = 75;
private _holdFar      = 25;
private _holdNearDist = 3000;
private _holdFarDist  = 10000;

// Escort class rolls per vehicle across armed car, IFV and armour, gated by OPFOR's earned Army Power via
// DUWS_fnc_tokenClass (low-AP fields cars, high can field tanks). Armed-car floor when the side has earned
// nothing, so a convoy is never unescorted.
private _escTokens = ["car", "ifv", "tank"] select { ([_x, "OPF"] call DUWS_fnc_tokenClass) != "" };
private _rollEsc = {
    if (_escTokens isEqualTo []) exitWith { opfor_ARMED_CAR1_X };
    private _c = [selectRandom _escTokens, "OPF"] call DUWS_fnc_tokenClass;
    if (_c == "") then { opfor_ARMED_CAR1_X } else { _c }
};

// The HVT rides an unarmed car of OPFOR's own faction (no turret, a few seats) so it reads as one of theirs,
// not a civilian giveaway, yet is the odd unarmed hull among armed escorts the player is told to find. The
// faction vocab names no such role, so CfgVehicles is scanned once for a Car-kind class the armed test
// clears; cached per faction (the scan is broad, the faction fixed for the session). No unarmed car -> an
// armed car, and the transport truck only if it names neither.
private _fac = getText (configFile >> "CfgVehicles" >> opfor_SOLDIER_X >> "faction");
private _cacheKey = format ["DUWS_hvtCarPool_%1", _fac];
private _carPool = missionNamespace getVariable [_cacheKey, []];
if (_carPool isEqualTo []) then {
    // Scope and faction filtered engine-side, so only this faction's public vehicles reach the SQF
    // loop -- a few dozen, not the whole CfgVehicles -- where the Car kind and the armed test decide.
    private _cond = format ["getNumber (_x >> 'scope') == 2 && {getText (_x >> 'faction') == '%1'}", _fac];
    private _cars = [];
    {
        private _c = configName _x;
        if (_c isKindOf "Car" && {!([_c] call DUWS_fnc_classIsArmed)}) then {
            _cars pushBack [_c, 1 + getNumber (_x >> "transportSoldier")];
        };
    } forEach (_cond configClasses (configFile >> "CfgVehicles"));
    // Prefer the four-to-five-seat cars, then any unarmed faction car. Failing that -- a faction with no
    // unarmed car at all -- an armed car, and the transport truck only if even that is unnamed.
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

// One line of vehicles seated ON the precomputed drive route: fnc_convoy_slots spaces one road-facing slot
// per vehicle along it, so the hulls form a real column on the path they will drive, not a scatter. Route
// stashed on the group (DUWS_convoy_route0) for the driver's first leg; crews merged into one group so they
// move together. Returns [group, [vehicles]]. Loot on the crew so a searched body reads as this faction.
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

// Bearing from the mission area to the destination: the columns run toward it, each forking to a via point
// offset to one side. The 3-10 km run and clean corridor are guaranteed by the destination pick, so the
// spawn sits at the offered point and the columns just aim in.
private _dirZone = [_MissionPos, _destPos] call BIS_fnc_dirTo;
private _legHalf = (_MissionPos distance2D _destPos) * 0.5;

// A road segment's run as a compass bearing, from its direction to a connected road; an unconnected stub
// falls back to its object heading. Keeps a via snap on a road running along the route, not crossing it.
private _roadBearing = {
    params ["_road"];
    private _conn = roadsConnectedTo _road;
    if (_conn isEqualTo []) exitWith { direction _road };
    _road getDir (_conn select 0)
};
// Acute angle (0-90) between two bearings as undirected lines: a road and its reverse read the same, so via
// alignment is line-to-line. The +540 keeps the mod dividend positive -- SQF mod takes the dividend's sign,
// so a bare (a-b+180) would mis-wrap for a<b.
private _axisOffset = {
    params ["_a", "_b"];
    private _d = abs ((((_a - _b) + 540) mod 360) - 180);
    _d min (180 - _d)
};

// Three independent start roads, each [pos, heading toward the zone]. Prefer roads aligned with the route
// (within _startCone of the destination bearing) so a column spawns pointing down-range, not perpendicular
// onto a crossing road. Pass 1 takes aligned roads; pass 2 tops up from any nearby road (laid straight at
// the zone); pass 3 falls back to fanned safe-pos points where the corner is road-thin. Each new start sits
// _startSep from the others so columns do not share a road.
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
    // A road-thin, cluttered corner: findSafePos can find nothing and return the map origin, which would
    // seat a whole column out at sea. The shared safe-pos helper falls back to the raw offered point
    // (already _spawnR out on the run bearing, inside the area) so the start stays where the column belongs.
    private _cand = _MissionPos getPos [_spawnR, _dirZone + ([-45, 0, 45] select _lat)];
    _startRoads pushBack [[_cand, 250, 8] call fnc_convoy_safepos, _dirZone];
};

private _hvtIdx = floor random 3;
private _groups = [];         // one group per convoy, index-aligned with the roll-out and the claim
private _vias   = [];         // matching via point per convoy, index-aligned with _groups
private _convoyStarts = [];   // one per convoy, for exactly three start markers (no tell)
private _hvt = objNull;       // the target; split into his own CARELESS group on first contact
private _car = objNull;       // his unarmed car -- watched by the monitor to trigger that split
private _hvtColGrp = grpNull; // his column's group until the split
private _carGrp = grpNull;    // the car's own CARELESS group once it breaks away to run for the zone

for "_i" from 0 to 2 do {
    private _lat = [-1, 0, 1] select _i;
    (_startRoads select _i) params ["_start"];
    // Via: a road point offset to one side of the midpoint so the pathfinder routes this column its own way
    // in (centre column, lat 0, runs the direct line). Snap to the nearest road within _viaCone of the
    // destination bearing so the via never points back the wrong way at the fork; none aligned -> nearest
    // road, then raw point.
    private _vCand = (_MissionPos getPos [_legHalf, _dirZone]) getPos [abs _lat * _viaSpread, _dirZone + (90 * _lat)];
    private _vRoads = _vCand nearRoads 900;
    private _viaRoad = objNull;
    {
        if (([[_x] call _roadBearing, _dirZone] call _axisOffset) <= _viaCone) exitWith { _viaRoad = _x };
    } forEach _vRoads;
    if (isNull _viaRoad && {!(_vRoads isEqualTo [])}) then { _viaRoad = _vRoads select 0 };
    private _via = if (!isNull _viaRoad) then { getPosATL _viaRoad } else { _vCand };
    // Route the first leg (start -> this column's via) and seat the column ON it below, so the hulls are born
    // on the drive path in trail order and roll straight off it; the driver reuses this route for leg one
    // (DUWS_convoy_route0), the via being that leg's waypoint.
    private _route0 = [_start, _via] call fnc_convoy_path;
    _convoyStarts pushBack _start;

    if (_i == _hvtIdx) then {
        // HVT column: escorts front and back, the unarmed car between them on one road so it sits mid-column.
        // One group so escorts and car drive together; the monitor peels the car into its own CARELESS group
        // on first contact so it commits to the run rather than halting to fight -- the player must stop the
        // car, not just spook the column.
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
        // Keep the HVT in the car -- a commander on foot breaks the hunt; the player must stop the car, not
        // chase a runner. No single call holds an AI in, so three layers: lock (blocks the player and
        // boarding, NOT an AI getting out), setUnloadInCombat false (no cargo bail when the column goes
        // COMBAT), and a GetOut handler that reseats him if the engine ejects him anyway (a halted/disabled
        // car bails past the first two). Reseat only into a live car (a destroyed one lets the eject stand);
        // moveInCargo re-enters past the lock, which does not impede the AI driving.
        _car lock true;
        _car setUnloadInCombat [false, false];
        _hvt addEventHandler ["GetOutMan", {
            params ["_unit", "", "_veh"];
            if (alive _unit && {alive _veh}) then { _unit moveInCargo _veh };
        }];
        _hvt addHeadgear "H_Beret_blk";
        _hvt addMagazineGlobal "FileTopSecret";
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

if (isNull _hvt) exitWith {
    // The officer class never crewed -- an exotic faction naming no officer role. Bail rather than
    // leave a mission that can never be won.
    { private _g = _x; { deleteVehicle (vehicle _x); deleteVehicle _x } forEach units _g; deleteGroup _g } forEach _groups;
    [2, "STR_DUWS_T_crtzxs0j", "hvt_spawn_failed: no officer class"] call fnc_mission_abort;
};

{ [_x] call fnc_mission_claim } forEach _groups;

// Standing DEBUG trace (silent unless duws_log_level is 4) for the "killed the HVT, nothing happened"
// ambiguity -- three columns, one carries him. Column index and car id at spawn, the peel, and the outcome
// at teardown tell hitting a decoy apart from the officer surviving his car's destruction, from an RPT alone.
["DEBUG", "MISSION", format ["hvt debug: hvtIdx=%1 car=%2 carClass=%3 hvt=%4 starts=%5", _hvtIdx, netId _car, _hvtCarClass, netId _hvt, _convoyStarts]] call fnc_log;

// Search ellipse on the convoy start cluster (where the player is sent), with a fix on each start inside it.
// The starts are one-shot: nothing tracks the convoys live, or there would be no hunt. The destination is
// marked separately below.
private _radius = 1500;
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

private _taskId = format ["hvtconvoy%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, format [localize "STR_DUWS_T_HVT_CONVOY_TASK", _destName, _vehName], _mission_name, _MissionPos, "kill"] call fnc_missionTaskCreate;
[localize "STR_DUWS_T_c2", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_hvtletsdothis", _destName, _vehName]] remoteExec ["fnc_duws_dialogue", 0];

// Departure gate: the columns hold at their start until a player reaches the convoy area (BLUFOR within the
// search radius) or the hold timer expires, whichever first -- the trigger starts the race on arrival, the
// timer is the fallback so they never sit forever. Then all columns are ordered to the zone via their own
// mid-route points at once, so the three take separate roads in.
private _holdMax = linearConversion [_holdNearDist, _holdFarDist, _MissionPos distance2D _destPos, _holdNear, _holdFar, true];
private _holdUntil = time + _holdMax;
// The outcome can resolve during the hold, before the columns ever move: the player can kill the HVT in his
// held car (WIN), or the mission deadline can pass with the convoy still parked (TIMEOUT). Declared here (not
// after the departure) so the gate and the monitor write the same variable, and a hold-phase result skips
// ordering the columns out and the monitor below.
private _outcome = "";
waitUntil {
    sleep 1;
    if (!alive _hvt) exitWith { _outcome = "WIN"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
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
    // Self-routing convoy driver per column, once rolling: it computes the road route and every hull drives it
    // holding spacing, so no follower wedges cutting its corner into the zone. Orders each column onto its crumb
    // in trail order at spawn (the hulls are laid in a rough line, not already trailing). Spawned only now, after
    // the grace hold, so it does not drive the columns sitting still. Ended at teardown via DUWS_convoy_stop.
    { [_x] spawn fnc_convoy_drive } forEach _groups;
    // Allseer calls the move the instant the columns are ordered out, so the player reads the race as
    // starting rather than watching for it.
    [localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_hvtmoveout", _destName]] remoteExec ["fnc_duws_dialogue", 0];
};

private _split = false;
// Midpoint intel: a rolled 30-60 s hold after the columns move, then Allseer names their mid-route points
// and drops an arrow on each pointing at the destination, so the player reads where the routes bend and can
// cut one short. Run in the monitor, not a side thread, so a kill or arrival before the reveal leaves
// _viaMarkers empty and teardown deletes nothing.
private _viaMarkers = [];
private _revealAt = time + (30 + round random 30);
private _revealed = false;
// Allseer's running track: at a rolled cadence (first call ~2-3 min after the push, clear of the move-out
// and midpoint lines) it moves a convoy symbol onto each column and calls a generic line. The symbols
// persist at their last-reported spot and jump on each update -- a periodic fix, not a continuous blip, so
// the intercept stays the player's. One marker per column, index-aligned with _groups, "" until placed and
// reset to "" if wiped; the peeled HVT car gets its own marker at breakaway (below), on the same cadence.
private _nextReportAt  = time + (120 + round random 60);
private _trackMarkers  = ["", "", ""];
private _hvtMarker     = "";
waitUntil {
    if (_outcome != "") exitWith { true };   // resolved during the hold; nothing to monitor, tear down now
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
            _mn setMarkerDir (_x getDir _destPos);   // arrow on the midpoint, heading into the zone
            _mn setMarkerSize [1.1, 1.1];
            _mn setMarkerAlpha 0.8;
            _viaMarkers pushBack _mn;
        } forEach _vias;
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_hvtmidpoint"] remoteExec ["fnc_duws_dialogue", 0];
    };
    // At the cadence, move a symbol onto each live column and, once he has peeled, the HVT marker onto his
    // car, then call a generic line. The symbol tracks the column's lead (cv_lead); a jammed hull's cv_lead
    // may be a corpse (leadership migrates on death before the drive loop re-pins it), so fall back to the
    // first live drivable hull. A destroyed column drops its marker. Marker commands are global from server.
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
    // First contact: peel the car into its own CARELESS group so it runs for the zone instead of halting to
    // fight with the escorts. Gated on a real BLUFOR threat within 300 m of the car, so a convoy fender-bender
    // (which raises damage and can chain into a collision explosion) does not spuriously launch it; then
    // triggered by the column going COMBAT or the car taking a hit. Crew keep their claim stamp, so
    // teardown collects them.
    if (!_split && alive _car
        && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D _car < 300} }) >= 0}
        && {
            (!isNull _hvtColGrp && {count units _hvtColGrp > 0} && {behaviour (leader _hvtColGrp) == "COMBAT"})
            || damage _car > 0
        }) then {
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
        // Hand the car to native AI: as a lone run-away it must flee CARELESS at full speed on its own
        // waypoint. The column driver dropped it when its driver joined _carGrp but only reverses its per-hull
        // control at its own teardown, so the stale path and the forced convoy cruise (which the player could
        // otherwise walk down) must be lifted explicitly here.
        [_car] call fnc_convoy_release_hull;
        // He has committed to his own run, so Allseer calls him out by name and drops a dedicated HVT marker
        // on the car (moved on each update). This is the reveal the hunt built to: the player now knows
        // which hull is his.
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
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
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
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_hvtend"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;
    sleep 1;
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
} else {
    if (_outcome == "ESCAPED") then {
        [[_destName], { params ["_z"]; hint format [localize "STR_DUWS_T_HVT_CONVOY_ESCAPED", _z] }] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    } else {
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_HVT_CONVOY_TIMEOUT"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    };
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
};

[_destPos, _radius] call fnc_mission_end;
