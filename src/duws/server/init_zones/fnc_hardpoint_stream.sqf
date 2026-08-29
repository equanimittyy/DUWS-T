// Locality: server -- the hardpoint streaming hooks and the site registration that reuses the shared
// poller. A hardpoint is a site like a zone: it registers with fnc_site_register, files one garrison
// occupant, and the poller in fnc_site_stream_init cycles it against the shared player list. What
// differs from a zone is the lifecycle -- one gun-and-garrison emplacement that wakes, sleeps and can
// be cleared, but is never captured or retaken -- so the hooks here are the zone's shape stripped to
// that and given a clearance check in place of a capture.
if (!isServer) exitWith {};

// The per-key slot a raise worker files its result in for the tick to adopt, the way a zone's raise
// hands back through ZONE_RAISE_SLOT.
#define HP_RAISE_SLOT(key) (format ["DUWS_hpRaise_%1", key])

// The same handback slot for a resident battery's loose-garrison raise, kept distinct from HP_RAISE_SLOT
// so a mortar or artillery hardpoint can cycle its defenders without disturbing the composition raise it
// never runs.
#define HP_LOOSE_SLOT(key) (format ["DUWS_hpLooseRaise_%1", key])

// How close a player must come to mark a hardpoint on the map, tighter than any streaming ring so the
// emplacement is revealed about when it comes into view rather than when its garrison streams in.
#define HP_REVEAL_RADIUS 100

// An observation post's recon ring, how often it wakes to report, and the odds it actually gets a fix
// off on any given wake. The ring is wider than any garrison stream radius (DUWS_hardpointStreaming) on
// purpose: the post screens its whole sector whether or not its lookouts have streamed in, so a player
// cannot sit just outside the garrison's ring unseen. Reporting on a beat, not continuously, gives the
// player time to break out of the ring; the per-wake chance makes the fix unreliable, so being in the ring
// is a mounting risk rather than a certainty and a player can slip a sector unseen.
#define OP_OBSERVE_RADIUS 1000
#define OP_OBSERVE_PERIOD 60
#define OP_OBSERVE_CHANCE 0.2

// The OPFOR radio-tower amplifier is the live count of uncleared "RADIO" rows, capped. Recomputed
// from the registry whenever a tower is registered or cleared -- never incremented in place -- so it
// cannot drift out of step with what actually stands, and clearing a mast drops the enemy's global
// rep push by a point everywhere at once. Called only for RADIO changes; other types leave it be.
DUWS_fnc_aoi_opforRecount = {
    DUWS_opforRadioLevel = (({(_x select 2) isEqualTo "RADIO"} count DUWS_hardpoints) min AOI_OPFOR_TOWER_CAP);
    ["INFO", "HARDPOINT", format ["OPFOR radio level -> %1", DUWS_opforRadioLevel]] call fnc_log;
};

// zoneKey call DUWS_fnc_hardpointZoneAwake -> is that zone up or coming up. A zone-coupled hardpoint
// reads this instead of its own ring, so its defence rises and falls with the garrison. An
// unregistered zone reads an empty map, fields default false, so one sited before its zone stays down.
//
// raising, not only awake: awake flips true only after the whole garrison spawns -- minutes on a big
// zone -- so gating on it alone raised the emplacement last or never. raising catches the zone as it commits.
DUWS_fnc_hardpointZoneAwake = {
    private _o = [_this, "garrison"] call fnc_site_occupant;
    (_o getOrDefault ["awake", false]) || {_o getOrDefault ["raising", false]}
};

