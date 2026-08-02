// Locality: server -- publishes the zone streaming hooks. Called once from server_fnc_init, after
// the site store and the zone state file it reads.
//
// One hook set shared by every zone: a zone differs from another only in its key, its position and
// its radius, all of which arrive as arguments. This replaces two permanent threads per zone -- the
// streaming loop and fnc_createzone's tail loop, which polled a shared array slot the first one set.
// The handshake between them goes with them: the tick below raises directly and adopts the result,
// which is what the raise flag is for.
if (!isServer) exitWith {};

// How far a fallen zone's survivors are sent. Past the streaming ring, so a group that actually
// walks it ends up outside the radius the player who just took the zone is likely to still be in.
#define WITHDRAW_DISTANCE 800

// No player within this of a survivor before it is collected. Wider than the litter sweep's 300 m
// because these are live men: a body blinking out at 300 m goes unnoticed and a soldier doing it
// does not.
#define WITHDRAW_KEEP_RADIUS 500

// Where a raise files its result for the tick to adopt. Unset while the worker is in flight.
#define ZONE_RAISE_SLOT(K) format ["DUWS_zoneRaise_%1", K]

// Zone turrets get their gunners from the prefab at build time, and the prefab never runs again --
// so a composition that has been stowed comes back with empty guns unless they are re-crewed here.
// Skipped once the zone is BLUFOR's: the emplacements are then the player's to use, which is the
// same reason zone compositions are persistent rather than released on capture.
DUWS_fnc_zoneManStatics = {
    params ["_pos", "_key"];
    if !(_pos in WARCOM_zones_controled_by_OPFOR) exitWith {};
    private _roster = [_key] call fnc_zone_roster;
    private _statics = (DUWS_compositions getOrDefault [_key, []]) select {
        !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"}
    };

    // A gun still carrying the crew the prefab gave it. That gunner is the zone's garrison as much
    // as a spawned one, so he joins the roster rather than holding the objective off the books:
    // unrostered, he denies capture through fnc_opfor_count_at while counting toward neither the
    // peak nor the break line, so killing him is progress the zone never registers.
    { _roster append (crew _x) } forEach (_statics select {count crew _x > 0});

    private _guns = _statics select {count crew _x == 0};
    if (count _guns == 0) exitWith {};
    // Manned to the garrison's strength: a weakened zone gets fewer emplacements manned, not weaker
    // ones. Attrition only, not tier -- these crew the prefab's own guns, and tier picks what the
    // zone spawns alongside itself rather than who stands on its fortifications.
    _guns = [_guns, [_key] call fnc_zone_strength] call fnc_zone_thin;
    private _types = _guns apply {opfor_SOLDIER_X};
    private _spawn = _pos findEmptyPosition [0, 30, opfor_SOLDIER_X];
    if (count _spawn == 0) then { _spawn = _pos };
    private _grp = [_spawn, EAST, _types, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _grp deleteGroupWhenEmpty true;
    // Indexed off the spawned group rather than assumed one-to-one: a group that came back short
    // would otherwise throw here every despawn cycle for the rest of the campaign.
    {
        private _unit = (units _grp) param [_forEachIndex, objNull];
        if (!isNull _unit) then { _unit moveInGunner _x };
    } forEach _guns;
    // On the roster like everything DUWS_fnc_raiseGarrison raises: these are the zone's garrison
    // too, and a blunt radius sweep has no other way to know it.
    _roster append (units _grp);
    // Searchable on the same terms as the rest of the garrison. A gunner is the one defender a
    // player is certain to have to kill, so leaving him unflagged made the objective itself the
    // least rewarding thing in the zone.
    [_grp, "garrison"] call fnc_search_flag_group;
    [_grp, _pos] call bis_fnc_taskDefend;
};

// The emplacement kind: a static weapon and the man on it, which do not stream the same way. The gun
// is campaign property that belongs to whoever holds the ground, so it stows; the man is a defender,
// so he goes. That split is the reason the model divides by what is streamed rather than by side --
// one object and one man, on the same objective, with opposite answers.
//
// Crewing out has to happen here rather than in the garrison sweep: that sweep's man clause tests
// vehicle _x == _x, so a gunner sitting in a static keeps his seat, and stow refuses while any member
// is crewed.
DUWS_zoneEmplacementHooks = createHashMapFromArray [
    ["wake", { params ["_key", "_o"]; [([_key] call fnc_site_at) get "pos", _key] call DUWS_fnc_zoneManStatics }],
    ["sleep", { params ["_key", "_o"];
        {
            if (_x isKindOf "StaticWeapon") then { deleteVehicleCrew _x };
        } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    }]
];

// The structure kind: props, walls and the prefab itself. Stowed, never deleted -- rebuilding them
// from scratch would restore the damage the player did to them, and the emplacements become the
// player's own the moment they take the ground.
DUWS_zoneStructureHooks = createHashMapFromArray [
    ["wake", { params ["_key", "_o"];
        if (_key in DUWS_stowed) then {
            [_key] call fnc_duws_deploy;
            ["INFO", "STREAM", format ["deployed %1", _key]] call fnc_log;
        };
    }],
    ["sleep", { params ["_key", "_o"];
        if ([_key] call fnc_duws_stow) then {
            ["INFO", "STREAM", format ["stowed %1", _key]] call fnc_log;
        };
    }]
];

// Ordered, which is why these two are driven rather than polled: the crews have to be out of the
// guns before the composition holding those guns can be stowed.
DUWS_fnc_zoneStow = {
    params ["_key"];
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "sleep");
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "sleep");
};

