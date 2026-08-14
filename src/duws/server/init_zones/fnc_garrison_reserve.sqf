// Locality: server -- every path here raises men, sorts networked lists or reads server-side garrison
// state, none of which a client may do. Executed at load (`[] call compile ...`) to define the globals
// below; the loop and the killed handler are launched later, at WARCOM init.
//
// The reinforcement half of the garrison reserve model, shared by zones and towns alike -- a town is a
// garrison site like a zone, and the only difference is which composition table it draws from. The
// accounting (the pool, the owed-men count, the live group count, the global throttle) is
// fnc_zone_state_init's; the raise seeds the pool and sets the ceiling; the strength ledger is
// fnc_garrison_strength_init's. What is here is the delivery: the refill pass that tops a fought-over
// site back up to its x1 group count out of the pool, the far-side placement that keeps a wave off the
// player's approach, the two triggers that fire it, and the break test that says when a garrison is
// beaten. The model is docs/info/garrison_strength_ledger_plan.md.

// Whether a garrison is beaten: its live men plus the men its reserve pool still owes, worn to a tenth
// of its full fighting potential. One tenth is the campaign's single capture line -- a player learns it
// once -- and it counts the owed reserves so a site cannot fall on an empty perimeter while waves are
// still owed. The denominator is the ledger's full potential; a site with no full stamped is not beaten.
// Read by the zone capture trigger and, for a town, by the tick that clears it.
DUWS_fnc_garrisonBeaten = {
    params ["_key"];
    private _fullMen = [_key] call DUWS_fnc_garrisonFullMen;
    if (_fullMen <= 0) exitWith { false };
    (([_key] call fnc_zone_garrison_count) + ([_key] call DUWS_fnc_garrisonReserveMen)) <= (0.1 * _fullMen)
};

// Whether _unit has an unbroken line of sight to a point over _pos. eyePos is ASL, so the target is
// lifted to standing head height and converted to match. An empty intersection list is a clear line --
// the point is seen. VIEW and GEOM together answer terrain and buildings both.
DUWS_fnc_posSeenBy = {
    params ["_pos", "_unit"];
    private _to = AGLToASL [_pos select 0, _pos select 1, 1.5];
    (lineIntersectsSurfaces [eyePos _unit, _to, _unit, objNull, true, 1, "VIEW", "GEOM"]) isEqualTo []
};

