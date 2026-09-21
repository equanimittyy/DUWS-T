// Server-only. A hardpoint reuses the zone/site streaming shape (fnc_site_register, one garrison
// occupant, fnc_site_stream_init's poller) but never captures or retakes -- only wakes, sleeps, clears.
if (!isServer) exitWith {};

// Raise-worker handback slot the tick adopts, the zone's ZONE_RAISE_SLOT pattern reused for hardpoints.
#define HP_RAISE_SLOT(key) (format ["DUWS_hpRaise_%1", key])

// Handback slot for a resident battery's loose-garrison raise -- kept distinct from HP_RAISE_SLOT so it
// never disturbs the composition raise this type never runs.
#define HP_LOOSE_SLOT(key) (format ["DUWS_hpLooseRaise_%1", key])

// Tighter than any streaming ring, so a hardpoint reveals about when it comes into view, not when its garrison streams in.
#define HP_REVEAL_RADIUS 100

// Reach kept wider than the garrison stream so a player cannot sit just outside it unseen; the chance
// rolls per tick rather than firing every one, so the fix is a risk to break out of, not a certain reveal.
#define OP_OBSERVE_K 2             // Chebyshev grid cells (OPCOM_GRID_CELL each): k=2 ~ 1000 m on axis
#define OP_OBSERVE_CHANCE 0.02     // per OPCOM tick; ~0.24/min at OPCOM_TICK_PERIOD 5

// OPFOR radio amplifier = live count of uncleared "RADIO" rows, capped. Recomputed from the registry
// rather than incremented in place, so it cannot drift out of step with what actually stands.
DUWS_fnc_aoi_opforRecount = {
    DUWS_opforRadioLevel = (({(_x select 2) isEqualTo "RADIO"} count DUWS_hardpoints) min AOI_OPFOR_TOWER_CAP);
    ["INFO", "HARDPOINT", format ["OPFOR radio level -> %1", DUWS_opforRadioLevel]] call fnc_log;
};

// A zone-coupled hardpoint mirrors this instead of its own ring; an unregistered zone reads an empty
// map and defaults false. Checks raising too: awake alone flips true only once the whole garrison has
// spawned -- minutes on a big zone -- so gating on it alone raised the emplacement late or never.
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
    // Re-confirmed with the same test that started the raise: a standalone hardpoint re-tests its own
    // ring including air ring, so an AA woken by a jet overhead is not dropped by a ground-only recheck.
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
    // Peak re-anchored to what stood up this cycle; only its presence gates clearCheck, never its value --
    // a hardpoint's own liveness is a latched DUWS_hardpoints row, not the graded garrisonHeld ledger.
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];
    missionNamespace setVariable [HP_RAISE_SLOT(_key), true];
};