// Survivors of a zone that has fallen: ordered off the objective here, collected by the tick once
// nobody can see them go. The order is what makes the collection quiet rather than what performs it
// -- a group that cannot path is still collected on distance, so nothing is left standing whether or
// not the walk works.
//
// Roster-scoped, so only this zone's own garrison goes: a neighbouring town's or a side mission's
// guards are not this zone's to take. Returns the men, for the collection to work through.
//
// Locality: addWaypoint and setBehaviour are ignored unless the group is local to the machine
// issuing them (docs/info/arma_engine_gotchas.md); every group on a zone roster is server-spawned.
DUWS_fnc_zoneSendOff = {
    params ["_key", "_pos"];
    private _men = ([_key] call fnc_zone_roster) select { alive _x };
    private _grps = [];
    { _grps pushBackUnique (group _x) } forEach _men;
    {
        private _grp = _x;
        // The defend and patrol waypoints the spawners gave them would pull them straight back onto
        // the objective. Back to front: deleteWaypoint shifts every later index down, so a forward
        // pass deletes every other one.
        private _wps = waypoints _grp;
        reverse _wps;
        { deleteWaypoint _x } forEach _wps;
        // Outward on the bearing they already stand on, so a group on the far side of the zone does
        // not cross it to leave.
        private _dest = _pos getPos [WITHDRAW_DISTANCE, _pos getDir (leader _grp)];
        private _wp = _grp addWaypoint [_dest, 50];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        _grp setBehaviour "AWARE";
        _grp setSpeedMode "FULL";
        // Saves the collection having to tidy up behind itself: the engine drops the group on the
        // last man, whether he was collected or shot.
        _grp deleteGroupWhenEmpty true;
    } forEach _grps;
    _men
};

// Dispatched rather than run inline: a full composition takes up to a couple of minutes to place,
// and the poller holds the clock of every other site. It files what it raised for the tick to adopt.
DUWS_fnc_zoneRaiseWorker = {
    params ["_key", "_pos", "_size"];
    // Confirmed after a pause rather than acted on the moment anyone clips the perimeter. A
    // helicopter transiting, or a patrol that turns back at the edge, would otherwise rebuild a
    // whole composition for someone already leaving.
    sleep 5;
    if !([_pos, _size + 400, 2] call fnc_duws_bluforNear) exitWith {
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), false];
    };

    // The roster is cleared here rather than where the band is raised, because the turret crews
    // below are garrison too and a roster cleared after them would drop them.
    [_key] call fnc_site_roster_clear;
    // Structure, then emplacement, then men: units must not spawn into ground that is about to have
    // a bunker on it, and the turrets have to exist before anyone mans them.
    [_key, [_key, "structure"] call fnc_site_occupant] call (DUWS_zoneStructureHooks get "wake");
    [_key, [_key, "emplacement"] call fnc_site_occupant] call (DUWS_zoneEmplacementHooks get "wake");
    [_pos, _size, _key] call fnc_zone_spawn;
    missionNamespace setVariable [ZONE_RAISE_SLOT(_key), true];
};

