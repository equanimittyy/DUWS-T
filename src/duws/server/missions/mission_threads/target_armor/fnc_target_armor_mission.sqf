// Locality: server -- callers remoteExec to target 2.
// Eliminate a roving vehicle patrol: three vehicles of one class, scaled to OPFOR's earned AP tier, that
// patrol a road loop inside the search ring as one column. Win: every crewman across the three dead. The
// column holds LIMITED speed until first hit or a man down, then drops the limit and fights -- "speed-
// limited until broken". Shared spine: fnc_mission_run.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // One class for the two followers, rolled once off the earned tier. Gated by earned AP (car floor,
    // tank top); armed-car global then transport truck back a side that has earned nothing, so the patrol
    // is never a column of empty air.
    private _tierPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
    private _token = if (_tierPool isEqualTo []) then { "car" } else { selectRandom _tierPool };
    private _vehClass = [_token] call DUWS_fnc_tokenClass;
    if (_vehClass == "") then { _vehClass = opfor_ARMED_CAR1_X; _token = "car" };
    if (_vehClass == "") then { _vehClass = opfor_TRANS_TRUCK_X };

    // Lead drawn apart from the pair so the column is led by a distinct hull, not three identical shapes:
    // a different earned tier when one exists, else a fresh draw of the same tier (distinct only where that
    // tier has variants). Reward still keys to _token, the pair's tier -- a heavier or lighter lead is
    // flavour, not a payout change.
    private _leadPool = _tierPool - [_token];
    private _leadToken = if (_leadPool isEqualTo []) then { _token } else { selectRandom _leadPool };
    private _leadClass = [_leadToken] call DUWS_fnc_tokenClass;
    if (_leadClass == "") then { _leadClass = _vehClass };

    // Reward scales with the tier fielded: +10 CP and +5 AP per step above a car patrol, so car / IFV /
    // armour pay 15/20, 25/25, 35/30. The briefing and strategic map print the base -- both are built
    // before this rolls -- so a heavier patrol pays the step-up as an unadvertised bonus at completion.
    // Inherent to rolling the tier at spawn, not a display bug to chase. One mission runs at a time
    // (Mission_available gate), so the in-place reward bump is safe.
    private _tier = ["car", "ifv", "tank"] find _token;
    DUWS_curReward set [0, (DUWS_curReward select 0) + (10 * _tier)];
    DUWS_curReward set [1, (DUWS_curReward select 1) + (5 * _tier)];

    // Patrol points around the ring, snapped to roads so the column rides the network rather than cutting
    // cross-country between them (Arma routes vehicles badly off-road -- see fnc_convoy_drive). Centred on
    // the marked position so the patrol stays inside the drawn ellipse.
    private _pts = [];
    private _steps = 5;
    for "_i" from 0 to (_steps - 1) do {
        private _ang = _i * (360 / _steps) + random 40;
        private _cand = _randomPos getPos [_radius * (0.4 + random 0.3), _ang];
        // Keep every anchor out of the sea: the first is where the column spawns and the
        // rest are what it laps, so a water point drowns the patrol or drives it in. Drop
        // roads whose segment sits over water (coastal snaps, bridges), and land the
        // road-less fallback via findSafePos waterMode 0 before falling to the raw point.
        private _roads = (_cand nearRoads 400) select { !surfaceIsWater (getPosATL _x) };
        _pts pushBack (if (_roads isEqualTo []) then {
            private _land = [_cand, 0, 200, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_land isEqualTo [] || {surfaceIsWater _land}) then { _cand } else { _land }
        } else {
            getPosATL (selectRandom _roads)
        });
    };
    private _start = _pts select 0;
    private _heading = [_start, _pts select 1] call BIS_fnc_dirTo;

    // Lay the three as a spaced column ON the road toward the first patrol point, so trailing hulls sit
    // on the carriageway facing the road's tangent -- not a straight offset back from the start that
    // ignores the road's curve and faces a map bearing, which left hulls crossways and shoved apart.
    private _slots = [_start, _heading, 3, 20] call fnc_convoy_layout;

    // Crews merged into one group so the three road-march as a column instead of pathing apart.
    private _grp = createGroup EAST;
    private _vehs = [];
    for "_i" from 0 to 2 do {
        (_slots select _i) params ["_sp", "_sd"];
        // Slot 0 is the front of the column (convoy_layout lays lead-first, and the driver picks the
        // frontmost as lead), so it takes the distinct lead class; the other two share _vehClass.
        private _class = [_vehClass, _leadClass] select (_i == 0);
        private _r = [_sp, _sd, _class, EAST] call BIS_fnc_spawnVehicle;
        (_r select 0) setDir _sd;
        (_r select 2) deleteGroupWhenEmpty true;
        (_r select 1) joinSilent _grp;
        _vehs pushBack (_r select 0);
    };
    // Disposition is left to the posture below (SAFE until it detects the player, then the engine promotes
    // it) -- the break flip drops to COMBAT on first contact. Combat mode, speed and column formation are
    // the patrol's own, untouched by hqpatrol.
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

    // Two ambient foot patrols working the zone alongside the vehicle column: extra opposition the
    // player meets while hunting the patrol, deliberately NOT in the win census (that stays the vehicle
    // crews returned below). Each owns its own half of the zone -- centres offset to opposite sides of
    // the marked point on a random axis, at half the ring so each team's spawn and circuit stay in its
    // half -- so the two roam wide (widepatrol) yet keep a zone-width apart rather than converging on
    // one random walk. Claimed so teardown collects them with the rest of the patrol on mission end.
    private _teamAxis = random 360;
    {
        private _teamCentre = _randomPos getPos [_radius * 0.5, _teamAxis + _x];
        private _team = ["team", _teamCentre, _radius * 0.5, "widepatrol"] call fnc_spawn_team;
        if (!isNull _team) then { [_team] call fnc_mission_claim };
    } forEach [0, 180];

    // Lap the road-snapped ring via the shared fixed-circuit posture, not a hand-rolled CYCLE. hqpatrol alone
    // takes caller anchors (closepatrol/widepatrol roll their own un-snapped points), so the column keeps to
    // the road network; it anchors CYCLE on the first point, so nearest-prior is that point rather than
    // whichever ring leg a straight-line tie fell to -- which could collapse the loop onto the last leg.
    [_grp, "hqpatrol", _randomPos, _radius, _pts] call fnc_apply_posture;

    // Path-replay driver: the lead laps the ring on its own waypoints and the other two trace its track, so
    // they hold the road as a column instead of each pathing apart. It reads the group's hulls live. Ends
    // itself once no vehicle can move (patrol wiped), so no teardown hook is owed here; the break flip below
    // releases it to fight.
    [_grp] spawn fnc_convoy_drive;

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
    7, 1500, "kill", "STR_DUWS_T_y7z1cx6j", "STR_DUWS_T_c7", "vehpatrol",
    _build,
    { (_this findIf { alive _x }) < 0 },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorend"],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_armorfail"],
    "mission_target_armor"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