// Dispatched, not inline: the raise re-crews statics through DUWS_fnc_manStatics, which sleeps in the
// drop-and-settle, and the poller holds every other site's clock.
DUWS_fnc_hardpointRaiseWorker = {
    params ["_key", "_o"];
    // Confirmed after a pause rather than on the first frame anyone clips the ring: a transiting
    // helicopter would otherwise rebuild the whole emplacement for someone already leaving.
    sleep 5;
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    // The same trigger that started the raise, re-confirmed after the pause. A zone-coupled hardpoint
    // follows its zone; a standalone one re-tests presence on its ring, air ring included, so an AA
    // woken by a jet overhead is not dropped by a ground-only recheck.
    private _zk = _o getOrDefault ["hpZoneKey", ""];
    private _stillUp = if (_zk isEqualTo "") then {
        [_pos, (_site get "radius") + (_o get "buffer"), _o get "minAI", _o getOrDefault ["airRing", 0]] call fnc_site_bluforOrAir
    } else {
        _zk call DUWS_fnc_hardpointZoneAwake
    };
    if (!_stillUp) exitWith {
        missionNamespace setVariable [HP_RAISE_SLOT(_key), false];
    };

    // Props and guns back first, then the garrison onto them -- men must not spawn into ground about
    // to carry a bunker, and the guns have to exist before anyone mans them.
    [_key] call fnc_duws_deploy;
    [_key] call fnc_site_roster_clear;
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _men = [_objs, _pos, _o get "hpSide", _key, _o get "hpGarrison"] call fnc_hardpoint_garrison;
    ([_key] call fnc_site_roster) append _men;
    // Peak re-anchored to what stood up this cycle; only its presence gates clearCheck, never its value.
    // This deployed-gate is the ledger's garrisonLive analogue, kept here because a hardpoint's own
    // liveness is a latched DUWS_hardpoints row, not that server-only graded ledger (see garrisonHeld).
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];
    missionNamespace setVariable [HP_RAISE_SLOT(_key), true];
};

// A resident battery's loose garrison, brought back on approach. The composition and its gun crew never
// left -- they are pinned so OPCOM can fire the battery with no player near -- so this raises only the
// defenders (fnc_hardpoint_garrison's _looseOnly) and appends them to the standing roster. No composition
// deploy and no re-crew: the pieces are already up and manned. Peak is not touched -- the pieces define
// clearance for these types and are always deployed, so it stays anchored on the crew set from register.
DUWS_fnc_hardpointLooseRaiseWorker = {
    params ["_key", "_o"];
    // Confirmed after a pause, like the composition raise: a helicopter transiting the ring must not
    // stand the defenders up for someone already leaving.
    sleep 5;
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _up = [_pos, (_site get "radius") + (_o get "buffer"), _o get "minAI",
        _o getOrDefault ["airRing", 0]] call fnc_site_bluforOrAir;
    if (!_up) exitWith { missionNamespace setVariable [HP_LOOSE_SLOT(_key), false] };
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _men = [_objs, _pos, _o get "hpSide", _key, _o get "hpGarrison", true] call fnc_hardpoint_garrison;
    ([_key] call fnc_site_roster) append _men;
    missionNamespace setVariable [HP_LOOSE_SLOT(_key), true];
};

// Uncrew, collect, stow -- the zone teardown order, so a gun is empty before its composition stows
// (fnc_duws_stow refuses a crewed member) and the men are collected rather than deleted with the
// props. Pinned guns keep their crew and never stow: the resident-crew step sets that flag, and both
// tests below honour it.
DUWS_fnc_hardpointStow = {
    params ["_key"];
    {
        if (_x isKindOf "StaticWeapon" && {!(_x getVariable ["DUWS_noStow", false])}) then {
            deleteVehicleCrew _x;
        };
    } forEach ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
    [_key] call fnc_site_collect;
    [_key] call fnc_duws_stow;
    // The peak goes with the garrison: a stowed hardpoint has an empty roster and must not read as one
    // beaten. Re-set when it raises again.
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], nil];
};

