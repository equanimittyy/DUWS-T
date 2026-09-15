// Locality: server -- every path here raises men or touches server-side garrison state; none of it a
// client may do. Defined at load, but the loop and the killed handler start later, at WARCOM init.
// Reinforcement half of the garrison model: accounting lives in fnc_zone_state_init, the strength ledger
// in fnc_garrison_strength_init. Model: docs/info/gameplay/garrison_and_reserves.md.

// Counts reserve-owed men with live men so a site can't fall on an empty perimeter while waves are still
// owed; no full-potential stamp yet reads as not-beaten, never as beaten.
DUWS_fnc_garrisonBeaten = {
    params ["_key"];
    private _fullMen = [_key] call DUWS_fnc_garrisonFullMen;
    if (_fullMen <= 0) exitWith { false };
    (([_key] call fnc_zone_garrison_count) + ([_key] call DUWS_fnc_garrisonReserveMen)) <= (0.1 * _fullMen)
};

// eyePos is ASL, so the target is lifted to standing head height and converted to match. VIEW and GEOM
// together answer terrain and buildings both; an empty intersection list means a clear line.
DUWS_fnc_posSeenBy = {
    params ["_pos", "_unit"];
    private _to = AGLToASL [_pos select 0, _pos select 1, 1.5];
    (lineIntersectsSurfaces [eyePos _unit, _to, _unit, objNull, true, 1, "VIEW", "GEOM"]) isEqualTo []
};

