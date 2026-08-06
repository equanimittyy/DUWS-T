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

// Dispatched, not inline: the raise re-crews statics through DUWS_fnc_manStatics, which sleeps in the
// drop-and-settle, and the poller holds every other site's clock.
DUWS_fnc_hardpointRaiseWorker = {
    params ["_key", "_o"];
    // Confirmed after a pause rather than on the first frame anyone clips the ring: a transiting
    // helicopter would otherwise rebuild the whole emplacement for someone already leaving.
    sleep 5;
    private _site = [_key] call fnc_site_at;
    private _pos = _site get "pos";
    private _ring = (_site get "radius") + (_o get "buffer");
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    // The same presence test the poller used to trigger this, air ring included -- an AA woken by a
    // jet overhead would fail a ground-only recheck and never actually raise.
    if !([_players, _pos, _ring, _o getOrDefault ["airRing", 0]] call fnc_site_nearOrAir) exitWith {
        missionNamespace setVariable [HP_RAISE_SLOT(_key), false];
    };

    // Props and guns back first, then the garrison onto them -- men must not spawn into ground about
    // to carry a bunker, and the guns have to exist before anyone mans them.
    [_key] call fnc_duws_deploy;
    [_key] call fnc_site_roster_clear;
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _men = [_objs, _pos, _o get "hpSide", _key, _o get "hpGarrison"] call fnc_hardpoint_garrison;
    ([_key] call fnc_site_roster) append _men;
    // Peak re-anchored to what actually stood up this cycle, the way a zone re-anchors on raise.
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];
    missionNamespace setVariable [HP_RAISE_SLOT(_key), true];
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
    if (([_key] call fnc_site_alive) > 0) exitWith {};
    [_key, _o] call DUWS_fnc_hardpointClear;
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
    // Wrecks left standing for the sweep, not deleted: release drops the pins and schedules disposal.
    [_key] call fnc_duws_release;
    ["INFO", "HARDPOINT", format ["%1 cleared", _key]] call fnc_log;
};

// One tick per hardpoint per pass, presence answered by the poller. The zone cycle without its
// withdraw and retake arms: a hardpoint is present or not, and standing or cleared.
DUWS_hardpointHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    if (_o getOrDefault ["cleared", false]) exitWith {};
    if (_here) then { _o set ["lastSeen", _now] };

    [_key, _o] call DUWS_fnc_hardpointClearCheck;
    if (_o getOrDefault ["cleared", false]) exitWith {};

    // Resident types (mortar, artillery) never raise or stow -- the clearance check above is the whole
    // tick for them.
    if (_o get "neverStream") exitWith {};

    // A raise in flight owns the hardpoint until it reports, so a player crossing the ring twice
    // cannot start a second raise onto the first.
    if (_o get "raising") exitWith {
        private _res = missionNamespace getVariable [HP_RAISE_SLOT(_key), nil];
        if (isNil "_res") exitWith {};
        missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
        _o set ["raising", false];
        _o set ["awake", _res];
    };

    if (_o get "awake") then {
        if (_now - (_o getOrDefault ["lastSeen", _now]) >= (_o get "grace")) then {
            _o set ["awake", false];
            [_key] call DUWS_fnc_hardpointStow;
        };
    } else {
        if (_here) then {
            _o set ["raising", true];
            missionNamespace setVariable [HP_RAISE_SLOT(_key), nil];
            [_key, _o] spawn DUWS_fnc_hardpointRaiseWorker;
        };
    };
}]];

// [_key, _type, _pos, _men, _side, _garrison, _zoneKey] call fnc_hardpoint_register
//
// Files the hardpoint as a streamed site and adopts the composition and men it was just built with.
// The streaming spec is the type's, not the caller's: spawnRadius, grace, neverStream and airRing all
// come from DUWS_hardpointStreaming, so the dev tool, the zone loop and OPCOM all site a given type
// the same way and one table tunes them. hpSide and hpGarrison are the serialisable spec a later
// raise rebuilds from.
//
// Player-presence, not the AI-aware zone gate: a hardpoint should stand up whenever a player is near
// enough to fight it, whichever side it is. A streamed one starts awake because it is created
// deployed and manned -- an occupant starting asleep over a standing composition would raise a second
// garrison on the first tick.
//
// neverStream (mortar, artillery) is kept resident so OPCOM can task it with no player near: its
// composition is pinned against every stow and release, so only a clear takes the battery down. It
// keeps the tick, unlike a zone's driven emplacement -- the tick's raise/stow arm short-circuits for
// it, but its clearance check still runs, so a destroyed battery is noticed like any other.
//
// _zoneKey ties the hardpoint to a parent zone for OPCOM and the map readout, or "" for a standalone
// one; it and the row appended to DUWS_hardpoints are the only state that leaves this server.
fnc_hardpoint_register = {
    params ["_key", "_type", "_pos", ["_men", []], ["_side", "opfor"], ["_garrison", []], ["_zoneKey", ""]];
    (DUWS_hardpointStreaming getOrDefault [_type, [600, 300, false, 0]])
        params ["_radius", "_grace", "_neverStream", "_airRing"];
    [_key, _pos, _radius, "stream"] call fnc_site_register;
    private _occ = [_key, "garrison", EAST, 0, _grace, true, false] call fnc_site_occupant_register;
    _occ set ["hpSide", _side];
    _occ set ["hpGarrison", _garrison];
    _occ set ["hpType", _type];
    _occ set ["airRing", _airRing];
    _occ set ["neverStream", _neverStream];
    _occ set ["awake", true];
    _occ set ["lastSeen", time];
    ([_key] call fnc_site_roster) append _men;
    // Peak = the garrison it stood up with; its presence marks the hardpoint deployed and worth
    // judging for clearance.
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];

    if (_neverStream) then {
        { [_x, _key, true] call fnc_duws_keep } forEach
            ((DUWS_compositions getOrDefault [_key, []]) select { !isNull _x });
    };

    // Registry row for OPCOM and the map readout: [key, pos, type, side, zone]. Presence is liveness;
    // the clearance check deletes the row when the emplacement falls.
    DUWS_hardpoints pushBack [_key, _pos, _type, _side, _zoneKey];
    publicVariable "DUWS_hardpoints";
    [_key, "garrison", DUWS_hardpointHooks] call fnc_site_hooks_set;
};