// Cleared when its own garrison is beaten: the roster is the crew plus the loose defenders, so an
// alive count of zero is the emplacement taken. By roster, not proximity -- a passing patrol does not
// man the gun, and a spatial scan per hardpoint per pass is exactly what the poller forbids inline.
// Judged only while deployed -- DUWS_hpPeak_<key> present -- so a stowed emplacement's empty roster is
// never mistaken for a garrison beaten.
//
// A minefield has no garrison; it is spent when no armed mine is left. A detonated mine deletes
// itself and a defused one goes inactive, so its own hazard list is the count. Judged on its own
// branch because peak, roster and grace say nothing about it -- it never stows, so the mines it holds
// are always the real ones.
DUWS_fnc_hardpointClearCheck = {
    params ["_key", "_o"];
    if ((_o get "hpType") isEqualTo "MINEFIELD") exitWith {
        private _mines = missionNamespace getVariable [format ["DUWS_hpMines_%1", _key], []];
        if (({!isNull _x && {mineActive _x}} count _mines) > 0) exitWith {};
        [_key, _o] call DUWS_fnc_hardpointClear;
    };
    // <= 0 covers a stowed hardpoint (peak nil, defaulted to 0): its men are off the map and there is
    // no roster to beat. Same guard, same reason, as the zone capture test.
    if ((missionNamespace getVariable [format ["DUWS_hpPeak_%1", _key], 0]) <= 0) exitWith {};
    if !(_o get "awake") exitWith {};
    // A radio tower is taken by wrecking its mast, not by beating its garrison: the mast is the one
    // live, damageable member (fnc_hardpoint_build), so the tower stands until it is destroyed even with
    // every defender dead. Judged only while deployed -- the peak guard above -- so the mast being off
    // the map for a stow is never read as one wrecked.
    if ((_o get "hpType") isEqualTo "RADIO") exitWith {
        private _comp = DUWS_compositions getOrDefault [_key, []];
        if ((_comp findIf { !isNull _x && {alive _x} && {typeOf _x isEqualTo DUWS_radioMastClass} }) > -1) exitWith {};
        [_key, _o] call DUWS_fnc_hardpointClear;
    };
    // A mortar pit or artillery battery is taken by wrecking its guns, not by killing their crews:
    // the pieces are pinned resident for OPCOM to task, so a crew killed off an intact gun would
    // otherwise retire a battery that still stands. Judged on the same pieces the garrison crews --
    // static mortars, and artillery vehicles by artilleryScanner -- so a modded battery clears alike.
    if ((_o get "hpType") in ["MORTAR", "ARTY"]) exitWith {
        private _comp = DUWS_compositions getOrDefault [_key, []];
        private _standing = if ((_o get "hpType") isEqualTo "MORTAR") then {
            _comp findIf { !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"} }
        } else {
            _comp findIf { !isNull _x && {alive _x} && {!(_x isKindOf "StaticWeapon")}
                && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1} }
        };
        if (_standing > -1) exitWith {};
        [_key, _o] call DUWS_fnc_hardpointClear;
    };
    if (([_key] call fnc_site_alive) > 0) exitWith {};
    [_key, _o] call DUWS_fnc_hardpointClear;
};

// The place a hardpoint is announced by: the nearer of the closest zone and the closest map town, the
// zone taking a tie and standing in whenever no town is found -- so a name still comes back with the
// civilian town system off, since zones are always present.
DUWS_fnc_hardpointNearestPlace = {
    params ["_pos"];
    private _zoneName = "";
    private _zoneDist = 1e9;
    {
        private _d = _pos distance2D (_x select 1);
        if (_d < _zoneDist) then { _zoneDist = _d; _zoneName = _x select 0 };
    } forEach zone_namePOS_pairs;

    private _townName = "";
    private _townDist = 1e9;
    private _near = nearestLocations [_pos, ["NameCity", "NameVillage", "NameCityCapital", "NameLocal"], worldSize];
    if (count _near > 0) then {
        _townName = text (_near select 0);
        _townDist = _pos distance2D (locationPosition (_near select 0));
    };

    // Town only when strictly closer; the zone takes an exact tie and every case with no town.
    private _place = if (_townName != "" && {_townDist < _zoneDist}) then { _townName } else { _zoneName };
    if (_place isEqualTo "") then { "the area" } else { _place }
};