// Where a reinforcement wave stands up: on the site's far side, past the players, preferably unseen.
// Three pulls in priority order over a flat distance floor, so a player never watches a squad appear
// and never gets flanked from their own approach direction.
DUWS_fnc_garrisonReservePos = {
    params ["_center", "_radius"];
    private _reach = _radius + DUWS_streamArrivalMargin;
    private _players = (call BIS_fnc_listPlayers) select { alive _x && {(_x distance2D _center) < _reach} };
    if (_players isEqualTo []) then { _players = (call BIS_fnc_listPlayers) select { alive _x } };

    // Anti-flank, non-negotiable: the reserve comes from the side away from the players, so it meets
    // them head-on as they advance rather than from behind their axis of approach. bluDir is the
    // centre-to-centroid bearing; the spawn sits opposite it.
    private _centroid = _center;
    if (_players isNotEqualTo []) then {
        private _cx = 0; private _cy = 0;
        { private _p = getPosATL _x; _cx = _cx + (_p select 0); _cy = _cy + (_p select 1) } forEach _players;
        _centroid = [_cx / count _players, _cy / count _players];
    };
    private _antiDir = (_center getDir _centroid) + 180;

    // Soft nudge toward the nearest OPFOR zone, so the wave reads as coming from friendly ground when the
    // geometry allows. Clamped to a narrow arc off the anti-approach bearing: the anti-flank rule wins any
    // conflict, so this only ever bends the spawn, never swings it back toward the players. Zones are the
    // nearest friendly-ground signal there is; a town reserve nudges toward one all the same.
    private _others = (missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []]) select {
        (_x distance2D _center) > _radius
    };
    if (_others isNotEqualTo []) then {
        private _near = ([_others, [], { _center distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        // Signed shortest turn from the anti-approach bearing toward the zone bearing, in -180..180,
        // then clamped to +-50 degrees.
        private _delta = ((( _center getDir _near) - _antiDir + 540) mod 360) - 180;
        _antiDir = _antiDir + ((_delta max -50) min 50);
    };

    // Start the ray just past the zone on the far side. The per-player reject in the candidate loop below
    // is the real floor -- it keeps every man DUWS_zoneReserveSpawnDist clear of the players -- so the
    // base distance only has to clear the objective, not reach past the fireteam. Adding the farthest
    // player's range on top of that stood the wave a kilometre out the back of the zone, a blob too far
    // to close on the objective before the fight was over.
    private _baseDist = _radius + DUWS_zoneReserveSpawnDist;

    // A few candidate bearings off the anti-approach line; keep the one the fewest players can see.
    // Bounded, and cast at spawn time only -- a wave every few minutes, a handful of rays per candidate
    // -- so the cost never lands on a frame budget. Prefer-hidden, accept-best: it never blocks a spawn.
    private _best = [];
    private _bestSeen = 1e9;
    {
        private _cand = [_center getPos [_baseDist, _antiDir + _x], 0, 200, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
        // Snap onto the nearest road so the truck-borne wave stands up on drivable ground. Done before
        // the seen-check and the floor reject so both judge the point the wave actually spawns on: a road
        // segment can sit closer to the players or in worse cover than the raw candidate.
        if (_cand isNotEqualTo []) then { _cand = [_cand] call DUWS_fnc_reserveRoadSnap };
        // Reject an empty result (findSafePos hands back [] on bad ground) and one it pulled back
        // inside the floor. An empty candidate must not reach the spawners: they read [] as "no
        // override" and would drop the reserve into the objective band, on top of the players.
        if (_cand isNotEqualTo [] && {(_players findIf { (_cand distance2D _x) < DUWS_zoneReserveSpawnDist }) < 0}) then {
            private _seen = { [_cand, _x] call DUWS_fnc_posSeenBy } count _players;
            if (_seen < _bestSeen) then { _bestSeen = _seen; _best = _cand };
        };
    } forEach [0, 30, -30, 60, -60];

    if (_best isEqualTo []) exitWith {
        // No bearing cleared the floor -- bad ground on every one. Better a far visible spawn than
        // none: the plain anti-approach point at the base distance, floor unenforced. getPos is used
        // rather than findSafePos so this can never itself return [] and collapse into the band.
        _center getPos [_baseDist, _antiDir]
    };
    _best
};

// Nearest road to a point, or the point unchanged when none is within DUWS_zoneReserveRoadSearch. The
// reserve rides trucks, so a wave stands up on drivable ground. Sorted here rather than trusting
// nearRoads' own order.
DUWS_fnc_reserveRoadSnap = {
    params ["_pos"];
    private _roads = _pos nearRoads DUWS_zoneReserveRoadSearch;
    if (_roads isEqualTo []) exitWith { _pos };
    getPosATL (([_roads, [], { _pos distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0)
};

// One spaced spawn slot for a wave. The lead point is pushed _i gaps back along _dir -- the outbound
// bearing, so the tail runs away from the objective and the players, never toward them -- then snapped to
// a road near there. A multi-vehicle wave lines up nose-to-tail on drivable ground with room between, and
// successive vehicles can take different roads rather than stacking on one point. If the snapped or the
// plain point would land within a gap of one already placed this wave, it steps another gap out and
// retries: good spacing outranks being exactly on a road, since two vehicles on one point brew up on
// spawn. Bounded retries, then the plain spaced point regardless.
DUWS_fnc_reserveConvoySlot = {
    params ["_lead", "_dir", "_i", "_slots"];
    private _out = [];
    private _step = _i;
    private _tries = 0;
    while { _out isEqualTo [] && {_tries < 6} } do {
        _tries = _tries + 1;
        private _raw = _lead getPos [_step * DUWS_reserveConvoyGap, _dir];
        private _snap = [_raw] call DUWS_fnc_reserveRoadSnap;
        if ((_slots findIf { (_snap distance2D _x) < DUWS_reserveConvoyGap }) < 0) then {
            _out = _snap;
        } else {
            if ((_slots findIf { (_raw distance2D _x) < DUWS_reserveConvoyGap }) < 0) then {
                _out = _raw;
            } else {
                _step = _step + 1;
            };
        };
    };
    if (_out isEqualTo []) then { _out = _lead getPos [_step * DUWS_reserveConvoyGap, _dir] };
    _out
};

// Hands the next convoy slot for a refill wave and records it. _wave carries the wave's lead point and
// outbound bearing, chosen once on the first call and reused after, so every vehicle in the wave lines up
// off the same lead rather than each re-picking a far-side point and stacking on it. Both _wave and
// _slots are the caller's own arrays, mutated in place (arrays pass by reference), so the running wave
// state lives in the refill loop, not here.
DUWS_fnc_reserveWaveSlot = {
    params ["_center", "_radius", "_wave", "_slots"];
    if (_wave isEqualTo []) then {
        private _lead = [_center, _radius] call DUWS_fnc_garrisonReservePos;
        _wave set [0, _lead];
        _wave set [1, _center getDir _lead];
    };
    private _pos = [_wave select 0, _wave select 1, count _slots, _slots] call DUWS_fnc_reserveConvoySlot;
    _slots pushBack _pos;
    _pos
};

// Hangs a killed handler on a site's groups. It does two jobs: records the group's token into the loss
// ledger when the group is wiped, and pulls an immediate refill wave on a deep dip. Called for the
// initial garrison and for every reserve that later joins it, so a wiped reinforcement is both recorded
// and answered. The key and the group's source token ride each unit rather than the group, which a dead
// man can outlive. The token was tagged on the group by DUWS_fnc_zoneSpawnOne when it was raised.
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
                // Record the token lost only when its whole group is down -- destroy the group, lose the
                // token. Chip damage that leaves survivors is not recorded, so the survivors come back.
                if (({ alive _x } count units (group _unit)) == 0) then {
                    [_k, _unit getVariable ["DUWS_garrisonToken", ""]] call DUWS_fnc_garrisonRecordLoss;
                };
                [_k] call DUWS_fnc_garrisonReserveOnKill;
            }];
        } forEach units _x;
    } forEach _grps;
};

// The event path. Debounced so a mass-casualty moment fires one wave, not one per body, and gated on a
// deep dip so shallow attrition waits for the heartbeat. Nothing to pull if the pool is spent or the
// site has no live ceiling -- stowed, cleared or mid-raise all read as zero.
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

// Picks the reserve's delivery truck: the faction's own troop-transport keys -- the covered
// (opfor_COVERED_TRUCK_X, the "truck" token) and the open (opfor_TRANS_TRUCK_X, the "transport" token).
// Both are defined per faction as actual troop carriers, so no kind test is needed to keep infantry off a
// car or a technical: these keys never name one, and the earlier isKindOf "Truck" gate only rejected
// legitimate mod trucks that do not inherit from the vanilla Truck class, dropping the whole wave to foot.
// Resolved through tokenClass so an auto-detected faction's pooled variant is drawn the same as a
// hand-written class; empties dropped. selectRandom for variety across a wave; "" when the side defines
// neither key, and the caller then walks the squad in.
DUWS_fnc_reserveTruckClass = {
    private _opts = ["truck", "transport"] apply { [_x, "OPF"] call DUWS_fnc_tokenClass };
    _opts = _opts select { _x != "" };
    if (_opts isEqualTo []) exitWith { "" };
    selectRandom _opts
};

// Stands up an empty delivery truck and its lone driver on the far side, ready to be loaded. The driver
// is the truck's own configured crew class raised into an east group of its own -- decoupled from the
// squads it carries, so a lost squad never costs the truck its driver and the driver never sits on any
// squad's roster. One driver only: it is a taxi, and the covered and open troop trucks it draws carry no
// gun to crew. The truck is never rostered or garrison-flagged; the dispatch monitor owns its whole life. Returns
// [truck, driverGroup, cargoSeats], or [] when no truck resolves or none seats a driver.
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
    // The engine reaps the driver group the moment it empties, so every teardown path below -- despawn,
    // mid-ride scrap, the oversize-squad scrap -- only has to delete the driver, never the group, and a
    // long campaign's worth of delivery runs cannot leak empty groups toward the per-side group cap.
    _drv deleteGroupWhenEmpty true;
    [_truck, _drv, _truck emptyPositions "Cargo"]
};