// Far side, past the players, preferably unseen -- so a player never watches a squad appear or gets
// flanked from their own approach direction.
DUWS_fnc_garrisonReservePos = {
    params ["_center", "_radius"];
    private _reach = _radius + DUWS_streamArrivalMargin;
    private _players = (call BIS_fnc_listPlayers) select { alive _x && {(_x distance2D _center) < _reach} };
    if (_players isEqualTo []) then { _players = (call BIS_fnc_listPlayers) select { alive _x } };

    // Anti-flank, non-negotiable: the reserve spawns opposite the players' centroid bearing, so it
    // meets them head-on rather than flanking from behind their axis of approach.
    private _centroid = _center;
    if (_players isNotEqualTo []) then {
        private _cx = 0; private _cy = 0;
        { private _p = getPosATL _x; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1) } forEach _players;
        _centroid = [_cx / count _players, _cy / count _players];
    };
    private _antiDir = (_center getDir _centroid) + 180;

    // Soft nudge toward the nearest OPFOR zone so the wave reads as coming from friendly ground; clamped
    // to a narrow arc since anti-flank always wins -- this only ever bends the spawn, never swings it
    // back toward the players. Applies to town reserves too: zones are the only friendly-ground signal
    // there is.
    private _others = (missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []]) select {
        (_x distance2D _center) > _radius
    };
    if (_others isNotEqualTo []) then {
        private _near = ([_others, [], { _center distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        // Signed shortest turn (-180..180) from anti-approach to zone bearing, then clamped to +-50 degrees.
        private _delta = ((( _center getDir _near) - _antiDir + 540) mod 360) - 180;
        _antiDir = _antiDir + ((_delta max -50) min 50);
    };

    // Base distance only has to clear the objective; the per-player reject in the loop below is the real
    // floor. Adding the farthest player's range on top (an earlier version) stood the wave a kilometre
    // out the back of the zone, too far to close before the fight was over.
    private _baseDist = _radius + DUWS_zoneReserveSpawnDist;

    // Cast only at spawn time (a wave every few minutes, a handful of rays per candidate) so the cost
    // never lands on a frame budget. Prefer-hidden, accept-best -- it never blocks a spawn.
    private _best = [];
    private _bestSeen = 1e9;
    {
        private _cand = [_center getPos [_baseDist, _antiDir + _x], 0, 200, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
        // Snapped before the seen-check and floor reject so both judge the point the wave actually spawns
        // on: a road segment can sit closer to the players or in worse cover than the raw candidate.
        if (_cand isNotEqualTo []) then { _cand = [_cand] call DUWS_fnc_reserveRoadSnap };
        // An empty candidate must not reach the spawners: they read [] as "no override" and would drop
        // the reserve into the objective band, on top of the players.
        if (_cand isNotEqualTo [] && {(_players findIf { (_cand distance2D _x) < DUWS_zoneReserveSpawnDist }) < 0}) then {
            private _seen = { [_cand, _x] call DUWS_fnc_posSeenBy } count _players;
            if (_seen < _bestSeen) then { _bestSeen = _seen; _best = _cand };
        };
    } forEach [0, 30, -30, 60, -60];

    if (_best isNotEqualTo []) exitWith { _best };

    // Preferred arc was all bad ground -- usually a far side facing the sea, where waterMode 0 refuses
    // to land offshore. Widened to the rest of the circle: anti-flank is given up before a water spawn,
    // since a wave dropped offshore drowns or strands outright, worse than one from a poor angle. First
    // land wins here rather than fewest-seen: being on the map at all outranks cover.
    private _wide = [];
    {
        if (_wide isEqualTo []) then {
            private _c = [_center getPos [_baseDist, _antiDir + _x], 0, 200, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
            if (_c isNotEqualTo []) then { _c = [_c] call DUWS_fnc_reserveRoadSnap };
            if (_c isNotEqualTo [] && {(_players findIf { (_c distance2D _x) < DUWS_zoneReserveSpawnDist }) < 0}) then { _wide = _c };
        };
    } forEach [90, -90, 120, -120, 150, -150, 180];
    if (_wide isNotEqualTo []) exitWith { _wide };

    // Whole circle blocked -- a speck of an island. Falls back to getPos, not findSafePos, so this can
    // never return [] and collapse the spawn into the objective band on top of the players.
    _center getPos [_baseDist, _antiDir]
};

// Reserve rides trucks, so a wave needs drivable ground. Sorted explicitly -- nearRoads' own order
// isn't trustworthy.
DUWS_fnc_reserveRoadSnap = {
    params ["_pos"];
    private _roads = _pos nearRoads DUWS_zoneReserveRoadSearch;
    if (_roads isEqualTo []) exitWith { _pos };
    getPosATL (([_roads, [], { _pos distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0)
};

// Lead point is pushed _i gaps back along the outbound bearing so the tail runs away from the objective,
// never toward it. Good spacing outranks landing exactly on a road (two vehicles on one point brew up on
// spawn), and neither outranks staying out of the sea. Bounded retries, then the lead point -- land by
// construction.
DUWS_fnc_reserveConvoySlot = {
    params ["_lead", "_dir", "_i"];
    // Read straight off the world with nearestObjects -- the same clear-ground test civilian cars settle
    // on -- rather than a private list, so a concurrent wave's trucks and ambient civ traffic count too.
    private _fnc_clear = { (nearestObjects [_this, ["LandVehicle"], DUWS_reserveConvoyGap]) isEqualTo [] };
    private _out = [];
    private _step = _i;
    private _tries = 0;
    while { _out isEqualTo [] && {_tries < 6} } do {
        _tries = _tries + 1;
        private _raw = _lead getPos [_step * DUWS_reserveConvoyGap, _dir];
        private _snap = [_raw] call DUWS_fnc_reserveRoadSnap;
        // A slot over water sinks a vehicle -- the outbound bearing can walk a coastal wave off the
        // shoreline step by step. Rejected like a collision so the ray steps further out for land.
        if (!surfaceIsWater _snap && {_snap call _fnc_clear}) then {
            _out = _snap;
        } else {
            if (!surfaceIsWater _raw && {_raw call _fnc_clear}) then {
                _out = _raw;
            } else {
                _step = _step + 1;
            };
        };
    };
    // Falls back to the wave lead -- garrisonReservePos guarantees it's on land. Crowding a vehicle
    // there is recoverable; the sea is not.
    if (_out isEqualTo []) then { _out = _lead };
    _out
};

// _wave's lead point and bearing are chosen once, on the first call, and reused so every vehicle in the
// wave lines up off the same lead instead of re-picking and stacking. _wave/_slots are the caller's own
// arrays, mutated in place (SQF arrays pass by reference) -- wave state lives in the refill loop, not here.
DUWS_fnc_reserveWaveSlot = {
    params ["_center", "_radius", "_wave", "_slots"];
    if (_wave isEqualTo []) then {
        private _lead = [_center, _radius] call DUWS_fnc_garrisonReservePos;
        _wave set [0, _lead];
        _wave set [1, _center getDir _lead];
    };
    private _pos = [_wave select 0, _wave select 1, count _slots] call DUWS_fnc_reserveConvoySlot;
    _slots pushBack _pos;
    _pos
};

// Key and token ride each unit, not the group -- a dead man can outlive his group's own lifetime.
// DUWS_srcToken was tagged on the group by DUWS_fnc_zoneSpawnOne when it was raised.
DUWS_fnc_garrisonReserveWatch = {
    params ["_key", "_grps"];
    {
        private _tok = _x getVariable ["DUWS_srcToken", ""];
        {
            _x setVariable ["DUWS_garrisonKey", _key];
            _x setVariable ["DUWS_garrisonToken", _tok];
            _x addEventHandler ["Killed", {
                private _unit = _this select 0;
                private _k = _unit getVariable ["DUWS_garrisonKey", ""];
                if (_k == "") exitWith {};
                // Recorded lost only when the whole group is down; chip damage with survivors doesn't
                // count -- those survivors come back.
                if (({ alive _x } count units (group _unit)) == 0) then {
                    [_k, _unit getVariable ["DUWS_garrisonToken", ""]] call DUWS_fnc_garrisonRecordLoss;
                };
                [_k] call DUWS_fnc_garrisonReserveOnKill;
            }];
        } forEach units _x;
    } forEach _grps;
};

// Debounced so a mass-casualty moment fires one wave, not one per body; gated on a deep dip so shallow
// attrition waits for the heartbeat. Ceiling reads zero for stowed, cleared or mid-raise alike, so
// nothing-to-pull is one check.
DUWS_fnc_garrisonReserveOnKill = {
    params ["_key"];
    if (!isServer) exitWith {};
    private _atVar = format ["DUWS_zoneReserveEventAt_%1", _key];
    if (diag_tickTime - (missionNamespace getVariable [_atVar, -1e9]) < DUWS_zoneReserveEventDebounce) exitWith {};
    private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
    if (_ceiling <= 0) exitWith {};
    if (([_key] call DUWS_fnc_garrisonReserve) isEqualTo []) exitWith {};
    if (([_key] call DUWS_fnc_garrisonGroupCount) >= DUWS_zoneReinforceFrac * _ceiling) exitWith {};
    missionNamespace setVariable [_atVar, diag_tickTime];
    [_key] spawn DUWS_fnc_garrisonReserveRefillOne;
};

// Truck token keys ("truck" -> opfor_COVERED_TRUCK_X covered, "transport" -> opfor_TRANS_TRUCK_X open) are
// always real troop carriers, so no kind test is needed -- the earlier isKindOf "Truck" gate rejected
// legitimate mod trucks that don't inherit from vanilla Truck, dropping the whole wave to foot.
// Walked over the config, not a spawned object, since the pick happens before the truck exists. Recurses
// over nested Turrets so a commander cupola on a mod hull counts too; a turret with empty weapons[]
// (cargo/FFV firing seats) does not.
DUWS_fnc_classIsArmed = {
    params ["_class"];
    private _queue = "true" configClasses (configFile >> "CfgVehicles" >> _class >> "Turrets");
    private _armed = false;
    while { !_armed && {count _queue > 0} } do {
        private _t = _queue deleteAt 0;
        if (count (getArray (_t >> "weapons")) > 0) then {
            _armed = true;
        } else {
            _queue append ("true" configClasses (_t >> "Turrets"));
        };
    };
    _armed
};

// Resolved through tokenClass so a pooled auto-detected variant draws the same as a hand-written class;
// empties dropped. Weighted toward an unarmed hull -- a taxi needs no gunner and can't be held up trading
// fire on the run in -- so armed is only drawn when the faction offers nothing else. "" when the side
// defines neither key; the caller then walks the squad in.
DUWS_fnc_reserveTruckClass = {
    private _opts = ["truck", "transport"] apply { [_x, "OPF"] call DUWS_fnc_tokenClass };
    _opts = _opts select { _x != "" };
    if (_opts isEqualTo []) exitWith { "" };
    private _unarmed = _opts select { !([_x] call DUWS_fnc_classIsArmed) };
    if (_unarmed isNotEqualTo []) exitWith { selectRandom _unarmed };
    selectRandom _opts
};

// Driver is the truck's own crew class in a fresh east group, decoupled from the squads it carries -- a
// lost squad never costs the truck its driver, and the driver never sits on any squad's roster. A gunner
// is raised for each armed turret too, sharing the driver's group, so a mod transport that mounts a gun
// doesn't roll in dead, and every teardown path that clears the driver clears them all. Truck is never
// rostered or garrison-flagged -- the dispatch monitor owns its whole life.
DUWS_fnc_garrisonReserveTruckSpawn = {
    params ["_spawnPos", "_center"];
    private _tclass = call DUWS_fnc_reserveTruckClass;
    if (_tclass == "") exitWith { [] };
    private _truck = createVehicle [_tclass, _spawnPos, [], 0, "NONE"];
    _truck setDir (_spawnPos getDir _center);
    // Hold the load aboard through contact -- the dispatch monitor is the only thing that dismounts them.
    _truck setUnloadInCombat [false, false];
    // The vehicle's own crew class into a fresh east group: faction-correct for a mod truck, and east by
    // construction so the driver runs to the objective rather than being read as friendly or fleeing.
    private _crewCls = getText (configFile >> "CfgVehicles" >> _tclass >> "crew");
    if (_crewCls == "") then { _crewCls = "O_Soldier_F" };
    private _drv = createGroup east;
    private _driver = _drv createUnit [_crewCls, _spawnPos, [], 0, "NONE"];
    _driver moveInDriver _truck;
    // A truck that seated no driver would never move: scrap it and let the caller walk the squad in.
    if (isNull (driver _truck)) exitWith { deleteVehicle _driver; deleteVehicle _truck; deleteGroup _drv; [] };
    // An armed transport (some mod trucks mount an MG) would otherwise roll in with a dead gun -- crewed
    // from the driver's group so gunners fight and are torn down on the same paths that delete the driver.
    // Non-FFV turrets only: allTurrets skips the cargo firing seats, which are passengers.
    {
        if ((_truck weaponsTurret _x) isNotEqualTo []) then {
            private _gunner = _drv createUnit [_crewCls, _spawnPos, [], 0, "NONE"];
            _gunner moveInTurret [_truck, _x];
        };
    } forEach allTurrets _truck;
    // Engine reaps the driver group the moment it empties (deleteGroupWhenEmpty), so every teardown path
    // below only deletes the driver, never the group -- a long campaign's delivery runs can't leak empty
    // groups toward the per-side group cap.
    _drv deleteGroupWhenEmpty true;
    [_truck, _drv, _truck emptyPositions "Cargo"]
};

// _grps is every squad aboard: the truck is shared, so its disposal cannot ride any one squad's group.
DUWS_fnc_garrisonReserveDispatch = {
    params ["_key", "_center", "_radius", "_spawnPos", "_truck", "_drv", "_grps"];
    private _debusRaw = _center getPos [_radius + DUWS_reserveDebusOffset, _center getDir _spawnPos];
    private _debusPos = [_debusRaw, 0, 80, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
    if (_debusPos isEqualTo []) then { _debusPos = _debusRaw };

    // CARELESS so the driver runs the route instead of stopping to fight -- the same trick the support
    // transports use to drive/fly through fire (fnc_paradrop, fnc_request_hcCAS). Waypoint is the driver
    // group's own; the debus hunt orders below are on the passenger groups.
    _drv setBehaviour "CARELESS";
    _drv setSpeedMode "FULL";
    private _wp = _drv addWaypoint [_debusPos, 0];
    _wp setWaypointType "MOVE";

    [_key, _center, _radius, _spawnPos, _truck, _drv, _grps, _debusPos] spawn {
        params ["_key", "_center", "_radius", "_spawnPos", "_truck", "_drv", "_grps", "_debusPos"];
        private _rideStart = diag_tickTime;
        waitUntil {
            uiSleep 1;
            !alive _truck
            || {!alive (driver _truck)}    // driver down -- get out and fight, do not sit out the timeout
            || {!canMove _truck}
            || {damage _truck > DUWS_reserveDebusDamageBail}
            || {(_truck distance2D _debusPos) < DUWS_reserveDebusRadius}
            || {diag_tickTime - _rideStart > DUWS_reserveMaxRide}
        };
        // Drop the ride waypoint so it does not fight the escape waypoint added below.
        for "_i" from ((count (waypoints _drv)) - 1) to 0 step -1 do { deleteWaypoint [_drv, _i] };
        // A capture or stow during the ride takes the objective out from under the wave: scrap the whole
        // load -- squads, truck, driver -- rather than debus onto ground that just changed hands. Squads
        // are already rostered, matching the refill loop's own mid-spawn delete path.
        if !([_key] call DUWS_fnc_garrisonHeld) exitWith {
            { { deleteVehicle _x } forEach units _x } forEach _grps;
            { deleteVehicle _x } forEach units _drv;
            if (!isNull _truck) then { deleteVehicle _truck };
        };
        // moveOut, not a get-out order: an ordered dismount only fires from a stopped, live vehicle, and
        // the truck here may be dead, dying or still rolling. Guarded on alive -- brewed-up men are
        // already recorded by the caller's killed-watch.
        {
            private _g = _x;
            { if (alive _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
            if (({ alive _x } count units _g) > 0) then {
                [_g, "hunt", _center, _radius] call fnc_apply_posture;
            };
        } forEach _grps;
        // Points the empty truck off the far side, then hands it to the map cleanup sweep with a delete
        // order instead of scrapping it here -- same KEEP_RADIUS rule a cleared garrison is binned by, so
        // it never blinks out under a player's eyes. binMe overrides the in-use-spare exemption a live
        // AI-crewed truck would otherwise get; the binAt grace lets it pull away first.
        if (alive _truck && {alive (driver _truck)}) then {
            private _escapePos = _center getPos [_radius + DUWS_reserveEscapeDist, _center getDir _spawnPos];
            _drv setBehaviour "CARELESS";
            _drv setSpeedMode "FULL";
            private _ewp = _drv addWaypoint [_escapePos, 0];
            _ewp setWaypointType "MOVE";
        };
        // Crew flagged individually too, not just the hull: a driver or gunner who bailed or dismounted is
        // no longer crew, and a hull-only flag would leave him standing as an orphan nothing reaps.
        _truck setVariable ["DUWS_binMe", true];
        _truck setVariable ["DUWS_binAt", time + 30];
        {
            _x setVariable ["DUWS_binMe", true];
            _x setVariable ["DUWS_binAt", time + 30];
        } forEach units _drv;
    };
};

// Truck-borne squads are committed inline in the refill loop instead -- their delete-on-flip is the
// dispatch monitor's, since the shared truck must not be deleted with just one squad.
DUWS_fnc_garrisonReserveCommit = {
    params ["_key", "_grp", "_roster"];
    if (isNull _grp) exitWith {};
    if ([_key] call DUWS_fnc_garrisonHeld) then {
        _roster append (units _grp);
        [_key, [_grp]] call DUWS_fnc_garrisonReserveWatch;
    } else {
        private _veh = vehicle (leader _grp);
        { deleteVehicle _x } forEach units _grp;
        if (!isNull _veh) then { deleteVehicle _veh };
    };
};

// Bounded three ways -- site held, pool not spent, throttle below the engine wall -- so a stalled player
// frees no room and gets no wave; that's intended. Ceiling is the full x1 capacity, so reserves restore
// the site's designed group count, not just what last deployed.
//
// Infantry batch into trucks (dispatch at half-full, next squad opens a fresh one) so a wave spreads
// across several trucks and no squad is coupled to its ride; vehicle tokens never batch, oversize squads
// and truckless sides walk.
//
// No lock, on purpose: the poll and killed handler can both reach one site at once, so two refills run
// safe rather than serialised -- shared pool/roster/count both stop at the ceiling, each token deleted by
// value located fresh (never a stale index), each refill loads its own trucks from its own locals. A
// latch stuck true by a mid-wave error would silently kill the site's reinforcement for the session.
DUWS_fnc_garrisonReserveRefillOne = {
    params ["_key"];
    if (!isServer) exitWith {};
    private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
    if (_ceiling <= 0) exitWith {};
    private _site = [_key] call fnc_site_at;
    private _center = _site getOrDefault ["pos", []];
    if (_center isEqualTo []) exitWith {};
    private _radius = _site getOrDefault ["radius", 0];
    private _pool = [_key] call DUWS_fnc_garrisonReserve;
    private _roster = [_key] call fnc_zone_roster;

    // Held open across iterations so consecutive squads share one truck; flushed on every loop exit below.
    private _truck = objNull;
    private _drv = grpNull;
    private _trkPos = [];
    private _cap = 0;
    private _used = 0;
    private _aboard = [];
    // _wave/_slots stage the convoy: lead point and bearing set once, every vehicle spaces off it
    // (see DUWS_fnc_reserveWaveSlot).
    private _wave = [];
    private _slots = [];
    // Set instead of exitWith so the loop breaks cleanly and still reaches the flush below -- a bare
    // exitWith here is ambiguous, it may exit the whole function rather than just the loop, and would
    // strand a part-loaded truck undispatched.
    private _spent = false;

    while {
        !_spent
        && {[_key] call DUWS_fnc_garrisonHeld}
        && {count _pool > 0}
        && {([_key] call DUWS_fnc_garrisonGroupCount) < _ceiling}
        && {(call DUWS_fnc_opforGroupCount) < DUWS_zoneGroupCeiling}
    } do {
        // Random fieldable token so a lost group is answered by any of the pool, not a fixed order -- a
        // downed tank might bring another tank or a rifle section. Fieldable: a team always, a vehicle
        // only once AP/settings resolve its class; unfieldable tokens wait in the pool rather than block
        // the wave.
        private _fieldable = _pool select { ([_x] call DUWS_fnc_tokenClass) != "" };
        if (_fieldable isEqualTo []) then { _spent = true } else {
            // Located fresh at delete time, not by the index the list above carried -- a concurrent
            // refill may have taken this token since, so a value now gone from the pool is skipped
            // rather than shifting the delete onto the wrong slot.
            private _fi = _pool find (selectRandom _fieldable);
            if (_fi >= 0) then {
                private _tok = _pool deleteAt _fi;
                private _men = [_tok] call DUWS_fnc_tokenMenCount;
                if (_men == 0) then {
                    // A vehicle or bare-class token owes no infantry men: it drives itself in, unbatched.
                    private _pos = [_center, _radius, _wave, _slots] call DUWS_fnc_reserveWaveSlot;
                    private _grp = [_tok, _center, _radius, "hunt", _pos] call DUWS_fnc_zoneSpawnOne;
                    [_key, _grp, _roster] call DUWS_fnc_garrisonReserveCommit;
                } else {
                    // Trucks are opened only at the point of loading, so an open one always has a squad
                    // aboard, and either room to spare or a full-enough load about to dispatch.
                    if (!isNull _truck && {_aboard isNotEqualTo []} && {_used + _men > _cap}) then {
                        [_key, _center, _radius, _trkPos, _truck, _drv, _aboard] call DUWS_fnc_garrisonReserveDispatch;
                        _truck = objNull; _drv = grpNull; _aboard = []; _used = 0; _cap = 0; _trkPos = [];
                    };
                    if (isNull _truck) then {
                        private _pos = [_center, _radius, _wave, _slots] call DUWS_fnc_reserveWaveSlot;
                        private _made = [_pos, _center] call DUWS_fnc_garrisonReserveTruckSpawn;
                        if (_made isNotEqualTo []) then {
                            _made params ["_mt", "_md", "_mc"];
                            _truck = _mt; _drv = _md; _cap = _mc; _trkPos = _pos;
                        };
                    };
                    if (isNull _truck || {_men > _cap}) then {
                        // Scrap a fresh empty truck first if the oversize squad was the only reason one
                        // was opened -- an empty delivery asset must not be left standing on the far side.
                        if (!isNull _truck && {_aboard isEqualTo []}) then {
                            { deleteVehicle _x } forEach units _drv;
                            deleteVehicle _truck;
                            _truck = objNull; _drv = grpNull; _cap = 0; _trkPos = [];
                        };
                        private _pos = [_center, _radius, _wave, _slots] call DUWS_fnc_reserveWaveSlot;
                        private _grp = [_tok, _center, _radius, "hunt", _pos] call DUWS_fnc_zoneSpawnOne;
                        [_key, _grp, _roster] call DUWS_fnc_garrisonReserveCommit;
                    } else {
                        // Raised orderless so it rides then hunts at the debus; rostered now while the
                        // site is held (the loop's own guard). If a mid-ride capture scraps the ride, the
                        // dispatch monitor deletes the group and leaves the stale roster entry for the
                        // teardown sweep, as for any reserve.
                        private _grp = [_tok, _center, _radius, "none", _trkPos] call DUWS_fnc_zoneSpawnOne;
                        if (!isNull _grp) then {
                            { _x moveInCargo _truck } forEach units _grp;
                            _roster append (units _grp);
                            [_key, [_grp]] call DUWS_fnc_garrisonReserveWatch;
                            _aboard pushBack _grp;
                            _used = _used + _men;
                            if (_used >= (_cap / 2)) then {
                                [_key, _center, _radius, _trkPos, _truck, _drv, _aboard] call DUWS_fnc_garrisonReserveDispatch;
                                _truck = objNull; _drv = grpNull; _aboard = []; _used = 0; _cap = 0; _trkPos = [];
                            };
                        };
                    };
                };
            };
            // Staggered so a wave reads as a run of groups over a few seconds, not a one-frame spawn spike.
            uiSleep 2;
        };
    };
    // Flushes a part-loaded truck so a wave that ends below half full still delivers what it raised. One
    // opened but never boarded (a squad-raise that failed right after) is scrapped instead of left
    // standing empty.
    if (!isNull _truck) then {
        if (_aboard isNotEqualTo []) then {
            [_key, _center, _radius, _trkPos, _truck, _drv, _aboard] call DUWS_fnc_garrisonReserveDispatch;
        } else {
            { deleteVehicle _x } forEach units _drv;
            deleteVehicle _truck;
        };
    };
};

// Most-crowded fight resupplies first; refills are spawned per site so waves stagger independently and one
// site's sleep never holds the next. Iterates the live-garrison registry, so a zone and a town are candidates
// by the same rule -- the one place the two site kinds meet. No BLUFOR-presence gate, matching the kill-event
// path (DUWS_fnc_garrisonReserveOnKill): a held site below its ceiling refills whether or not it is fought.
DUWS_fnc_garrisonReservePass = {
    if (!isServer) exitWith {};
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    private _cand = [];
    {
        private _key = _x;
        private _site = [_key] call fnc_site_at;
        private _pos = _site getOrDefault ["pos", []];
        if (_pos isNotEqualTo []
            && {[_key] call DUWS_fnc_garrisonHeld}
            && {([_key] call DUWS_fnc_garrisonReserve) isNotEqualTo []}) then {
            private _reach = (_site getOrDefault ["radius", 0]) + DUWS_streamArrivalMargin;
            _cand pushBack [count (_players select { (_x distance2D _pos) < _reach }), _key];
        };
    } forEach (missionNamespace getVariable ["DUWS_garrisonSites", []]);

    _cand = [_cand, [], { -(_x select 0) }, "ASCEND"] call BIS_fnc_sortBy;
    { [_x select 1] spawn DUWS_fnc_garrisonReserveRefillOne } forEach _cand;
};

// Launched once at WARCOM init beside the site poller. The poll beat tops sites up during a steady
// grind; the killed handler covers the deep dips between beats.
DUWS_fnc_garrisonReserveLoop = {
    if (!isServer) exitWith {};
    while {true} do {
        // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
        try {
        uiSleep DUWS_zoneReservePollPeriod;
        [] call DUWS_fnc_garrisonReservePass;
        } catch {
            ["ERROR", "RESERVE", format ["reserve pass threw, thread held alive: %1", _exception]] call fnc_log;
            sleep 10;
        };
    };
};