// Latched -- a cleared hardpoint stays cleared. The site is not retired here: deleting it would mutate
// the map the poller is mid-iteration over, so the occupant is only marked inert, its registry row
// dropped and the composition released to the cleanup sweep. The dev clear and, later, OPCOM retire
// the inert site from outside the pass.
DUWS_fnc_hardpointClear = {
    params ["_key", "_o"];
    _o set ["cleared", true];
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], nil];
    missionNamespace setVariable [format ["DUWS_hpMines_%1", _key], nil];
    // Deleted, not flagged: a cleared hardpoint is destroyed, so it leaves the registry rather than
    // sitting in it as a dead row for OPCOM to filter past every pass.
    private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
    if (_i >= 0) then {
        DUWS_hardpoints deleteAt _i;
        publicVariable "DUWS_hardpoints";
    };
    // A cleared tower is gone from the registry above, so the recount drops the amplifier and its
    // coverage falls with it -- far towns no zone reaches leave OPFOR ground entirely.
    if ((_o get "hpType") isEqualTo "RADIO") then { call DUWS_fnc_aoi_opforRecount };
    deleteMarker (format ["hpm_%1", _key]);
    // The garrison stays where it fell and is handed to the sweep with a delete order, not collected in
    // the player's face. A radio tower falls when its mast is wrecked, so defenders can still be alive
    // at clear; deleting them where the player is looking reads as a bug. Flagged, they despawn once the
    // player is KEEP_RADIUS clear -- the same rule as everything else the sweep bins. The flag lives on
    // the unit, so the later fnc_site_retire roster-clear cannot strip it, and the men are not
    // composition members so release never reaches them; this is what now empties the roster.
    //
    // Both rosters: a resident battery keeps its crew on a separate "crew" roster, so binning only the
    // loose garrison would strand the gunners. The crew roster is empty for every other type, so the
    // second pass is a no-op there.
    {
        {
            if (!isNull _x && {alive _x}) then {
                _x setVariable ["DUWS_binMe", true];
                _x setVariable ["DUWS_binAt", time + 300];
            };
        } forEach ([_key, _x] call fnc_site_roster);
    } forEach ["garrison", "crew"];
    // Wrecks left standing for the sweep, not deleted: release drops the pins and schedules disposal.
    [_key] call fnc_duws_release;
    // The auto-gate trigger is keyed to the composition, not a member, so release never reaches it;
    // drop it here or it evaluates over a cleared key for the rest of the campaign. objNull for every
    // non-roadblock key, so the lookup is a harmless no-op there.
    private _gateTrg = missionNamespace getVariable [format ["DUWS_gateTrg_%1", _key], objNull];
    if (!isNull _gateTrg) then {
        deleteVehicle _gateTrg;
        missionNamespace setVariable [format ["DUWS_gateTrg_%1", _key], nil];
    };
    ["INFO", "HARDPOINT", format ["%1 cleared", _key]] call fnc_log;

    // A standalone strongpoint the player hunted down pays a bounty scaled to its type (DUWS_hardpointBounty)
    // and announces itself. A zone emplacement pays nothing -- taking the zone already credits its defences
    // -- and neither does a minefield, a hazard cleared rather than a garrison beaten.
    if !((_o get "hpZoneKey") isEqualTo "") exitWith {};
    if ((_o get "hpType") isEqualTo "MINEFIELD") exitWith {};
    (DUWS_hardpointBounty getOrDefault [_o get "hpType", [5, 0]]) params ["_cp", "_ap"];
    [_cp, "hardpoint_cleared"] call fnc_cp_adjust;
    if (_ap > 0) then { ["BLU", _ap, "hardpoint_cleared", _ap] call fnc_ap_adjust; };
    private _name = DUWS_hardpointName getOrDefault [_o get "hpType", _o get "hpType"];
    private _place = [([_key] call fnc_site_at) get "pos"] call DUWS_fnc_hardpointNearestPlace;
    private _tgt = [0, -2] select isDedicated;
    // CP and AP each get their own card: a single combined card buried the AP gain in a badge that
    // only ever showed the CP figure, so the AP the player earned went unread.
    ["HPdestroyed", [_cp, _name, _place]] remoteExec ["BIS_fnc_showNotification", _tgt, false];
    if (_ap > 0) then {
        ["HPdestroyedAP", [_ap, _name, _place]] remoteExec ["BIS_fnc_showNotification", _tgt, false];
    };
};

// [_pos] call DUWS_fnc_hardpointOPBurst -- one recon fix from a post at _pos: pin OPFOR's knowledge of
// every live BLUFOR within OP_OBSERVE_RADIUS to a full identification (reveal 4) and red-card each
// compromised player. reveal is a knowledge write, hence server-only. Its left operand must be a unit or a
// group, never a side, so an OPFOR-wide fix means revealing each caught BLUFOR to every live EAST group in
// turn -- allGroups holds only spawned groups, so this reaches the OPFOR actually in play, not the
// virtualised garrisons still behind the site poller. Convoy groups (DUWS_convoy_handled, set by
// fnc_convoy_drive) are skipped: they cruise SAFE on a scripted route, and feeding them this reveal would
// promote the column out of SAFE and false-trip a mission's under-attack test with no real contact. The card
// is remoteExec'd to each player object, so only the compromised player sees it, on their own machine, in SP
// and MP alike. Unconditional: the observe loop
// gates it behind its per-wake roll and the dev map-click tool fires it at 100%, so this holds only the sweep.
DUWS_fnc_hardpointOPBurst = {
    params ["_pos"];
    private _blu = allUnits select { side _x == WEST && {alive _x} && {_x distance2D _pos < OP_OBSERVE_RADIUS} };
    if (_blu isEqualTo []) exitWith {};
    private _opforGroups = allGroups select { side _x == EAST && {!(_x getVariable ["DUWS_convoy_handled", false])} };
    {
        private _u = _x;
        { _x reveal [_u, 4] } forEach _opforGroups;
        if (isPlayer _u) then {
            ["critical", [localize "STR_DUWS_T_OP_COMPROMISED_TITLE", localize "STR_DUWS_T_OP_COMPROMISED_MSG"]]
                remoteExec ["BIS_fnc_showNotification", _u, false];
        };
    } forEach _blu;
};