// Resident battery's loose garrison only -- the pieces and crew are pinned and never left, so this skips
// composition deploy/re-crew and leaves peak untouched (it stays anchored on the crew set at register).
DUWS_fnc_hardpointLooseRaiseWorker = {
    params ["_key", "_o"];
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

// Uncrew, collect, stow -- fnc_duws_stow refuses a crewed member, so a gun must be empty before its
// composition stows. Pinned guns keep their crew and skip this: the resident-crew step flags that.
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

// Cleared when the roster (crew + loose defenders) hits zero, not by proximity -- a passing patrol
// does not man the gun, and a spatial scan per hardpoint per pass is what the poller forbids inline.
// Judged only while deployed (peak present), so a stowed emplacement's empty roster never reads as beaten.
//
// A minefield has no garrison: it is spent when no armed mine is left, judged on its own branch since
// peak/roster/grace say nothing about it -- it never stows, so the mines it holds are always the real ones.
DUWS_fnc_hardpointClearCheck = {
    params ["_key", "_o"];
    if ((_o get "hpType") isEqualTo "MINEFIELD") exitWith {
        private _mines = missionNamespace getVariable [format ["DUWS_hpMines_%1", _key], []];
        private _armed = {!isNull _x && {mineActive _x}} count _mines;
        // The first mine gone -- set off, disarmed or blown -- gives the whole field away.
        if (_armed < count _mines) then { ["ONE", _key] call fnc_hardpoint_reveal };
        if (_armed > 0) exitWith {};
        [_key, _o] call DUWS_fnc_hardpointClear;
    };
    // <= 0 covers a stowed hardpoint too (peak nil defaults to 0) -- same guard as the zone capture test.
    if ((missionNamespace getVariable [format ["DUWS_hpPeak_%1", _key], 0]) <= 0) exitWith {};
    if !(_o get "awake") exitWith {};
    // A radio tower is taken by wrecking its mast, not by beating its garrison -- the mast stands until
    // destroyed even with every defender dead. The peak guard above stops a stowed mast reading as wrecked.
    if ((_o get "hpType") isEqualTo "RADIO") exitWith {
        private _comp = DUWS_compositions getOrDefault [_key, []];
        if ((_comp findIf { !isNull _x && {alive _x} && {typeOf _x isEqualTo DUWS_radioMastClass} }) > -1) exitWith {};
        [_key, _o] call DUWS_fnc_hardpointClear;
    };
    // A mortar/artillery battery is taken by wrecking its guns, not killing crews: the pieces are pinned
    // resident for OPCOM to task, so a crew killed off an intact gun must not retire a battery still standing.
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

// Nearer of the closest zone or town; the zone takes a tie and stands in when no town is found, so a
// name still comes back with the civilian town system off (zones are always present).
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

    private _place = if (_townName != "" && {_townDist < _zoneDist}) then { _townName } else { _zoneName };
    if (_place isEqualTo "") then { "the area" } else { _place }
};

// Latched, not retired here: deleting the site would mutate the map the poller is mid-iteration over, so
// the occupant is only marked inert; the dev clear and, later, OPCOM retire it from outside the pass.
DUWS_fnc_hardpointClear = {
    params ["_key", "_o"];
    _o set ["cleared", true];
    missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], nil];
    missionNamespace setVariable [format ["DUWS_hpMines_%1", _key], nil];
    if ((_o get "hpType") isEqualTo "MINEFIELD") then { remoteExec ["", format ["DUWS_hpMineReveal_%1", _key]] };
    // Deleted, not flagged, so it leaves the registry rather than sitting as a dead row OPCOM filters past every pass.
    private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
    if (_i >= 0) then {
        DUWS_hardpoints deleteAt _i;
        publicVariable "DUWS_hardpoints";
        [_key] call DUWS_fnc_opcom_gridDirty;
    };
    // A cleared tower is gone from the registry above, so the recount drops the amplifier and its
    // coverage falls with it -- far towns no zone reaches leave OPFOR ground entirely.
    if ((_o get "hpType") isEqualTo "RADIO") then { call DUWS_fnc_aoi_opforRecount };
    deleteMarker (format ["hpm_%1", _key]);
    // Flagged for the sweep, not deleted here: a radio tower's defenders can still be alive when its mast
    // is wrecked, and deleting them in the player's face reads as a bug. The flag lives on the unit so the
    // later fnc_site_retire roster-clear cannot strip it; the men aren't composition members, so this is
    // what empties the roster.
    //
    // Both rosters, since a resident battery's crew sits on a separate "crew" roster -- binning only the
    // loose garrison would strand the gunners. Empty for every other type, so that pass is a no-op there.
    {
        {
            if (!isNull _x && {alive _x}) then {
                _x setVariable ["DUWS_binMe", true];
            };
        } forEach ([_key, _x] call fnc_site_roster);
    } forEach ["garrison", "crew"];
    // Wrecks left standing for the sweep, not deleted: release drops the pins and schedules disposal.
    [_key] call fnc_duws_release;
    // The gate trigger is keyed to the composition, not a member, so release never reaches it -- drop it
    // here or it evaluates over a cleared key for the rest of the campaign (objNull elsewhere is a no-op).
    private _gateTrg = missionNamespace getVariable [format ["DUWS_gateTrg_%1", _key], objNull];
    if (!isNull _gateTrg) then {
        deleteVehicle _gateTrg;
        missionNamespace setVariable [format ["DUWS_gateTrg_%1", _key], nil];
    };
    ["INFO", "HARDPOINT", format ["%1 cleared", _key]] call fnc_log;

    // Only a standalone strongpoint pays a bounty and announces itself: a zone emplacement pays nothing
    // (taking the zone already credits its defences), nor does a minefield -- a hazard, not a garrison beaten.
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