// Sends one loaded truck on its way and hands its passengers off. Driven CARELESS so the man at the wheel
// runs the route instead of stopping to fight, to a debus point short of the objective on the far side;
// held aboard through contact; then every squad hard-ejected in cover to hunt the zone centre. Same
// failure modes as any ride -- truck killed, driver down, immobilised, heavily damaged, arrived, or a
// hard ride ceiling -- each ending the ride and dropping whoever is left. A capture mid-ride scraps the
// whole load, truck and driver included, rather than debussing onto ground no longer OPFOR. Finally the
// driver runs the empty truck off the field and it despawns on a fixed timer. _grps is every squad
// aboard: the truck is shared, so its disposal cannot ride any one squad's group.
DUWS_fnc_garrisonReserveDispatch = {
    params ["_key", "_center", "_radius", "_spawnPos", "_truck", "_drv", "_grps"];
    private _debusRaw = _center getPos [_radius + DUWS_reserveDebusOffset, _center getDir _spawnPos];
    private _debusPos = [_debusRaw, 0, 80, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
    if (_debusPos isEqualTo []) then { _debusPos = _debusRaw };

    // CARELESS so the driver runs the route instead of stopping to fight -- the same trick the support
    // transports use to drive/fly through fire (fnc_paradrop, fnc_request_hcCAS). The waypoint is the
    // driver group's own; the debus hunt orders the passengers take below are on their own groups.
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
        // A capture or stow during the ride takes the objective out from under the wave: scrap it -- every
        // squad aboard, the truck and the driver -- rather than debus onto ground that just changed hands.
        // The squads are already on the roster, matching the refill loop's own mid-spawn delete path.
        if !([_key] call DUWS_fnc_garrisonHeld) exitWith {
            { { deleteVehicle _x } forEach units _x } forEach _grps;
            { deleteVehicle _x } forEach units _drv;
            if (!isNull _truck) then { deleteVehicle _truck };
        };
        // moveOut, not a get-out order: the truck may be dead, dying or still rolling on the timeout path,
        // and an ordered dismount only fires from a stopped, live vehicle. A hard eject is the one exit
        // that fires in every state. Guarded on alive, since men may have brewed up with the truck --
        // their loss is already recorded by the caller's killed-watch.
        {
            private _g = _x;
            { if (alive _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
            if (({ alive _x } count units _g) > 0) then {
                [_g, "hunt", _center, _radius] call fnc_apply_posture;
            };
        } forEach _grps;
        // The driver's work is done: point the empty truck off the far side, away from the players, then
        // hand it to the map cleanup sweep with a delete order rather than scrapping it here. Flagged on the
        // hull, it and its driver are reaped together once they are KEEP_RADIUS clear of every player -- the
        // same rule the sweep bins a cleared garrison by, so a delivery truck never blinks out under a
        // player's eyes and needs no despawn timer of its own. binMe overrides the in-use spare a live
        // AI-crewed mobile truck would otherwise get; the small binAt grace lets it pull away first.
        if (alive _truck && {alive (driver _truck)}) then {
            private _escapePos = _center getPos [_radius + DUWS_reserveEscapeDist, _center getDir _spawnPos];
            _drv setBehaviour "CARELESS";
            _drv setSpeedMode "FULL";
            private _ewp = _drv addWaypoint [_escapePos, 0];
            _ewp setWaypointType "MOVE";
        };
        _truck setVariable ["DUWS_binMe", true];
        _truck setVariable ["DUWS_binAt", time + 30];
    };
};

// Rosters and killed-watches a standalone reserve group, or clears it if the site flipped during its
// raise. The truck-borne squads are committed inline in the refill loop instead: their delete-on-flip is
// the dispatch monitor's, since the truck they ride is shared and must not be deleted with one squad.
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

// Tops one site back up to its x1 group ceiling out of the pool. Bounded three ways: the site still held
// (live), pool not spent, and the global throttle below the engine wall -- a player making no progress
// frees no room and gets no wave, which is intended. The ceiling is the full x1 capacity, so reserves
// bring a mauled site back to its designed group count, not merely to what last deployed.
//
// Infantry ride in, batched: consecutive squads share one truck until it is at least half full, then it
// is dispatched and the next squad opens a fresh truck -- so a wave arrives spread across several trucks
// rather than packed into one, and no squad is coupled to the vehicle carrying it. Vehicle tokens drive
// themselves in and never batch; a squad too big for a whole truck, or a side that fields no truck, walks.
//
// No lock, on purpose. The poll and the killed handler can both reach one site at once, and two refills
// are made safe rather than serialised: they share the pool, roster and live group count and both stop
// at the ceiling; each token is deleted by value located fresh, so a token the other refill already took
// is skipped rather than a stale index deleting the wrong slot; and each refill loads its own trucks from
// its own locals. A latch would only save the redundant checks, and one left stuck true by a mid-wave
// error would silently kill the site's reinforcement for the whole session.
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

    // The truck currently being loaded, held open across iterations so consecutive squads share it.
    // Dispatched and replaced once at least half its cargo is filled; flushed on every loop exit below.
    private _truck = objNull;
    private _drv = grpNull;
    private _trkPos = [];
    private _cap = 0;
    private _used = 0;
    private _aboard = [];
    // Convoy staging for the wave: _wave holds the lead point and outbound bearing (set on the first
    // spawn, reused after); _slots is every point placed so far, so each vehicle lines up spaced off the
    // lead rather than stacking on it. The whole wave shares one convoy line.
    private _wave = [];
    private _slots = [];
    // Set when the pool holds nothing the side can field right now, to break the loop cleanly and still
    // reach the flush below. A bare exitWith here is ambiguous -- it may exit the whole function rather
    // than just the loop -- and would then strand a part-loaded truck undispatched.
    private _spent = false;

    while {
        !_spent
        && {[_key] call DUWS_fnc_garrisonHeld}
        && {count _pool > 0}
        && {([_key] call DUWS_fnc_garrisonGroupCount) < _ceiling}
        && {(call DUWS_fnc_opforGroupCount) < DUWS_zoneGroupCeiling}
    } do {
        // A random fieldable token, so a lost group is answered by any of the pool rather than a fixed
        // order -- a downed tank might bring another tank or a rifle section. Fieldable is what the side
        // can raise right now: a team always, a vehicle only once its AP and settings resolve its class,
        // and an unfieldable one waits in the pool rather than blocking the wave.
        private _fieldable = _pool select { ([_x] call DUWS_fnc_tokenClass) != "" };
        if (_fieldable isEqualTo []) then { _spent = true } else {
            // Located fresh at delete time, not by the index the list above carried: a concurrent refill
            // of the same site may have taken this token since, so a value gone from the pool is skipped
            // this iteration rather than shifting the delete onto the wrong slot.
            private _fi = _pool find (selectRandom _fieldable);
            if (_fi >= 0) then {
                private _tok = _pool deleteAt _fi;
                private _men = [_tok] call DUWS_fnc_tokenMenCount;
                if (_men == 0) then {
                    // A vehicle or bare-class token owes no infantry men: it drives itself in, unbatched.
                    private _pos = [_center, _radius, _wave, _slots] call DUWS_fnc_reserveWaveSlot;
                    private _grp = [_tok, _center, _radius, "hunt", _pos] call DUWS_fnc_zoneSpawnOne;
                    if (!isNull _grp) then { [_grp, "garrison"] call fnc_search_flag_group };
                    [_key, _grp, _roster] call DUWS_fnc_garrisonReserveCommit;
                } else {
                    // Send the open truck off if this squad will not fit what is left in it, then make sure
                    // a truck is open. Trucks are opened only at the point of loading, so an open one always
                    // has a squad aboard and either room to spare or a full-enough load about to dispatch.
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
                        // No truck fielded, or a squad too big for a whole one: walk it in. Scrap a fresh
                        // empty truck first if the oversize squad was the only reason one was opened -- an
                        // empty delivery asset must not be left standing on the far side.
                        if (!isNull _truck && {_aboard isEqualTo []}) then {
                            { deleteVehicle _x } forEach units _drv;
                            deleteVehicle _truck;
                            _truck = objNull; _drv = grpNull; _cap = 0; _trkPos = [];
                        };
                        private _pos = [_center, _radius, _wave, _slots] call DUWS_fnc_reserveWaveSlot;
                        private _grp = [_tok, _center, _radius, "hunt", _pos] call DUWS_fnc_zoneSpawnOne;
                        if (!isNull _grp) then { [_grp, "garrison"] call fnc_search_flag_group };
                        [_key, _grp, _roster] call DUWS_fnc_garrisonReserveCommit;
                    } else {
                        // Raise the squad orderless so it rides then hunts at the debus, board it, and
                        // roster it now while the site is held (the loop's own guard). If a mid-ride capture
                        // later scraps the ride the dispatch monitor deletes the group; the stale roster
                        // entry is the teardown sweep's to clear, as for any reserve.
                        private _grp = [_tok, _center, _radius, "none", _trkPos] call DUWS_fnc_zoneSpawnOne;
                        if (!isNull _grp) then {
                            { _x moveInCargo _truck } forEach units _grp;
                            [_grp, "garrison"] call fnc_search_flag_group;
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
            // Staggered so a wave arrives as a run of groups over a few seconds rather than a one-frame
            // spawn spike on the site the player is already fighting.
            uiSleep 2;
        };
    };
    // Flush a part-loaded truck so a wave that ends below half full still delivers what it raised. A truck
    // opened but never boarded -- a squad-raise that failed right after it was created -- is scrapped here
    // rather than left standing empty on the far side.
    if (!isNull _truck) then {
        if (_aboard isNotEqualTo []) then {
            [_key, _center, _radius, _trkPos, _truck, _drv, _aboard] call DUWS_fnc_garrisonReserveDispatch;
        } else {
            { deleteVehicle _x } forEach units _drv;
            deleteVehicle _truck;
        };
    };
};

// One pass over every contested garrison site with a pool: refill it. Skips a quiet site -- its pool
// waits until it is being fought, by the same presence test that raises a garrison. The most-crowded
// fight resupplies first, so the site the players are actually in tops up before a lightly-held one.
// Refills are spawned per site, so their waves stagger independently and one site's sleep never holds
// the next. Iterates the live-garrison registry, so a zone and a town are both candidates by the same
// rule -- the one place the two site kinds meet.
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
            if ([_pos, _reach, 1] call fnc_duws_bluforNear) then {
                _cand pushBack [count (_players select { (_x distance2D _pos) < _reach }), _key];
            };
        };
    } forEach (missionNamespace getVariable ["DUWS_garrisonSites", []]);

    _cand = [_cand, [], { -(_x select 0) }, "ASCEND"] call BIS_fnc_sortBy;
    { [_x select 1] spawn DUWS_fnc_garrisonReserveRefillOne } forEach _cand;
};

// The heartbeat: one server loop, launched once at WARCOM init beside the site poller. The 5-minute
// beat tops sites up during a steady grind; the killed handler covers the deep dips between beats.
DUWS_fnc_garrisonReserveLoop = {
    if (!isServer) exitWith {};
    while {true} do {
        uiSleep DUWS_zoneReservePollPeriod;
        [] call DUWS_fnc_garrisonReservePass;
    };
};