// [_key, _pos] spawn DUWS_fnc_hardpointOPObserve -- the recon screen a standalone enemy observation post
// runs while it stands. Each period, at OP_OBSERVE_CHANCE odds, it fires a burst (DUWS_fnc_hardpointOPBurst),
// so a post left alive keeps feeding its sector to the enemy and pressures the player to kill it or route
// around its ring -- but the per-wake roll means it can miss, so the ring is a risk, not a certain reveal.
// Runs off the poller on its own clock, so its beat is independent of the streaming tick and it reports
// whether the post is deployed or stowed. Terminates when the post's row leaves DUWS_hardpoints (cleared,
// dev-cleared or retired); the up-to-one-period lag before it notices is harmless -- the post is already gone.
DUWS_fnc_hardpointOPObserve = {
    params ["_key", "_pos"];
    while { (DUWS_hardpoints findIf { (_x select 0) isEqualTo _key }) > -1 } do {
        if (random 1 < OP_OBSERVE_CHANCE) then { [_pos] call DUWS_fnc_hardpointOPBurst };
        sleep OP_OBSERVE_PERIOD;
    };
};

// One tick per hardpoint per pass, presence answered by the poller. The zone cycle without its
// withdraw and retake arms: a hardpoint is present or not, and standing or cleared.
DUWS_hardpointHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    if (_o getOrDefault ["cleared", false]) exitWith {};
    if (_here) then {
        _o set ["lastSeen", _now];

        // Proximity reveal, the way walking into a zone reveals it. Behind _here so the precise player
        // scan only runs when someone is already in the wider streaming ring and this hardpoint is still
        // hidden, and behind the parent zone for a zone-child hardpoint -- the same gate the intel draw
        // applies, so closing on a gun never marks it before its zone is found. fnc_hardpoint_reveal
        // no-ops once the row is flagged, so a player loitering in range does not re-announce it.
        private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
        if (_i > -1 && {!((DUWS_hardpoints select _i) select 5)}) then {
            private _pzk = _o getOrDefault ["hpZoneKey", ""];
            private _parentUp = _pzk isEqualTo "" ||
                { (zone_namePOS_pairs findIf { (_x select 2) && {([_x select 1] call fnc_zone_key) isEqualTo _pzk} }) > -1 };
            if (_parentUp) then {
                private _hpPos = (DUWS_hardpoints select _i) select 1;
                if (((call BIS_fnc_listPlayers) findIf { alive _x && {_x distance2D _hpPos < HP_REVEAL_RADIUS} }) > -1) then {
                    ["ONE", _key] call fnc_hardpoint_reveal;
                };
            };
        };
    };

    [_key, _o] call DUWS_fnc_hardpointClearCheck;
    if (_o getOrDefault ["cleared", false]) exitWith {};

    // Resident-composition types (mortar, artillery, minefield): the pieces and their gun crew are pinned
    // and never stream -- OPCOM tasks the battery with no player near -- but the loose garrison does, so a
    // battery no longer stands its defenders in an empty field for the whole campaign. awake stays true (the
    // pieces are the clearance target and are always up); a private looseUp cycle drives just the defenders.
    // A minefield fields no loose garrison, so the arm falls straight through for it.
    if (_o get "neverStream") exitWith {
        if ((_o get "hpGarrison") isEqualTo "") exitWith {};   // no loose garrison (minefield): nothing to cycle
        // A loose raise in flight owns the garrison until it reports, the way the composition raise arm does.
        if (_o getOrDefault ["looseRaising", false]) exitWith {
            private _res = missionNamespace getVariable [HP_LOOSE_SLOT(_key), nil];
            if (isNil "_res") exitWith {};
            missionNamespace setVariable [HP_LOOSE_SLOT(_key), nil];
            _o set ["looseRaising", false];
            _o set ["looseUp", _res];
        };
        // Held while near, within grace, or with a defender in a fight -- the standalone stow rule. The
        // garrison roster is the loose men alone (the crew is a separate driven occupant), so a defender in
        // COMBAT holds the stow while the crew dueling from a pinned gun does not.
        private _up = _here
            || {(_now - (_o getOrDefault ["lastSeen", _now])) < (_o get "grace")}
            || {([_key] call fnc_site_roster) findIf { alive _x && {behaviour _x isEqualTo "COMBAT"} } > -1};
        if (_o getOrDefault ["looseUp", false]) then {
            if (!_up) then {
                _o set ["looseUp", false];
                [_key] call fnc_site_collect;   // loose roster only; the crew occupant is untouched
            };
        } else {
            if (_up) then {
                _o set ["looseRaising", true];
                missionNamespace setVariable [HP_LOOSE_SLOT(_key), nil];
                [_key, _o] spawn DUWS_fnc_hardpointLooseRaiseWorker;
            };
        };
    };

    // A raise in flight owns the hardpoint until it reports, so a player crossing the ring twice
    // cannot start a second raise onto the first.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [HP_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    // Zone-coupled hardpoints mirror their parent zone -- up when its garrison is, so a zone's whole
    // defence rises and falls together instead of each emplacement waking on its own ring. Standalone
    // ones hold while near, within grace, or in a fight: a roster in COMBAT is the engine's own contact
    // state (fnc_apply_posture spawns them SAFE, the engine promotes them the moment they detect anything),
    // so a gun dueling a player from beyond its ring is not stowed out from under the fight and re-raised
    // at full strength when the player closes again. The roster scan is the bounded list the clear-check
    // already walks, and || defers it to the stow-decision frame -- out of ring and past grace.
    private _zk = _o getOrDefault ["hpZoneKey", ""];
    private _up = if (_zk isEqualTo "") then {
        _here
        || {(_now - (_o getOrDefault ["lastSeen", _now])) < (_o get "grace")}
        || {([_key] call fnc_site_roster) findIf { alive _x && {behaviour _x isEqualTo "COMBAT"} } > -1}
    } else {
        _zk call DUWS_fnc_hardpointZoneAwake
    };
    if (_o get "awake") then {
        if (!_up) then {
            _o set ["awake", false];
            [_key] call DUWS_fnc_hardpointStow;
        };
    } else {
        if (_up) then {
            _o set ["raising", true];
            missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
            [_key, _o] spawn DUWS_fnc_hardpointRaiseWorker;
        };
    };
}]];