// reveal's left operand must be a unit or group, never a side, so an OPFOR-wide fix means revealing to
// every live EAST group -- allGroups holds only spawned groups, reaching OPFOR actually in play, not
// virtualised garrisons behind the site poller. Convoy groups are skipped: revealing them would promote
// a SAFE scripted column out of SAFE and false-trip a mission's under-attack test with no real contact.
// No-ops until the grid is built (isNil guard below); the per-tick roll lives in DUWS_fnc_hardpointOPSense.
DUWS_fnc_hardpointOPBurst = {
    params ["_pos"];
    if (isNil "DUWS_opcom_grid_w") exitWith {};
    private _w = DUWS_opcom_grid_w;
    private _oc  = [_pos] call DUWS_fnc_opcom_w2c;
    private _ocx = _oc mod _w;
    private _ocy = floor (_oc / _w);
    // The distance gate is the cell box's circumscribed radius, so it only spares the per-unit cell lookup.
    private _reach = (OP_OBSERVE_K + 1) * OPCOM_GRID_CELL * 1.415;
    private _blu = allUnits select {
        side _x == WEST && {alive _x} && {(_x distance2D _pos) < _reach} && {
            private _c = [getPosASL _x] call DUWS_fnc_opcom_w2c;
            ((abs ((_c mod _w) - _ocx)) max (abs ((floor (_c / _w)) - _ocy))) <= OP_OBSERVE_K
        }
    };
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

    // A guaranteed belief write, not just the reveal above: a stowed post with no live observer still feeds
    // the commander. No separate OPCOM guard needed -- belief is built before the grid, so it already exists.
    // Unique groups first: sightStr walks a whole group, so price once per group, not once per unit aboard.
    private _seenG = [];
    { _seenG pushBackUnique (group _x) } forEach _blu;
    {
        private _bp = getPosASL (leader _x);
        _bp set [2, 0];
        [netId _x, _bp, [_x] call DUWS_fnc_opcom_sightStr] call fnc_opcom_belief_upsert;
    } forEach _seenG;
};

// Reads the registry live, so a cleared post drops out with no per-post loop to terminate. OPFOR posts
// only: a BLUFOR OP (the dev tool can place one) must not report BLUFOR to OPFOR.
DUWS_fnc_hardpointOPSense = {
    if (isNil "DUWS_opcom_grid_w") exitWith {};
    {
        if ((_x select 2) isEqualTo "OP" && {(_x select 3) isEqualTo "opfor"}) then {
            private _pos = _x select 1;
            // Coverage stamps every tick, unlike the detection roll: an OP post's radius always reads
            // swept-clear, so ground a standing post overlooks is never mistaken for never-seen.
            [_pos, OP_OBSERVE_K] call fnc_opcom_cover_stamp;
            if (random 1 < OP_OBSERVE_CHANCE) then {
                [_pos] call DUWS_fnc_hardpointOPBurst;
                // After the burst, not gated on it finding anyone: a fired post that turned up nobody is the strongest clear.
                [_pos, OP_OBSERVE_K] call fnc_opcom_cover_clear;
            };
        };
    } forEach DUWS_hardpoints;
};

