// Locality: server -- callers remoteExec to target 2.
// Eliminate a roving vehicle patrol: three vehicles of one class, scaled to OPFOR's earned AP tier, that
// patrol a road loop inside the search ring as one column. Win: every crewman across the three dead. The
// column holds LIMITED speed until first hit or a man down, then drops the limit and fights -- "speed-
// limited until broken". Shared spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // One class for all three, rolled once -- tokenClass draws per call, so per-vehicle rolls give a mixed
    // column. Gated by earned AP (car floor, tank top); armed-car global then transport truck back a side
    // that has earned nothing, so the patrol is never a column of empty air.
    private _tierPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
    private _token = if (_tierPool isEqualTo []) then { "car" } else { selectRandom _tierPool };
    private _vehClass = [_token] call DUWS_fnc_tokenClass;
    if (_vehClass == "") then { _vehClass = opfor_ARMED_CAR1_X; _token = "car" };
    if (_vehClass == "") then { _vehClass = opfor_TRANS_TRUCK_X };

    // Reward scales with the tier fielded: +10 CP and +5 AP per step above a car patrol, so car / IFV /
    // armour pay 15/20, 25/25, 35/30. The briefing and strategic map print the base -- both are built
    // before this rolls -- so a heavier patrol pays the step-up as an unadvertised bonus at completion.
    // Inherent to rolling the tier at spawn, not a display bug to chase. One mission runs at a time
    // (Mission_available gate), so the in-place reward bump is safe.
    private _tier = ["car", "ifv", "tank"] find _token;
    DUWS_curReward set [0, (DUWS_curReward select 0) + (10 * _tier)];
    DUWS_curReward set [1, (DUWS_curReward select 1) + (5 * _tier)];

    // Patrol points around the ring, snapped to roads so the column rides the network rather than cutting
    // cross-country between them (Arma routes vehicles badly off-road -- see fnc_convoy_setup). Centred on
    // the marked position so the patrol stays inside the drawn ellipse.
    private _pts = [];
    private _steps = 5;
    for "_i" from 0 to (_steps - 1) do {
        private _ang = _i * (360 / _steps) + random 40;
        private _cand = _randomPos getPos [_radius * (0.4 + random 0.3), _ang];
        private _roads = _cand nearRoads 400;
        _pts pushBack (if (_roads isEqualTo []) then { _cand } else { getPosATL (selectRandom _roads) });
    };
    private _start = _pts select 0;
    private _heading = [_start, _pts select 1] call BIS_fnc_dirTo;

    // Crews merged into one group so the three road-march as a column instead of pathing apart.
    private _grp = createGroup EAST;
    private _vehs = [];
    for "_i" from 0 to 2 do {
        private _p = _start getPos [_i * 20, _heading + 180];
        private _r = [_p, _heading, _vehClass, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _heading;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    };
    _grp setBehaviour "AWARE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "LIMITED";
    _grp setFormation "COLUMN";
    _grp deleteGroupWhenEmpty true;
    { [_x] call fnc_addRandomLoot } forEach units _grp;

    // Claiming the group stamps the crew and their vehicles, so teardown collects the whole patrol wherever
    // it has driven to.
    [_grp] call fnc_mission_claim;

    [leader _grp] spawn { params ["_u"]; sleep 5; _u addMagazineGlobal "FileTopSecret" };
    if (hardcore_mode_enable) then {
        [units _grp, "objective"] call fnc_search_flag_group;
    };

    // MOVE through each point, then CYCLE so the column laps the ring until it is broken.
    {
        private _wp = _grp addWaypoint [_x, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 40;
        _wp setWaypointSpeed "LIMITED";
    } forEach (_pts select [1, count _pts - 1]);
    private _cyc = _grp addWaypoint [_start, 0];
    _cyc setWaypointType "CYCLE";
    _cyc setWaypointCompletionRadius 40;

    // Reliability layer + stuck watchdog: road-lock, spacing, keep-crew-aboard, and a nudge for any jammed
    // hull. Ends itself once no vehicle can move (patrol wiped), so no teardown hook is owed here.
    [_grp, _vehs] call fnc_convoy_setup;
    [_grp, _vehs] spawn fnc_convoy_watch;

    // Speed-limited until broken: the first man down or hull hit lifts the limit and turns the patrol loose,
    // dropping its waypoints so the AI manoeuvres rather than lapping the ring. A wound past 0.3, not a
    // scrape: a hull that clips terrain on the loop self-damages, and that must not read as contact. Guards
    // the flip so a patrol cleaned before it is ever engaged cannot make the thread outlive the group.
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

private _spec = [
    7, 1500, "kill", "STR_DUWS_T_y7z1cx6j", "STR_DUWS_T_c7", "vehpatrol",
    _build,
    { (_this findIf { alive _x }) < 0 },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorend"],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorfail"],
    "mission_target_armor"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