// [_key, _open] call fnc_roadblock_gate_set -- raise (_open 1) or lower (0) the live boom of the
// roadblock filed under _key. Re-resolved from the composition every call rather than held as a
// reference: the boom is a streamed prop fnc_duws_deploy re-creates as a new object on each raise, so a
// stored handle would point at a deleted one after the first stow. A no-op while the composition is
// stowed (no member is the gate) -- the trigger below re-opens it on the next arrival once it is back.
fnc_roadblock_gate_set = {
    params ["_key", "_open"];
    private _members = DUWS_compositions getOrDefault [_key, []];
    private _i = _members findIf { !isNull _x && {typeOf _x isEqualTo "Land_BarGate_F"} };
    if (_i < 0) exitWith {};
    (_members select _i) animate ["door_1_rot", _open];
};

// Arms the roadblock's boom as a side-aware auto-gate, mirroring the BLUFOR HQ gate (fnc_BluHQinit) but
// keyed to the composition, not the object: the boom streams, so a netId-bound trigger like the HQ one
// dangles after the first stow. Server-local trigger, so its statements run only where DUWS_compositions
// lives. The boom rises only while an own-side or civilian *mobile vehicle* stands in the area and drops
// when none does, so it passes its own traffic (car, truck, APC/IFV, tank, bike) and civilians, and bars
// the enemy -- and the third party too, unlike a bare "not the enemy" test, which would wave an
// independent faction through the checkpoint. Gated on LandVehicle-minus-StaticWeapon, not any unit, on
// purpose: the roadblock's own crewed statics and foot garrison sit inside the 20m area and, counted as
// friendlies, would pin the boom open forever -- the road never barred. StaticWeapon is itself a
// LandVehicle, so it is carved back out explicitly, or the guns re-pin it. A boom stops vehicles, not men
// (who walk around it), so keying on mobile vehicles is also what it physically does.
fnc_roadblock_gate_arm = {
    params ["_key", "_pos", "_side"];
    if !(isNull (missionNamespace getVariable [format ["DUWS_gateTrg_%1", _key], objNull])) exitWith {};
    private _trg = createTrigger ["EmptyDetector", _pos, false];
    _trg setTriggerArea [20, 20, 0, false, 12];
    _trg setTriggerActivation ["ANY", "PRESENT", true];
    _trg setVariable ["DUWS_gateKey", _key];
    _trg setVariable ["DUWS_gateOwn", [EAST, WEST] select (_side isEqualTo "blufor")];
    _trg setTriggerStatements [
        "{ (side _x == (thisTrigger getVariable 'DUWS_gateOwn') || {side _x == civilian}) && {(vehicle _x) isKindOf 'LandVehicle'} && {!((vehicle _x) isKindOf 'StaticWeapon')} } count thisList > 0",
        "[thisTrigger getVariable 'DUWS_gateKey', 1] call fnc_roadblock_gate_set",
        "[thisTrigger getVariable 'DUWS_gateKey', 0] call fnc_roadblock_gate_set"
    ];
    missionNamespace setVariable [format ["DUWS_gateTrg_%1", _key], _trg];
};

