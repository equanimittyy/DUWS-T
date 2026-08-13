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

// Raises one pool token as a reinforcement: placed on the far side, ordered to hunt whatever posture it
// carried in the pool. Flagged as garrison like the initial band, so the search/loot system and the
// roster-scoped teardown treat a reinforcement as the site's own. Whole token: a reserve arrives at full
// strength, since attrition is the ledger of lost tokens, not a thin.
DUWS_fnc_garrisonReserveSpawnOne = {
    params ["_key", "_center", "_radius", "_tok"];
    private _spawnPos = [_center, _radius] call DUWS_fnc_garrisonReservePos;
    private _grp = [_tok, _center, _radius, "hunt", _spawnPos] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then { [_grp, "garrison"] call fnc_search_flag_group };
    _grp
};

// Tops one site back up to its x1 group ceiling out of the pool. Bounded three ways: the site still held
// (live), pool not spent, and the global throttle below the engine wall -- a player making no progress
// frees no room and gets no wave, which is intended. The ceiling is the full x1 capacity, so reserves
// bring a mauled site back to its designed group count, not merely to what last deployed.
//
// No lock, on purpose. The poll and the killed handler can both reach one site at once, and two refills
// are made safe rather than serialised: they share the pool, roster and live group count and both stop
// at the ceiling; each token is deleted by value located fresh, so a token the other refill already took
// is skipped rather than a stale index deleting the wrong slot; and the append is guarded against a
// mid-iteration teardown below. A latch would only save the redundant checks, and one left stuck true by
// a mid-wave error would silently kill the site's reinforcement for the whole session.
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

    while {
        ([_key] call DUWS_fnc_garrisonHeld)
        && {count _pool > 0}
        && {([_key] call DUWS_fnc_garrisonGroupCount) < _ceiling}
        && {(call DUWS_fnc_opforGroupCount) < DUWS_zoneGroupCeiling}
    } do {
        // A random fieldable token, so a lost group is answered by any of the pool rather than a fixed
        // order -- a downed tank might bring another tank or a rifle section. Fieldable is what the side
        // can raise right now: a team always, a vehicle only once its AP and settings resolve its class,
        // and an unfieldable one waits in the pool rather than blocking the wave.
        private _fieldable = _pool select { ([_x] call DUWS_fnc_tokenClass) != "" };
        if (_fieldable isEqualTo []) exitWith {};
        // Located fresh at delete time, not by the index the list above carried: a concurrent refill of
        // the same site may have taken this token since, so a value gone from the pool is skipped this
        // iteration rather than shifting the delete onto the wrong slot.
        private _fi = _pool find (selectRandom _fieldable);
        if (_fi >= 0) then {
            private _grp = [_key, _center, _radius, _pool deleteAt _fi] call DUWS_fnc_garrisonReserveSpawnOne;
            // grpNull is dropped, not re-pooled: the throttle keeps this rare and the pool is spent,
            // not regenerated -- a token that hit the engine cap is a wave the site did not get.
            if (!isNull _grp) then {
                // The site can flip during the spawn if a frame-budget yield splits this iteration. The
                // sweep that walks a torn-down garrison off has then already read the roster, so appending
                // here would strand a hunt group on ground that just changed hands. Gated on the live
                // flag, which the teardown drops: gone means clean the stray up instead of rostering it.
                if ([_key] call DUWS_fnc_garrisonHeld) then {
                    _roster append (units _grp);
                    [_key, [_grp]] call DUWS_fnc_garrisonReserveWatch;
                } else {
                    private _veh = vehicle (leader _grp);
                    { deleteVehicle _x } forEach units _grp;
                    if (!isNull _veh) then { deleteVehicle _veh };
                };
            };
        };
        // Staggered so a wave arrives as a run of groups over a few seconds rather than a one-frame
        // spawn spike on the site the player is already fighting.
        uiSleep 2;
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