// The zone poller's hook shape stripped of leftovers and retake: a hardpoint is only present or not, standing or cleared.
DUWS_hardpointHooks = createHashMapFromArray [["tick", {
    params ["_key", "_o", "_here", "_now"];
    if (_o getOrDefault ["cleared", false]) exitWith {};
    if (_here) then {
        _o set ["lastSeen", _now];

        // Gated behind _here so the precise player scan only runs inside the wider streaming ring, and
        // behind the parent zone for a zone-child hardpoint -- closing on a gun never marks it before its
        // zone is found. fnc_hardpoint_reveal itself no-ops once flagged, so loitering in range doesn't re-announce it.
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

    // Resident types keep pieces/crew pinned (OPCOM tasks with no player near) but still stream the loose
    // garrison; awake stays true since the pieces are always up. A minefield has no loose garrison to cycle.
    if (_o get "neverStream") exitWith {
        if ((_o get "hpGarrison") isEqualTo "") exitWith {};   // no loose garrison (minefield): nothing to cycle
        if (_o getOrDefault ["looseRaising", false]) exitWith {
            private _res = missionNamespace getVariable [HP_LOOSE_SLOT(_key), nil];
            if (isNil "_res") exitWith {};
            missionNamespace setVariable [HP_LOOSE_SLOT(_key), nil];
            _o set ["looseRaising", false];
            _o set ["looseUp", _res];
        };
        // Garrison roster is the loose men alone (crew is a separate driven occupant), so a defender in
        // COMBAT holds the stow here while the crew dueling from a pinned gun does not.
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

    // Standalone hardpoints hold while near, within grace, or in a fight: COMBAT is the engine's own
    // contact state (fnc_apply_posture spawns SAFE, the engine promotes on detection), so a gun dueling a
    // player from beyond its ring isn't stowed out from under the fight and re-raised at full strength.
    // The roster scan is the bounded list the clear-check already walks; || defers it to this frame.
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

// Re-resolved from the composition every call, not held as a reference: fnc_duws_deploy re-creates the
// boom as a new object on each raise, so a stored handle would point at a deleted one after the first
// stow. No-ops while stowed; the trigger below re-opens it on the next arrival once it's back.
fnc_roadblock_gate_set = {
    params ["_key", "_open"];
    private _members = DUWS_compositions getOrDefault [_key, []];
    private _i = _members findIf { !isNull _x && {typeOf _x isEqualTo "Land_BarGate_F"} };
    if (_i < 0) exitWith {};
    (_members select _i) animate ["door_1_rot", _open];
};

// Keyed to the composition, not the object, unlike the BLUFOR HQ gate (fnc_BluHQinit): the boom streams,
// so a netId-bound trigger dangles after the first stow. Server-local, since DUWS_compositions is server-only.
// Requires own-side/civilian, not just "not enemy", so an independent faction isn't waved through. Gated
// on LandVehicle-minus-StaticWeapon: the roadblock's own crewed statics and foot garrison sit inside the
// 20m area and, counted as friendlies, would pin the boom open forever if not carved out.
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

// Streaming spec (spawnRadius, grace, neverStream, airRing, garrison token) comes from the type's tables,
// not the caller, so the dev tool, zone loop and OPCOM all site a given type the same way.
//
// Crewed now only if BLUFOR are already near (or the type is resident); otherwise stowed uncrewed and
// re-crewed by the raise worker on approach, so campaign start never pays the drop-and-settle for
// emplacements nobody is near.
//
// neverStream (mortar/artillery/minefield) pins the pieces and gun crew resident for OPCOM to task with
// no player near, but still streams the loose garrison; a minefield has none to stream.
//
// _zoneKey "" is standalone, on its own ring; set, it mirrors that zone's garrison instead.
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

    // Registry row for OPCOM and the map readout: [key, pos, type, side, zone, revealed, dir]. Presence is
    // liveness -- the clearance check deletes the row on fall. Hardcore gates only the initial intel: what
    // generation lays starts shown outside hardcore, and anything built in play (after mission_init_complete)
    // starts hidden in both modes. Dir is read by the survey to score interlocking fire.
    private _shown = !hardcore_mode_enable && {!mission_init_complete};
    DUWS_hardpoints pushBack [_key, _pos, _type, _side, _zoneKey, _shown, _dir];
    publicVariable "DUWS_hardpoints";
    [_key] call DUWS_fnc_opcom_gridDirty;
    // A newly-registered tower raises the amplifier; recount from the row just pushed.
    if (_type isEqualTo "RADIO") then { call DUWS_fnc_aoi_opforRecount };

    // Left standing through stow: a marker is a map object, not a streamed unit, so a stowed emplacement
    // still marks its ground. Alpha tracks the reveal flag; fnc_hardpoint_reveal flips it to 1 on discovery.
    private _mk = format ["hpm_%1", _key];
    createMarker [_mk, _pos];
    _mk setMarkerShape "ICON";
    _mk setMarkerType "loc_Bunker";
    _mk setMarkerColor (["ColorOPFOR", "ColorBLUFOR"] select (_side isEqualTo "blufor"));
    _mk setMarkerText _type;
    _mk setMarkerSize [1, 1];
    _mk setMarkerAlpha ([0, 1] select _shown);

    [_key, "garrison", DUWS_hardpointHooks] call fnc_site_hooks_set;

    // Armed once per key: the trigger outlives the stow/deploy cycles the composition goes through.
    if (_type isEqualTo "ROADBLOCK") then { [_key, _pos, _side] call fnc_roadblock_gate_arm; };

    // The dev tool spawns onto the player, so its hardpoints read up and crew immediately.
    private _objs = (DUWS_compositions getOrDefault [_key, []]) select { !isNull _x };
    private _crewNow = {
        private _men = [_objs, _pos, _side, _key, _occ get "hpGarrison"] call fnc_hardpoint_garrison;
        ([_key] call fnc_site_roster) append _men;
        _occ set ["awake", true];
        missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key] call fnc_site_alive];
    };

    if (_neverStream) exitWith {
        // Two occupants for parts that stream on opposite terms: the gun crew rides a driven "crew"
        // occupant the poller never touches (a frozen crew can't fire the mission residency exists for),
        // while the loose garrison stays on the streamed "garrison" occupant and stows normally.
        { [_x, _key, true] call fnc_duws_keep } forEach _objs;
        // Token "" crews the guns only, no loose men. Filed under the driven "crew" occupant so the poller
        // skips it and the clearance peak reads a garrison that's always present.
        private _crew = [_objs, _pos, _side, _key, ""] call fnc_hardpoint_garrison;
        if (count _crew > 0) then {
            ([_key, "crew"] call fnc_site_occupant_register) set ["driven", true];
            ([_key, "crew"] call fnc_site_roster) append _crew;
        };
        _occ set ["awake", true];
        missionNamespace setVariable [format ["DUWS_hpPeak_%1", _key], [_key, "crew"] call fnc_site_alive];
        // A standing battery holds no ammunition: OPCOM loads its guns for the mission it gives them and empties
        // them after (fnc_opcom_fires), so a crew never shells anything on its own. Guarded: OPCOM is its own subsystem.
        if (!isNil "DUWS_fnc_opcom_batteryUnload") then { [_key] call DUWS_fnc_opcom_batteryUnload };
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
