// Locality: server -- callers remoteExec to target 2.
// Eliminate a roving vehicle patrol: three vehicles of one class, scaled to OPFOR's earned AP tier,
// lapping a road loop inside the search ring as one column. Win: every crewman across the three dead.
// The column holds LIMITED until first hit or man down, then drops it and fights. Spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // One class for the two followers, rolled once off the earned AP tier (car floor, tank top).
    // Armed-car global, then transport truck, back a side that earned nothing -- never a column of empty air.
    private _tierPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
    private _token = if (_tierPool isEqualTo []) then { "car" } else { selectRandom _tierPool };
    private _vehClass = [_token] call DUWS_fnc_tokenClass;
    if (_vehClass == "") then { _vehClass = opfor_ARMED_CAR1_X; _token = "car" };
    if (_vehClass == "") then { _vehClass = opfor_TRANS_TRUCK_X };

    // Lead drawn apart from the pair so the column has a distinct hull, not three identical shapes: a
    // different earned tier if one exists, else a fresh draw of the same tier (distinct only where it has
    // variants). Reward keys to _token (the pair's tier), so a heavier/lighter lead is flavour, not payout.
    private _leadPool = _tierPool - [_token];
    private _leadToken = if (_leadPool isEqualTo []) then { _token } else { selectRandom _leadPool };
    private _leadClass = [_leadToken] call DUWS_fnc_tokenClass;
    if (_leadClass == "") then { _leadClass = _vehClass };

    // Reward scales with the tier fielded: +10 CP per step above a car patrol, AP flat (car/IFV/armour
    // pay 15/20, 25/20, 35/20). The briefing and strategic map print the base -- both built before this
    // rolls -- so the step-up is an unadvertised completion bonus, inherent to rolling the tier at spawn,
    // not a display bug. One mission runs at a time (Mission_available gate), so the in-place bump is safe.
    private _tier = ["car", "ifv", "tank"] find _token;
    DUWS_curReward set [0, (DUWS_curReward select 0) + (10 * _tier)];

    // Patrol points around the ring, snapped to roads so the column rides the network rather than cutting
    // cross-country (Arma routes vehicles badly off-road -- see fnc_convoy_drive). Centred on the marked
    // position so the patrol stays inside the drawn ellipse.
    private _pts = [];
    private _steps = 5;
    for "_i" from 0 to (_steps - 1) do {
        private _ang = _i * (360 / _steps) + random 40;
        private _cand = _randomPos getPos [_radius * (0.4 + random 0.3), _ang];
        // Keep every anchor out of the sea: the spawn point (first) and the points it laps alike, so a water
        // anchor drowns the patrol or drives it in. Drop roads whose segment sits over water (coastal snaps,
        // bridges); road-less fallback is the shared safe-pos helper (clear land near the point, else the
        // raw point -- never the map origin).
        private _roads = (_cand nearRoads 400) select { !surfaceIsWater (getPosATL _x) };
        _pts pushBack (if (_roads isEqualTo []) then {
            [_cand, 200, 5] call fnc_convoy_safepos
        } else {
            getPosATL (selectRandom _roads)
        });
    };
    // Guard a spawn/patrol point that lands far outside the marked ring. A road or findSafePos snap must
    // never seat the column kilometres away -- dropped on top of BLUFOR HQ, its garrison wipes the patrol
    // the instant it spawns and the mission auto-completes with the player nowhere near. A point past the
    // ring radius is a bad snap, not a real anchor, so it falls back to the marked centre (the AO the player
    // is sent to). The legitimate points sit at 0.4-0.7 * _radius, well inside this bound.
    {
        if ((_x distance2D _randomPos) > _radius) then { _pts set [_forEachIndex, _randomPos] };
    } forEach _pts;
    private _start = _pts select 0;

    // Route the first leg (start -> _pts#1, the first point it drives to) and seat the three ON it in trail
    // order, so they are born on the drive path facing down it, not on a straight offset that ignores the
    // road's curve. The same route is handed to the driver below so it reuses it without teleport-reordering.
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

    // Two ambient foot patrols working the zone alongside the vehicle column: extra opposition the player
    // meets while hunting, deliberately NOT in the win census (that stays the vehicle crews below). Each
    // owns half the zone -- centres offset to opposite sides of the marked point on a random axis, at half
    // the ring so each stays in its half -- so both roam wide (widepatrol) yet keep a zone-width apart
    // rather than converging on one walk. Claimed so teardown collects them with the rest on mission end.
    private _teamAxis = random 360;
    {
        private _teamCentre = _randomPos getPos [_radius * 0.5, _teamAxis + _x];
        private _team = ["team", _teamCentre, _radius * 0.5, "widepatrol"] call fnc_spawn_team;
        if (!isNull _team) then { [_team] call fnc_mission_claim };
    } forEach [0, 180];

    // Lap the road-snapped ring via the shared fixed-circuit posture, not a hand-rolled CYCLE: only
    // hqpatrol takes caller anchors (closepatrol/widepatrol roll un-snapped points), so the column keeps to
    // the network. Rotate the spawn point (_pts#0) LAST: a leading waypoint there is a zero-length first leg
    // that, with the column pre-seated forward, drives it backward. Still visits every point, CYCLEs on _pts#1.
    private _ring = (_pts select [1, (count _pts) - 1]) + [_pts select 0];
    [_grp, "hqpatrol", _randomPos, _radius, _ring] call fnc_apply_posture;

    // Self-routing driver: computes each leg's road route and every hull drives it holding spacing, so they
    // hold the road as a column. Reads the group's hulls live; ends itself once no vehicle can move (patrol
    // wiped), so no teardown hook here -- the break flip below releases it to fight. Reuses the seated
    // leg-one route (DUWS_convoy_route0).
    _grp setVariable ["DUWS_convoy_route0", _route0];
    [_grp] spawn fnc_convoy_drive;

    // Speed-limited until broken: the first man down or hull hit lifts the limit and turns the patrol loose,
    // dropping its waypoints so the AI manoeuvres rather than lapping the ring. Past 0.3, not a scrape: a
    // hull that clips terrain self-damages and must not read as contact. Guards the flip so a patrol cleaned
    // before it is ever engaged cannot make the thread outlive the group.
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

private _spec = [
    7, 1500, "kill", "STR_DUWS_T_y7z1cx6j", "vehpatrol",
    _build,
    { (_this findIf { alive _x }) < 0 },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorend"],
    [],
    "mission_target_armor"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
