// Locality: server -- every path here raises men, sorts networked zone lists or reads server-side zone
// state, none of which a client may do. Executed at load (`[] call compile ...`) to define the globals
// below; the loop and the killed handler are launched later, at WARCOM init.
//
// The reinforcement half of the zone reserve model. The accounting -- the pool, the owed-men count,
// the live group count and the global throttle -- is fnc_zone_state_init's; fnc_zone_spawn seeds the
// pool and sets the ceiling. What is here is the delivery: the refill pass that tops a fought-over
// zone back up to its x1 group count out of the pool, the far-side placement that keeps a wave off the
// player's approach, and the two triggers that fire it. The model is
// docs/info/zone_reserve_reinforcement_plan.md.

// Whether _unit has an unbroken line of sight to a point over _pos. eyePos is ASL, so the target is
// lifted to standing head height and converted to match. An empty intersection list is a clear line --
// the point is seen. VIEW and GEOM together answer terrain and buildings both.
DUWS_fnc_posSeenBy = {
    params ["_pos", "_unit"];
    private _to = AGLToASL [_pos select 0, _pos select 1, 1.5];
    (lineIntersectsSurfaces [eyePos _unit, _to, _unit, objNull, true, 1, "VIEW", "GEOM"]) isEqualTo []
};

// Where a reinforcement wave stands up: on the zone's far side, past the players, preferably unseen.
// Three pulls in priority order over a flat distance floor, so a player never watches a squad appear
// and never gets flanked from their own approach direction.
DUWS_fnc_zoneReservePos = {
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

    // Soft nudge toward the nearest other OPFOR zone, so the wave reads as coming from friendly ground
    // when the geometry allows. Clamped to a narrow arc off the anti-approach bearing: the anti-flank
    // rule wins any conflict, so this only ever bends the spawn, never swings it back toward the players.
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

    // The floor clears every contesting player, not just the nearest: reach past the farthest one so a
    // spread-out fireteam is still the full distance clear of where the wave starts.
    private _spread = 0;
    { _spread = _spread max (_center distance2D _x) } forEach _players;
    private _baseDist = _radius + _spread + DUWS_zoneReserveSpawnDist;

    // A few candidate bearings off the anti-approach line; keep the one the fewest players can see.
    // Bounded, and cast at spawn time only -- a wave every few minutes, a handful of rays per candidate
    // -- so the cost never lands on a frame budget. Prefer-hidden, accept-best: it never blocks a spawn.
    private _best = [];
    private _bestSeen = 1e9;
    {
        private _cand = [_center getPos [_baseDist, _antiDir + _x], 0, 200, 8, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos;
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

// Hangs a killed handler on a zone's groups so a deep dip pulls an immediate wave. Called for the
// initial garrison and for every reserve that later joins it, so a wiped reinforcement triggers the
// next one. The zone key rides each unit rather than its group, which a dead man can outlive.
DUWS_fnc_zoneReserveWatch = {
    params ["_key", "_grps"];
    {
        {
            _x setVariable ["DUWS_reserveZoneKey", _key];
            _x addEventHandler ["Killed", {
                private _k = (_this select 0) getVariable ["DUWS_reserveZoneKey", ""];
                if (_k != "") then { [_k] call DUWS_fnc_zoneReserveOnKill };
            }];
        } forEach units _x;
    } forEach _grps;
};

// The event path. Debounced so a mass-casualty moment fires one wave, not one per body, and gated on a
// deep dip so shallow attrition waits for the heartbeat. Nothing to pull if the pool is spent or the
// zone has no live ceiling -- stowed, captured or mid-raise all read as zero.
DUWS_fnc_zoneReserveOnKill = {
    params ["_key"];
    if (!isServer) exitWith {};
    private _atVar = format ["DUWS_zoneReserveEventAt_%1", _key];
    if (diag_tickTime - (missionNamespace getVariable [_atVar, -1e9]) < DUWS_zoneReserveEventDebounce) exitWith {};
    private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
    if (_ceiling <= 0) exitWith {};
    if (([_key] call DUWS_fnc_zoneReserve) isEqualTo []) exitWith {};
    if (([_key] call DUWS_fnc_zoneGroupCount) >= DUWS_zoneReinforceFrac * _ceiling) exitWith {};
    missionNamespace setVariable [_atVar, diag_tickTime];
    [_key] spawn DUWS_fnc_zoneReserveRefillOne;
};

// Raises one pool token as a reinforcement: placed on the far side, ordered to hunt whatever posture
// it carried in the pool. Flagged as garrison like the initial band, so the search/loot system and the
// roster-scoped teardown treat a reinforcement as the zone's own.
DUWS_fnc_zoneReserveSpawnOne = {
    params ["_key", "_center", "_radius", "_tok", "_strength"];
    private _spawnPos = [_center, _radius] call DUWS_fnc_zoneReservePos;
    private _grp = [_tok, _center, _radius, _strength, "hunt", _spawnPos] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then { [_grp, "garrison"] call fnc_search_flag_group };
    _grp
};

// Tops one zone back up to its x1 group ceiling out of the pool. Bounded three ways: the zone still
// held (peak up), pool not spent, and the global throttle below the engine wall -- a player making no
// progress frees no room and gets no wave, which is intended. The ceiling is the full x1 capacity, so
// reserves bring a mauled zone back to its designed group count, not merely to what last deployed.
//
// No lock, on purpose. The poll and the killed handler can both reach one zone at once, and two
// refills are made safe rather than serialised: they share the pool, roster and live group count and
// both stop at the ceiling; each token is deleted by value located fresh, so a token the other refill
// already took is skipped rather than a stale index deleting the wrong slot; and the append is guarded
// against a mid-iteration capture below. A latch would only save the redundant checks, and one left
// stuck true by a mid-wave error would silently kill the zone's reinforcement for the whole session.
DUWS_fnc_zoneReserveRefillOne = {
    params ["_key"];
    if (!isServer) exitWith {};
    private _ceiling = missionNamespace getVariable [format ["DUWS_zoneCeiling_%1", _key], 0];
    if (_ceiling <= 0) exitWith {};
    private _site = [_key] call fnc_site_at;
    private _center = _site getOrDefault ["pos", []];
    if (_center isEqualTo []) exitWith {};
    private _radius = _site getOrDefault ["radius", 0];
    private _pool = [_key] call DUWS_fnc_zoneReserve;
    private _roster = [_key] call fnc_zone_roster;

    while {
        (missionNamespace getVariable [format ["DUWS_zonePeak_%1", _key], 0]) > 0
        && {count _pool > 0}
        && {([_key] call DUWS_fnc_zoneGroupCount) < _ceiling}
        && {(call DUWS_fnc_opforGroupCount) < DUWS_zoneGroupCeiling}
    } do {
        private _strength = [_key] call fnc_zone_strength;
        // A random fieldable token, so a lost group is answered by any of the pool rather than a fixed
        // order -- a downed tank might bring another tank or a rifle section. A team always fields; a
        // vehicle only at half strength or better, matching the initial garrison's own thin, so a
        // mauled zone does not pop vehicle tokens it could not stand up. Unfieldables stay in the pool.
        private _fieldable = _pool select {
            (([_x] call DUWS_fnc_teamRow) isNotEqualTo []) || { _strength >= 0.5 }
        };
        if (_fieldable isEqualTo []) exitWith {};
        // Located fresh at delete time, not by the index the list above carried: a concurrent refill of
        // the same zone may have taken this token since, so a value gone from the pool is skipped this
        // iteration rather than shifting the delete onto the wrong slot.
        private _fi = _pool find (selectRandom _fieldable);
        if (_fi >= 0) then {
            private _grp = [_key, _center, _radius, _pool deleteAt _fi, _strength] call DUWS_fnc_zoneReserveSpawnOne;
            // grpNull is dropped, not re-pooled: the throttle keeps this rare and the pool is spent,
            // not regenerated -- a token that hit the engine cap is a wave the zone did not get.
            if (!isNull _grp) then {
                // The zone can flip during the spawn if a frame-budget yield splits this iteration. The
                // sweep that walks a captured garrison off has then already read the roster, so appending
                // here would strand a hunt group on ground that just changed hands. Gated on the peak,
                // which the capture path drops: gone means clean the stray up instead of rostering it.
                if ((missionNamespace getVariable [format ["DUWS_zonePeak_%1", _key], 0]) > 0) then {
                    _roster append (units _grp);
                    [_key, [_grp]] call DUWS_fnc_zoneReserveWatch;
                } else {
                    private _veh = vehicle (leader _grp);
                    { deleteVehicle _x } forEach units _grp;
                    if (!isNull _veh) then { deleteVehicle _veh };
                };
            };
        };
        // Staggered so a wave arrives as a run of groups over a few seconds rather than a one-frame
        // spawn spike on the zone the player is already fighting.
        uiSleep 2;
    };
};

// One pass over every contested OPFOR zone with a pool: refill it. Skips a quiet zone -- its pool waits
// until it is being fought, by the same presence test that raises a garrison. The most-crowded fight
// resupplies first, so the zone the players are actually in tops up before a lightly-held one. Refills
// are spawned per zone, so their waves stagger independently and one zone's sleep never holds the next.
DUWS_fnc_zoneReservePass = {
    if (!isServer) exitWith {};
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    private _cand = [];
    {
        private _pos = _x;
        private _key = [_pos] call fnc_zone_key;
        if ((missionNamespace getVariable [format ["DUWS_zonePeak_%1", _key], 0]) > 0
            && {([_key] call DUWS_fnc_zoneReserve) isNotEqualTo []}) then {
            private _reach = (([_key] call fnc_site_at) getOrDefault ["radius", 0]) + DUWS_streamArrivalMargin;
            if ([_pos, _reach, 1] call fnc_duws_bluforNear) then {
                _cand pushBack [count (_players select { (_x distance2D _pos) < _reach }), _key];
            };
        };
    } forEach (missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []]);

    _cand = [_cand, [], { -(_x select 0) }, "ASCEND"] call BIS_fnc_sortBy;
    { [_x select 1] spawn DUWS_fnc_zoneReserveRefillOne } forEach _cand;
};

// The heartbeat: one server loop, launched once at WARCOM init beside the site poller. The 5-minute
// beat tops zones up during a steady grind; the killed handler covers the deep dips between beats.
DUWS_fnc_zoneReserveLoop = {
    if (!isServer) exitWith {};
    while {true} do {
        uiSleep DUWS_zoneReservePollPeriod;
        [] call DUWS_fnc_zoneReservePass;
    };
};
