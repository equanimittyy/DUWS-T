// Locality: server -- callers remoteExec to target 2.
//
// Convoy hunt. A high-value target flees to an OPFOR-held zone in one of three armed road convoys,
// each on its own approach. Exactly one convoy carries the HVT in a single unarmed car -- the odd hull
// among the armed escorts, its type named to the player -- so the mission is to spot the right column
// and stop it before it arrives. Win: the HVT dies. Fail: his car reaches the zone, or the deadline
// passes.
//
// Off the fnc_mission_run spine on purpose: the win is a race, not a one-shot predicate polled at a
// fixed spot (see fnc_mission_run's header), so this owns its own site pick, spawn and monitor the
// way the informant hunt and the IDAP escort do.
params ["_MissionPos", "_mission_name"];
if (!([2, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// Destination: the OPFOR-held zone nearest the sited position -- the safe haven the convoys run for.
// Matched by position against WARCOM_zones_controled_by_OPFOR the way the informant hunt picks its
// escape zone. None held (the last fell between offer and start) -> abort, releasing gate and slot.
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _destPos = [];
private _destName = "";
private _destD = 1e9;
{
    _x params ["_zn", "_zp"];
    if ((_enemyZones findIf { _x distance2D _zp < 50 }) >= 0 && {(_zp distance2D _MissionPos) < _destD}) then {
        _destD = _zp distance2D _MissionPos; _destPos = _zp; _destName = _zn;
    };
} forEach zone_namePOS_pairs;
if (_destPos isEqualTo []) exitWith {
    [2, "STR_DUWS_T_crtzxs0j", "dest_zone_missing: no OPFOR-held zone to run the convoy to"] call fnc_mission_abort;
};

// The convoys start bunched in the mission area on a small radius, then fork onto three separate
// roads to the zone, each via a divergent mid-route point, so the approaches split and the player
// cannot cover them all. TUNABLE: spawnR is the start cluster's radius, viaSpread the lateral offset
// that pushes the three columns onto different roads (bigger = wider fork), startSep the minimum gap
// between two starts so no two columns snap to the same road, graceSec the rolled hold the columns
// keep at their start before they roll -- Allseer calls the move when it ends -- arrive is the
// zone-edge fail band.
private _spawnR    = 425;
private _viaSpread = 1200;
private _startSep  = 200;
private _graceSec  = 30 + round random 30;
private _arrive    = 80;

// Escort classes roll per vehicle across armed car, IFV and armour, gated by OPFOR's earned Army
// Power through DUWS_fnc_tokenClass -- a low-AP campaign fields cars, a high one can field tanks. The
// armed car is the floor when the side has earned nothing yet, so a convoy is never unescorted.
private _escTokens = ["car", "ifv", "tank"] select { ([_x, "OPF"] call DUWS_fnc_tokenClass) != "" };
private _rollEsc = {
    if (_escTokens isEqualTo []) exitWith { opfor_ARMED_CAR1_X };
    private _c = [selectRandom _escTokens, "OPF"] call DUWS_fnc_tokenClass;
    if (_c == "") then { opfor_ARMED_CAR1_X } else { _c }
};

// The HVT rides an unarmed car of OPFOR's own faction -- no turret weapon, a handful of seats -- so it
// reads as one of theirs, not a civilian giveaway, yet is the odd unarmed hull among armed escorts and
// the thing the player is told to look for. The faction vocab names no such role, so its CfgVehicles is
// scanned once for a Car-kind class the armed test (the reserve trucks' own) clears; cached per faction,
// since the scan is broad and the faction is fixed for the session. A faction with no unarmed car falls
// back to an armed car, and the transport truck only if it names neither.
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

// One line of vehicles as a road column, crews merged into a single group so they move together.
// Returns [group, [vehicles]]. Loot on the crew so a searched body reads as this faction like any
// patrol.
private _spawnLine = {
    params ["_classes", "_start", "_heading", "_behaviour", "_speed"];
    private _grp = createGroup EAST;
    private _vehs = [];
    {
        private _p = [_start getPos [_forEachIndex * 18, _heading + 180]] call _onRoad;
        private _r = [_p, _heading, _x, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _heading;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    } forEach _classes;
    _grp setBehaviour _behaviour;
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode _speed;
    _grp setFormation "COLUMN";
    _grp deleteGroupWhenEmpty true;
    { [_x] call fnc_addRandomLoot } forEach units _grp;
    [_grp, _vehs]
};

// Snap a lined-up column slot onto the road beneath it, so the whole column sits on tarmac and not just
// the lead vehicle -- a hull spawned in the ditch fights the pathfinder before it even rolls. Only the
// road under the slot, close in: the start is already on a road, so this shifts each following slot a
// few metres onto that same segment rather than hunting a distant one. No road near (the roadless-start
// fallback) keeps the raw slot.
private _onRoad = {
    params ["_p"];
    private _r = _p nearRoads 30;
    if (count _r > 0) then { getPosATL (_r select 0) } else { _p }
};

// Bearing from the mission area to the destination: the columns spawn fanned around it and each
// forks to a via point offset to one side of it.
private _dirZone = [_MissionPos, _destPos] call BIS_fnc_dirTo;
private _legHalf = (_MissionPos distance2D _destPos) * 0.5;

private _hvtIdx = floor random 3;
private _groups = [];         // one group per convoy, index-aligned with the roll-out and the claim
private _groupVehs = [];      // matching vehicle list per convoy, for the reliability layer + watchdog
private _vias   = [];         // matching via point per convoy, index-aligned with _groups
private _convoyStarts = [];   // one per convoy, for exactly three start markers (no tell)
private _hvt = objNull;       // the target; split into his own CARELESS group on first contact
private _car = objNull;       // his unarmed car -- watched by the monitor to trigger that split
private _hvtColGrp = grpNull; // his column's group until the split
private _carGrp = grpNull;    // the car's own group once split out -- held here so teardown ends its watchdog

for "_i" from 0 to 2 do {
    private _lat = [-1, 0, 1] select _i;
    // Start: bunched in the mission area, fanned off the zone bearing so each column searches its own
    // arc, then snapped to the nearest road at least _startSep from every start already placed -- so no
    // two columns share a segment and spawn stacked. A road-dense area with nothing far enough falls
    // back to the nearest road; a convoy off the network fights the pathfinder the whole way.
    private _sCand = _MissionPos getPos [_spawnR, _dirZone + (_lat * 70)];
    private _sRoads = _sCand nearRoads 400;
    private _start = [];
    {
        private _rp = getPosATL _x;
        if (_convoyStarts findIf { _x distance2D _rp < _startSep } < 0) exitWith { _start = _rp };
    } forEach _sRoads;
    if (_start isEqualTo []) then {
        _start = if (count _sRoads > 0) then { getPosATL (_sRoads select 0) }
            else { [_sCand, 0, 120, 8, 0, 0.6, 0] call BIS_fnc_findSafePos };
    };
    // Via: a road point offset to one side of the midpoint, so the pathfinder routes this column its
    // own way in; the centre column (lat 0) runs the direct line. Snap to a road, else take the raw
    // point -- the pathfinder still favours roads getting there.
    private _vCand = (_MissionPos getPos [_legHalf, _dirZone]) getPos [abs _lat * _viaSpread, _dirZone + (90 * _lat)];
    private _vRoads = _vCand nearRoads 900;
    private _via = if (count _vRoads > 0) then { getPosATL (_vRoads select 0) } else { _vCand };
    private _heading = [_start, _via] call BIS_fnc_dirTo;
    _convoyStarts pushBack _start;

    if (_i == _hvtIdx) then {
        // One group so the escorts and the HVT's car drive together; the monitor peels the car into
        // its own CARELESS group on first contact so it commits to the run and drives through the
        // firefight rather than halting -- the player has to stop the car, not just spook the column.
        _hvtColGrp = createGroup EAST;
        private _hvtEscorts = [];   // escorts only -- the car peels off with its own watchdog at the split
        {
            private _p = [_start getPos [_x, _heading + 180]] call _onRoad;
            private _r = [_p, _heading, call _rollEsc, EAST] call BIS_fnc_spawnVehicle;
            (_r select 0) setDir _heading;
            (_r select 2) deleteGroupWhenEmpty true;
            (_r select 1) joinSilent _hvtColGrp;
            _hvtEscorts pushBack (_r select 0);
        } forEach [0, 36];
        private _cp = [_start getPos [18, _heading + 180]] call _onRoad;
        _car = createVehicle [_hvtCarClass, _cp, [], 0, "NONE"];
        _car setDir _heading;
        private _driver = _hvtColGrp createUnit [opfor_SOLDIER_X, _cp, [], 0, "NONE"];
        _driver moveInDriver _car;
        _hvt = _hvtColGrp createUnit [opfor_OFFICER_X, _cp, [], 0, "NONE"];
        _hvt moveInCargo _car;
        _hvt addHeadgear "H_Beret_blk";
        _hvt addMagazineGlobal "FileTopSecret";
        _hvtColGrp setBehaviour "AWARE";
        _hvtColGrp setCombatMode "YELLOW";
        _hvtColGrp setSpeedMode "LIMITED";
        _hvtColGrp setFormation "COLUMN";
        _hvtColGrp deleteGroupWhenEmpty true;
        { [_x] call fnc_addRandomLoot } forEach units _hvtColGrp;
        _groups pushBack _hvtColGrp;
        _groupVehs pushBack _hvtEscorts;
        _vias pushBack _via;
    } else {
        ([[call _rollEsc, call _rollEsc, call _rollEsc], _start, _heading, "AWARE", "LIMITED"] call _spawnLine) params ["_grp", "_gvehs"];
        _groups pushBack _grp;
        _groupVehs pushBack _gvehs;
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

// Search ellipse on the convoy start cluster -- where the player is sent -- with a fix on each
// convoy's start inside it. The starts are one-shot: nothing tracks the convoys live, or there would
// be no hunt. The destination the convoys run for is marked separately just below.
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

// The safe-haven zone the convoys run for, marked so the player reads the direction of the race and
// can move to cut a column off short of it. Its rounded position names the marker, cleared with the
// rest at mission end.
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

// Grace: the columns hold at their start points, so a player inserting from range has a window before
// the race begins. Then every column is ordered to the zone via its own mid-route point at once, so
// the three take separate roads in.
sleep _graceSec;
{
    private _via = _vias select _forEachIndex;
    private _wpVia = _x addWaypoint [_via, 0];
    _wpVia setWaypointType "MOVE";
    _wpVia setWaypointCompletionRadius 60;
    private _wpEnd = _x addWaypoint [_destPos, 0];
    _wpEnd setWaypointType "MOVE";
    _wpEnd setWaypointCompletionRadius 40;
} forEach _groups;
// Reliability layer per column, once they are rolling: road-lock + spacing + keep-crew-aboard, plus a
// stuck watchdog that nudges any jammed hull and lifts the road-lock for the run into the off-road zone.
// Spawned only now, after the grace hold, so it does not fight the columns sitting still at their starts.
// Ended at teardown via DUWS_convoy_stop.
{
    private _gv = _groupVehs select _forEachIndex;
    [_x, _gv] call fnc_convoy_setup;
    [_x, _gv] spawn fnc_convoy_watch;
} forEach _groups;
// Allseer calls the move the instant the columns are ordered out, so the player reads the race as
// starting rather than watching for it.
[localize "STR_DUWS_T_ALLSEER", format [localize "STR_DUWS_T_hvtmoveout", _destName]] remoteExec ["fnc_duws_dialogue", 0];

private _outcome = "";
private _split = false;
// Midpoint intel: a rolled 30-60 s hold after the columns move, then Allseer names their mid-route
// points and drops an arrow on each pointing at the destination, so the player reads where the routes
// bend and can move to cut one short. Run inside the monitor, not a side thread, so a kill or arrival
// before the reveal ends the mission with nothing left to clear -- _viaMarkers stays empty and teardown
// deletes nothing.
private _viaMarkers = [];
private _revealAt = time + (30 + round random 30);
private _revealed = false;
waitUntil {
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
    // First contact: peel the car out of the column into its own CARELESS group so it runs for the
    // zone instead of halting to fight alongside the escorts. Triggered by the column going COMBAT or
    // the car taking a hit. Its crew keep their claim stamp, so teardown still collects them.
    if (!_split && alive _car && {
        (!isNull _hvtColGrp && {count units _hvtColGrp > 0} && {behaviour (leader _hvtColGrp) == "COMBAT"})
        || damage _car > 0
    }) then {
        _split = true;
        _carGrp = createGroup EAST;
        [_hvt, driver _car] joinSilent _carGrp;
        _carGrp setBehaviour "CARELESS";
        _carGrp setSpeedMode "FULL";
        _carGrp deleteGroupWhenEmpty true;
        private _wp = _carGrp addWaypoint [_destPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 40;
        // The peeled car gets its own reliability layer + watchdog: it commits to the zone alone now, so
        // a jam on the final stretch would hand the player a win the mission does not intend.
        [_carGrp, [_car]] call fnc_convoy_setup;
        [_carGrp, [_car]] spawn fnc_convoy_watch;
    };
    if (!alive _hvt) exitWith { _outcome = "WIN"; true };
    if (_hvt distance2D _destPos < _arrive) exitWith { _outcome = "ESCAPED"; true };
    if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
    false
};

// End every convoy watchdog: the column groups and, if it split out, the HVT car's own group.
{ _x setVariable ["DUWS_convoy_stop", true] } forEach _groups;
if (!isNull _carGrp) then { _carGrp setVariable ["DUWS_convoy_stop", true] };

[_marker] call fnc_missionMarkerClear;
{ deleteMarker _x } forEach _startMarkers;
{ deleteMarker _x } forEach _viaMarkers;
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