// Files the hardpoint as a streamed site over the composition the caller just built, and either crews it now
// or stows it uncrewed. The streaming spec is the type's, not the caller's: spawnRadius, grace, neverStream
// and airRing come from DUWS_hardpointStreaming and the loose garrison from DUWS_hardpointGarrison, so the
// dev tool, the zone loop and OPCOM all site a given type the same way and one pair of tables tunes them.
// hpSide and the garrison token are the serialisable spec a later raise rebuilds from.
//
// A standalone hardpoint streams on BLUFOR presence over its own ring -- a player, friendly AI, or an
// aircraft in its air ring, the same arrival test a zone answers to; a zone one -- a _zoneKey names its
// parent -- instead mirrors that zone's garrison, so a zone's whole defence rises and falls together rather
// than each emplacement waking on its own radius. The caller builds but never mans it: an emplacement BLUFOR
// are already near (or a resident type) is crewed here and stands deployed, and every other is stowed
// uncrewed at once and re-crewed by the raise worker on approach -- the zone lifecycle, where a garrison
// rises on stream-in, not at build. So campaign start never pays the drop-and-settle for the emplacements
// nobody is near, and an occupant is never left asleep over a standing composition.
//
// neverStream (mortar, artillery, minefield) keeps its composition resident so OPCOM can task it with no
// player near: the pieces and their gun crew are pinned against every stow and release, so only a clear
// takes them down. What still streams is the loose garrison -- the defenders are stowed while the ring is
// empty and raised on approach, so a battery does not stand its patrol in a field nobody visits for the
// whole campaign. It keeps the tick, unlike a zone's driven emplacement: the composition raise/stow arm
// short-circuits for it, but its clearance check runs and, below the short-circuit, a loose-garrison-only
// stow/raise arm cycles the defenders. A minefield has no loose garrison, so only its mines remain.
//
// _zoneKey ties the hardpoint to a parent zone: it drives streaming (the hardpoint follows that zone) and
// rides the DUWS_hardpoints row for OPCOM. "" is a standalone hardpoint on its own ring.
fnc_hardpoint_register = {
    params ["_key", "_type", "_pos", ["_side", "opfor"], ["_zoneKey", ""], ["_dir", 0]];
    (DUWS_hardpointStreaming getOrDefault [_type, [600, 300, false, 0]])
        params ["_radius", "_grace", "_neverStream", "_airRing"];
    [_key, _pos, _radius, "stream"] call fnc_site_register;
    private _occ = [_key, "garrison", EAST, 0, _grace, true, true] call fnc_site_occupant_register;
    _occ set ["hpSide", _side];
    _occ set ["hpGarrison", DUWS_hardpointGarrison getOrDefault [_type, ""]];
    _occ set ["hpType", _type];
    _occ set ["airRing", _airRing];
    _occ set ["neverStream", _neverStream];
    _occ set ["hpZoneKey", _zoneKey];
    _occ set ["lastSeen", time];

    // Registry row for OPCOM and the map readout: [key, pos, type, side, zone, revealed, dir]. Presence
    // is liveness; the clearance check deletes the row when the emplacement falls. Revealed follows the
    // same fog a zone's does -- shown at once with no hardcore fog, hidden until intel finds it under
    // hardcore -- so a hardpoint sited at campaign start is on the map exactly when its zone would be. Dir
    // is the heading it faced; the survey reads a nest neighbour's to score interlocking fire.
    DUWS_hardpoints pushBack [_key, _pos, _type, _side, _zoneKey, !hardcore_mode_enable, _dir];
    publicVariable "DUWS_hardpoints";
    // A newly-registered tower raises the amplifier; recount from the row just pushed.
    if (_type isEqualTo "RADIO") then { call DUWS_fnc_aoi_opforRecount };

    // A small OPFOR-coloured bunker icon carrying the type in caps, no area ring. Created for every
    // registered hardpoint here so the caller need not, and left standing through stow: a marker is a
    // map object, not a streamed unit, so a stowed emplacement still marks its ground. Alpha tracks the
    // reveal flag; fnc_hardpoint_reveal flips it to 1 when the intel system finds this one.
    private _mk = format ["hpm_%1", _key];
    createMarker [_mk, _pos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType "loc_Bunker";
    _mk setMarkerColor (["ColorOPFOR", "ColorBLUFOR"] select (_side isEqualTo "blufor"));
    _mk setMarkerText _type;
    _mk setMarkerSize [1, 1];
    _mk setMarkerAlpha ([0, 1] select (!hardcore_mode_enable));

    [_key, "garrison", DUWS_hardpointHooks] call fnc_site_hooks_set;

    // An enemy observation post runs a recon screen on its own clock (DUWS_fnc_hardpointOPObserve), keyed to
    // the registry row so it dies with the post. OPFOR posts only: a BLUFOR OP (the dev tool can place one)
    // must not report BLUFOR to OPFOR.
    if (_type isEqualTo "OP" && {_side isEqualTo "opfor"}) then { [_key, _pos] spawn DUWS_fnc_hardpointOPObserve; };

    // The boom opens for its own side and bars the enemy; armed once per key, the trigger outlives the
    // stow/deploy cycles the composition goes through.
    if (_type isEqualTo "ROADBLOCK") then { [_key, _pos, _side] call fnc_roadblock_gate_arm; };

    // Crew now or stow. The caller built the composition but never manned it, so the drop-and-settle is
    // paid here only for an emplacement that will actually stand: a resident type, or one BLUFOR are
    // already near. Everything else -- every hardpoint the siting loop lays while the players are still at
    // their HQ -- is stowed uncrewed at once and re-crewed by the raise worker when someone approaches, so
    // campaign start no longer pays the settle for emplacements nobody is near. The dev tool spawns onto
    // the player, so its hardpoints read up and crew immediately.
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _crewNow = {
        private _men = [_objs, _pos, _side, _key, _occ get "hpGarrison"] call fnc_hardpoint_garrison;
        ([_key] call fnc_site_roster) append _men;
        _occ set ["awake", true];
        // Peak = the garrison it stood up with; its presence marks the hardpoint deployed and worth
        // judging for clearance.
        missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];
    };

    if (_neverStream) exitWith {
        // Resident composition (mortar, artillery, minefield): the pieces are pinned against every stow so
        // OPCOM can task the battery with no player near, and a minefield's mines are never stowed off the
        // map. Two occupants -- the zone shape for a site whose parts stream on opposite terms. The gun crew
        // rides a driven "crew" occupant the poller never touches (a frozen crew cannot fire the mission that
        // justifies residency), and the loose garrison stays on the streamed "garrison" occupant, so its stow
        // is the ordinary fnc_site_collect over a crew-free roster. awake stays true (the pieces are the
        // clearance target and are always deployed); looseUp drives just the defenders.
        { [_x, _key, true] call fnc_duws_keep } forEach _objs;
        // Crew the pieces once, resident. Token "" crews the guns and places no loose men. Under a driven
        // occupant so the poller skips it and the clearance peak reads a garrison that is always present.
        private _crew = [_objs, _pos, _side, _key, ""] call fnc_hardpoint_garrison;
        if (count _crew > 0) then {
            ([_key, "crew"] call fnc_site_occupant_register) set ["driven", true];
            ([_key, "crew"] call fnc_site_roster) append _crew;
        };
        _occ set ["awake", true];
        missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key, "crew"] call fnc_site_alive];
        // Loose garrison: stood up now only if BLUFOR are already near, cycled by the tick thereafter.
        private _up = [_pos, _radius, _occ get "minAI", _airRing] call fnc_site_bluforOrAir;
        _occ set ["looseUp", _up];
        if (_up) then {
            ([_key] call fnc_site_roster) append
                ([_objs, _pos, _side, _key, _occ get "hpGarrison", true] call fnc_hardpoint_garrison);
        };
    };

    private _up = if (_zoneKey isEqualTo "") then {
        [_pos, _radius, _occ get "minAI", _airRing] call fnc_site_bluforOrAir
    } else {
        _zoneKey call DUWS_fnc_hardpointZoneAwake
    };
    if (_up) then {
        call _crewNow;
    } else {
        _occ set ["awake", false];
        [_key] call DUWS_fnc_hardpointStow;   // stows the uncrewed composition; the raise re-crews on approach
    };
};