// One tick per zone per pass. Presence, the empty clock and the vacate latch arrive answered.
//
// Each branch below ends the pass for this zone: they are mutually exclusive states of one
// garrison, and the raise in particular must never see a zone that is mid-withdrawal.
DUWS_zoneHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _size = _site get "radius";
    private _opforHolds = _pos in WARCOM_zones_controled_by_OPFOR;

    // A zone the player took, still walking its survivors off. Retried every pass rather than timed
    // out, so a man somebody is standing over is collected when they leave rather than never.
    // Nothing else would collect them -- fnc_repetitive_cleanup takes bodies, wrecks and empty
    // vehicles, never living men.
    if (_o get "withdrawing") exitWith {
        // On a roster of its own, not in the record: a record holds plain values so it can survive a
        // save, and these are object references. The kind names what they are -- men walking off
        // ground they no longer hold.
        private _left = ([_key, "withdrawing"] call fnc_site_roster) select { alive _x };
        // BIS_fnc_ListPlayers, not allPlayers: this is the streaming system's own answer to "is a
        // player here", and the whole collection turns on it. A list that came back empty where it
        // should not would delete every survivor on the first pass, which is precisely the vanishing
        // act the walk-off exists to avoid.
        private _players = call BIS_fnc_ListPlayers;
        {
            private _man = _x;
            if ((_players findIf { _x distance _man < WITHDRAW_KEEP_RADIUS }) < 0) then {
                deleteVehicle _man;
            };
        } forEach _left;
        private _roster = [_key, "withdrawing"] call fnc_site_roster;
        _roster resize 0;
        _roster append (_left select { alive _x });
        // Whatever is still walking goes with BLUFOR's tenure. A retake means they left the zone, so
        // there is nobody to watch it happen, and the garrison that arrives files a roster of its own
        // these men would not be on -- left alive, nothing would collect them.
        if (_opforHolds) then {
            { deleteVehicle _x } forEach _roster;
            [_key, "withdrawing"] call fnc_site_roster_clear;
            _o set ["withdrawing", false];
        };
    };

    // A raise in flight owns this zone until it reports.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [ZONE_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    if !(_o get "awake") exitWith {
        if (_here && {!(_o get "awaitVacate")} && {_opforHolds}) then {
            _o set ["raising", true];
            missionNamespace setVariable [ZONE_RAISE_SLOT(_key), nil];
            [_key, _pos, _size] spawn DUWS_fnc_zoneRaiseWorker;
        };
    };

    // The zone changed hands. The composition is not despawned -- the emplacements are the player's
    // now -- but its surviving OPFOR are a different question. The capture trigger tests over the
    // radius while streaming reaches 400 m further, so the zone can flip with everything in that
    // ring still alive: those units were never inside the test. Bounded rather than open-ended:
    // fnc_zone_capture_ready refuses while more than its break fraction of the peak is alive on the
    // roster anywhere, so this is a fifth of a garrison at worst.
    if !(_opforHolds) exitWith {
        // Before the split: the garrison is about to be walked off and the zone has changed hands,
        // and either ends what the capture test was judging. A peak surviving into this reads a
        // pack-up as a garrison wiped.
        [_key] call fnc_zone_garrison_dropped;
        private _leftovers = [_key, _pos] call DUWS_fnc_zoneSendOff;
        [_key, "withdrawing"] call fnc_site_roster_clear;
        ([_key, "withdrawing"] call fnc_site_roster) append _leftovers;
        _o set ["withdrawing", true];
        _o set ["awake", false];
        // Re-latched, because a retake is not the clean start it looks like. EAST SEIZED only
        // promises BLUFOR are outside the trigger radius; the arrival test reaches 400 m further, so
        // a player who has backed off the objective but is still on the approach is near by its
        // reckoning and would have the new garrison raised in front of them.
        _o set ["awaitVacate", true];
        // The attrition this zone carried is left as it stands. Resetting it to full here handed the
        // player's grinding straight back the moment they lost the ground again; fnc_opfor_cap
        // floors the figure when the flip actually happens.
        if (count _leftovers > 0) then {
            ["INFO", "STREAM", format ["%1 lost; %2 surviving garrison man/men ordered off",
                _key, count _leftovers]] call fnc_log;
        };
    };

    // Streamed out once the ring has been empty for the grace period. The grace restarts every time
    // BLUFOR are seen: the shape this replaces tested once at the timer mark and then pinned the
    // zone permanently if anyone happened to be inside at that instant, so an assault lasting longer
    // than the timer left the zone standing for the rest of the campaign.
    if (!_here && {(_o get "emptySince") >= 0}
        && {diag_tickTime > (_o get "emptySince") + (_o get "grace")}) exitWith {
        // What the player left of the garrison, off the roster and above the line below: the record
        // reads the peak to tell a garrison that finished arriving from one still being placed, and
        // the next statement clears it.
        [_key] call fnc_zone_strength_record;
        [_key] call fnc_zone_garrison_dropped;
        // By roster, not by proximity. A radius sweep took the neighbouring town's garrison with it,
        // and the town then measured its survivors against its baseline and came back thinned for
        // the rest of the campaign.
        private _men = ([_key] call fnc_zone_roster) select { !isNull _x };
        private _vehs = [];
        { if (vehicle _x != _x) then { _vehs pushBackUnique (vehicle _x) } } forEach _men;
        { deleteVehicle _x } forEach _men;
        // After the men, and only if nothing else is aboard: a transport the zone crewed goes with
        // its crew, while one the player left in the ring is not on this roster and stays.
        { if (({alive _x} count crew _x) == 0) then { deleteVehicle _x } } forEach _vehs;
        [_key] call DUWS_fnc_zoneStow;
        _o set ["awake", false];
    };
}]];
