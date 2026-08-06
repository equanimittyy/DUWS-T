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

// How close a player must come to mark a hardpoint on the map, tighter than any streaming ring so the
// emplacement is revealed about when it comes into view rather than when its garrison streams in.
#define HP_REVEAL_RADIUS 100

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
        private _players = (call BIS_fnc_listPlayers) select { alive _x };
        [_players, _pos, (_site get "radius") + (_o get "buffer"), _o getOrDefault ["airRing", 0]] call fnc_site_nearOrAir
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
    deleteMarker (format ["hpm_%1", _key]);
    // Wrecks left standing for the sweep, not deleted: release drops the pins and schedules disposal.
    [_key] call fnc_duws_release;
    ["INFO", "HARDPOINT", format ["%1 cleared", _key]] call fnc_log;

    // A standalone strongpoint the player hunted down pays a small bounty and announces itself. A zone
    // emplacement pays nothing -- taking the zone already credits its defences -- and neither does a
    // minefield, a hazard cleared rather than a garrison beaten.
    if !((_o get "hpZoneKey") isEqualTo "") exitWith {};
    if ((_o get "hpType") isEqualTo "MINEFIELD") exitWith {};
    [5, "hardpoint_cleared"] call fnc_cp_adjust;
    private _name = DUWS_hardpointName getOrDefault [_o get "hpType", _o get "hpType"];
    private _place = [([_key] call fnc_site_at) get "pos"] call DUWS_fnc_hardpointNearestPlace;
    ["HPdestroyed", [5, _name, _place]] remoteExec ["BIS_fnc_showNotification", [0, -2] select isDedicated, false];
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

    // Zone-coupled hardpoints mirror their parent zone -- up when its garrison is, so a zone's whole
    // defence rises and falls together instead of each emplacement waking on its own ring. Standalone
    // ones wake on presence and stow after their grace, as before.
    private _zk = _o getOrDefault ["hpZoneKey", ""];
    private _up = if (_zk isEqualTo "") then {
        _here || {(_now - (_o getOrDefault ["lastSeen", _now])) < (_o get "grace")}
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

// Files the hardpoint as a streamed site and adopts the composition and men it was just built with.
// The streaming spec is the type's, not the caller's: spawnRadius, grace, neverStream and airRing come
// from DUWS_hardpointStreaming and the loose garrison from DUWS_hardpointGarrison, so the dev tool, the
// zone loop and OPCOM all site a given type the same way and one pair of tables tunes them. hpSide and
// the garrison token are the serialisable spec a later raise rebuilds from.
//
// A standalone hardpoint streams on player presence over its own ring; a zone one -- a _zoneKey names
// its parent -- instead mirrors that zone's garrison, so a zone's whole defence rises and falls
// together rather than each emplacement waking on its own radius. Either way it starts awake because it
// is created deployed and manned -- an occupant asleep over a standing composition would raise a second
// garrison on the first tick -- and the birth-stow below takes it down at once if nothing wants it up.
//
// neverStream (mortar, artillery) is kept resident so OPCOM can task it with no player near: its
// composition is pinned against every stow and release, so only a clear takes the battery down. It
// keeps the tick, unlike a zone's driven emplacement -- the tick's raise/stow arm short-circuits for
// it, but its clearance check still runs, so a destroyed battery is noticed like any other.
//
// _zoneKey ties the hardpoint to a parent zone: it drives streaming (the hardpoint follows that zone)
// and rides the DUWS_hardpoints row for OPCOM. "" is a standalone hardpoint on its own ring.
fnc_hardpoint_register = {
    params ["_key", "_type", "_pos", ["_men", []], ["_side", "opfor"], ["_zoneKey", ""]];
    (DUWS_hardpointStreaming getOrDefault [_type, [600, 300, false, 0]])
        params ["_radius", "_grace", "_neverStream", "_airRing"];
    [_key, _pos, _radius, "stream"] call fnc_site_register;
    private _occ = [_key, "garrison", EAST, 0, _grace, true, false] call fnc_site_occupant_register;
    _occ set ["hpSide", _side];
    _occ set ["hpGarrison", DUWS_hardpointGarrison getOrDefault [_type, ""]];
    _occ set ["hpType", _type];
    _occ set ["airRing", _airRing];
    _occ set ["neverStream", _neverStream];
    _occ set ["hpZoneKey", _zoneKey];
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

    // Registry row for OPCOM and the map readout: [key, pos, type, side, zone, revealed]. Presence is
    // liveness; the clearance check deletes the row when the emplacement falls. Revealed follows the
    // same fog a zone's does -- shown at once with no hardcore fog, hidden until intel finds it under
    // hardcore -- so a hardpoint sited at campaign start is on the map exactly when its zone would be.
    DUWS_hardpoints pushBack [_key, _pos, _type, _side, _zoneKey, !hardcore_mode_enable];
    publicVariable "DUWS_hardpoints";

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

    // Built deployed, but stowed at once if nobody is near to see it -- the way a zone stows at
    // build-out. Otherwise every hardpoint the siting loop lays at campaign start carries its crew for
    // a full grace period while the players are still at their HQ. Resident types are exempt: they
    // never stow. The dev tool spawns onto the player, so its hardpoints stay up.
    if (_neverStream) exitWith {};
    private _up = if (_zoneKey isEqualTo "") then {
        private _players = (call BIS_fnc_listPlayers) select { alive _x };
        [_players, _pos, _radius, _airRing] call fnc_site_nearOrAir
    } else {
        _zoneKey call DUWS_fnc_hardpointZoneAwake
    };
    if (!_up) then {
        _occ set ["awake", false];
        [_key] call DUWS_fnc_hardpointStow;
    };
};
