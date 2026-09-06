// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // One class for the two followers, rolled once off the earned AP tier (car floor, tank top).
    // Armed-car global, then transport truck, back a side that earned nothing -- never a column of empty air.
    private _tierPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
    private _token = if (_tierPool isEqualTo []) then { "car" } else { selectRandom _tierPool };
    private _vehClass = [_token] call DUWS_fnc_tokenClass;
    if (_vehClass == "") then { _vehClass = opfor_ARMED_CAR1_X; _token = "car" };
    if (_vehClass == "") then { _vehClass = opfor_TRANS_TRUCK_X };

    // Lead drawn apart from the pair for a distinct hull; reward keys to _token (the pair's tier), so a
    // heavier or lighter lead is flavour, not payout.
    private _leadPool = _tierPool - [_token];
    private _leadToken = if (_leadPool isEqualTo []) then { _token } else { selectRandom _leadPool };
    private _leadClass = [_leadToken] call DUWS_fnc_tokenClass;
    if (_leadClass == "") then { _leadClass = _vehClass };

    // +10 CP per tier above a car patrol (AP flat). An unadvertised completion bonus: the briefing and map
    // print the base, built before this rolls. Safe to bump in place -- only one mission runs at a time.
    private _tier = ["car", "ifv", "tank"] find _token;
    DUWS_curReward set [0, (DUWS_curReward select 0) + (10 * _tier)];

    // Patrol points around the ring, snapped to roads -- Arma routes vehicles badly off-road (see
    // fnc_convoy_drive). Centred on the marked position so the patrol stays inside the ellipse.
    private _pts = [];
    private _steps = 5;
    for "_i" from 0 to (_steps - 1) do {
        private _ang = _i * (360 / _steps) + random 40;
        private _cand = _randomPos getPos [_radius * (0.4 + random 0.3), _ang];
        // Keep every anchor out of the sea -- a water anchor drowns the patrol: drop road segments over
        // water (coastal snaps, bridges); road-less fallback is fnc_mission_safepos.
        private _roads = (_cand nearRoads 400) select { !surfaceIsWater (getPosATL _x) };
        _pts pushBack (if (_roads isEqualTo []) then {
            [_cand, 200, 0, 5] call fnc_mission_safepos
        } else {
            getPosATL (selectRandom _roads)
        });
    };
    // Clamp a snap that lands past _radius back to centre: a bad road/findSafePos snap could seat the
    // column on BLUFOR HQ, whose garrison wipes it on spawn and auto-completes the mission. Real points
    // sit at 0.4-0.7 * _radius, well inside this bound.
    {
        if ((_x distance2D _randomPos) > _radius) then { _pts set [_forEachIndex, _randomPos] };
    } forEach _pts;
    private _start = _pts select 0;

    // Route the first leg and seat the three ON it in trail order, so they are born facing down the drive
    // path, not a straight offset that ignores the road's curve. The driver below reuses this same route.
    private _route0 = [_start, _pts select 1] call fnc_convoy_path;
    private _slots = [_route0, 3, 20] call fnc_convoy_slots;

    // Crews merged into one group so the three road-march as a column instead of pathing apart.
    private _grp = createGroup EAST;
    private _vehs = [];
    for "_i" from 0 to 2 do {
        (_slots select _i) params ["_sp", "_sd"];
        // Slot 0 is the column front (convoy_layout lays lead-first, the driver picks the frontmost as
        // lead), so it takes the distinct lead class; the other two share _vehClass.
        private _class = [_vehClass, _leadClass] select (_i == 0);
        _sp = [_sp, _class] call fnc_convoy_fit;
        private _r = [_sp, _sd, _class, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _sd;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    };
    // Disposition is left to the posture below (SAFE until it spots the player, then engine-promoted; the
    // break flip drops COMBAT on contact). Combat mode, speed, formation are its own, not hqpatrol's.
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "LIMITED";
    _grp setFormation "COLUMN";
    _grp deleteGroupWhenEmpty true;
    { [_x] call fnc_addRandomLoot } forEach units _grp;

    // Claiming the group stamps the crew and vehicles, so teardown collects the whole patrol wherever it
    // has driven to.
    [_grp] call fnc_mission_claim;

    [leader _grp] spawn { params ["_u"]; sleep 5; _u addMagazineGlobal "FileTopSecret" };
    if (hardcore_mode_enable) then {
        [units _grp, "objective"] call fnc_search_flag_group;
    };

    // Two ambient foot patrols, deliberately NOT in the win census (that stays the vehicle crews). Centres
    // offset to opposite half-ring axes so the two roam wide yet keep apart rather than converging.
    private _teamAxis = random 360;
    {
        private _teamCentre = _randomPos getPos [_radius * 0.5, _teamAxis + _x];
        private _team = ["team", _teamCentre, _radius * 0.5, "widepatrol"] call fnc_spawn_team;
        if (!isNull _team) then { [_team] call fnc_mission_claim };
    } forEach [0, 180];

    // hqpatrol is the only posture that takes caller anchors, so the column keeps to the snapped roads.
    // Spawn point (_pts#0) rotated LAST: a leading waypoint there is a zero-length first leg that drives
    // the pre-seated column backward. Still visits every point, CYCLEs on _pts#1.
    private _ring = (_pts select [1, (count _pts) - 1]) + [_pts select 0];
    [_grp, "hqpatrol", _randomPos, _radius, _ring] call fnc_apply_posture;

    // Self-routing driver: each hull drives the leg's road route holding spacing, so they keep column on
    // the road. Ends itself once no vehicle can move (patrol wiped) -- no teardown hook needed; the break
    // flip below releases it to fight. Reuses the seated leg-one route (DUWS_convoy_route0).
    _grp setVariable ["DUWS_convoy_route0", _route0];
    [_grp] spawn fnc_convoy_drive;

    // Speed-limited until broken: first man down or hull hit past 0.3 damage lifts the limit and drops the
    // waypoints so the AI manoeuvres. The 0.3 floor ignores terrain scrapes; the guard below stops a patrol
    // cleaned before contact outliving its group.
    [_grp, _vehs] spawn {
        params ["_grp", "_vehs"];
        private _crew = units _grp;
        waitUntil {
            sleep 2;
            isNull _grp
            || { (units _grp) isEqualTo [] }
            || { (_vehs findIf { !alive _x || {damage _x > 0.3} }) >= 0 }
            || { (_crew findIf { !alive _x }) >= 0 }
        };
        if (!isNull _grp && {(units _grp) isNotEqualTo []}) then {
            // Release the path-replay driver first: it must stop re-issuing setDriveOnPath and drop the speed
            // caps, or the hulls stay committed to the track and never manoeuvre.
            _grp setVariable ["DUWS_convoy_release", true];
            for "_i" from (count (waypoints _grp) - 1) to 1 step -1 do { deleteWaypoint [_grp, _i] };
            _grp setSpeedMode "FULL";
            _grp setBehaviour "COMBAT";
            _grp setCombatMode "RED";
        };
    };

    // Win census: bailed survivors stay in this group, so a player who disables a hull and shoots the crew
    // out clears them too.
    units _grp
};

private _done = { (_this findIf { alive _x }) < 0 };

if (!([7, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 1500;
private _site = [_MissionPos, _radius, 7, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["vehpatrol%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_y7z1cx6j", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorletsdothis", 8], ["STR_DUWS_T_actionteam", "STR_DUWS_T_armorcopy", 0]]
] call fnc_mission_present;

sleep 5; // let the column finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_target_armor"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorend"], true, "mission_target_armor"] call fnc_mission_finish;
