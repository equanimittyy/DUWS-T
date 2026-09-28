// Locality: server, [] call'd at load. The commit actions, which stake a unit rather than AP (opcom_plan.md §Sourcing).
// A target is [source ref, task, expValue, lift]: task the fnc_opcom_task arguments after the tasking, [] for a hire that
// needs no order, and lift [] or [lift ref, the rider's destination].
if (!isServer) exitWith {};

// -> the unit _target names, raised and given its order; nil when either is refused. A refused hire is dismissed, so
// no unpaid unit is left standing.
DUWS_fnc_opcom_send = {
    params ["_target"];
    _target params ["_ref", "_task", "_exp", "_lift"];
    private _t = [_ref] call DUWS_fnc_opcom_raise;
    if (isNil "_t") exitWith { nil };
    // No order for a Garrison hire, raised into the zone's garrison, or an attacker with no dry ground to stage on.
    private _ok = switch (true) do {
        case (_task isEqualTo []): { true };
        case (_lift isEqualTo []): { ([_t] + _task) call fnc_opcom_task };
        default { [_t, _task, _lift] call DUWS_fnc_opcom_liftRun };
    };
    if (!_ok) exitWith { [_ref, _t] call DUWS_fnc_opcom_dismiss; nil };
    // What the order is worth once committed, which a Ferry is priced on if the unit stops at a water leg.
    _t set ["expValue", _exp];
    _t
};

DUWS_fnc_opcom_sendRun = {
    params ["_target"];
    private _t = [_target] call DUWS_fnc_opcom_send;
    !isNil "_t"
};

// One assault or flank at a time, and none for OPCOM_ATTACK_COOLDOWN after one ends, so the players get a lull between
// offensives. It commits as an assault or a flank, each its own action row, its units stage and launch together
// (fnc_opcom_attack), and the bucket DUWS_fnc_opcom_joinBucket names is a target of its own, filled by a later pick.
//
// Zones and towns on the same terms, and the HQ once found. What differs is how the ground answers: a zone flips on
// presence, a town only by having its garrison cleared, so a town with no garrison is no target -- there would be
// nothing to beat, and reputation rather than a fight is what owns it.
//
// A source across water from its target reaches it only by ferry, which carries men alone, and lands them a trip at a
// time, which no flank's timing survives: such a source is offered only if it is transportable, and only to assault.
DUWS_fnc_opcom_acrossWater = {
    params ["_src", "_mass"];
    ([_src select 1] call DUWS_fnc_opcom_massAt) != _mass
};

// A target is [members, attack]: members as DUWS_fnc_opcom_attackPackage, each unit's target [source ref, task,
// expValue, lift]; attack ["open", key, target, label, roles, kind] commits a new Attack, and ["join", attack id] adds
// to one still staging. -> kind -> targets, one sweep for both rows.
DUWS_fnc_opcom_attackSweep = {
    private _fits = { params ["_f", "_m"]; [_f, _m, false] call DUWS_fnc_opcom_isCombatant };
    private _free = ([false] call DUWS_fnc_opcom_freeCombatants) apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    // A muster commits below the odds it launches at, so only a hopeless one holds.
    private _floor = [OPCOM_MUSTER_HOLD, 0] call DUWS_fnc_opcom_pWinAt;
    private _busy = DUWS_opcom_taskings apply { _x getOrDefault ["targetZone", ""] };
    private _out = createHashMapFromArray [["assault", []], ["flank", []]];
    private _fnc_sources = {
        params ["_at", "_near", "_flank"];
        private _mass = [_at] call DUWS_fnc_opcom_massAt;
        (_free + ([_fits, _near, _zones] call DUWS_fnc_opcom_hireSources)) select {
            !([_x, _mass] call DUWS_fnc_opcom_acrossWater) || {!_flank && {"transportable" in (_x select 4)}}
        }
    };
    // _to scores the send; _at is the order's own target, which a zone reads off the site store because a held
    // position and the one its trigger filed differ in z.
    private _fnc_consider = {
        params ["_key", "_to", "_at", "_label"];
        if (_key in _busy) exitWith {};
        private _worth = [_key] call DUWS_fnc_opcom_siteWorth;
        private _lead = [([_at, _to, false] call _fnc_sources) apply { [_x, _worth] }, _to, true, 0, 0, 0] call DUWS_fnc_opcom_bestSources;
        if (_lead isEqualTo []) exitWith {};
        private _bearing = _at getDir (((_lead select 0) select 0) select 1);
        {
            private _kind = _x;
            private _roles = [_kind, _at, _bearing] call DUWS_fnc_opcom_stageRoles;
            if (_roles isNotEqualTo []) then {
                private _title = format ["%1 %2", ["Assault", "Flank"] select (_kind isEqualTo "flank"), _label];
                ([[_at, _to, _kind isEqualTo "flank"] call _fnc_sources, _to, _at, _worth, _floor,
                    _roles apply { [_x select 1, _x select 2, 0, 0, _x select 4] }, 0, _title] call DUWS_fnc_opcom_attackPackage)
                    params [["_members", []], "_price", "_v", "_pw", "_c", "_names"];
                // From this ratio up a flank buys a setup leg and nothing else.
                if (_members isNotEqualTo [] && {_kind isEqualTo "assault" || {sqrt (_pw / ((1 - _pw) max 0.001)) < OPCOM_BAND_CRUSH}}) then {
                    (_out get _kind) pushBack [[_members, ["open", _key, _at, _label, _roles, _kind]], _price,
                        format ["%1 with %2", _title, _names], _v, _pw, _c];
                };
            };
        } forEach ["assault", "flank"];
    };
    if (DUWS_opcom_attackReadyTick <= DUWS_opcom_tick && {(DUWS_opcom_attacks findIf { (_x get "kind") isNotEqualTo "qrf" }) < 0}) then {
        {
            private _zk = [_x] call fnc_zone_key;
            [_zk, _x, ([_zk] call fnc_site_at) get "pos", [_zk] call DUWS_fnc_opcom_zoneLabel] call _fnc_consider;
        } forEach WARCOM_zones_controled_by_BLUFOR;
        {
            private _i = _forEachIndex;
            if (_x > 0 && {([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU"}) then {
                private _tp = [_i] call DUWS_fnc_opcom_townPos;
                if (_tp isNotEqualTo []) then {
                    [[_i] call fnc_town_site_key, _tp, _tp, [_i] call DUWS_fnc_opcom_townLabel] call _fnc_consider;
                };
            };
        } forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);
        if (DUWS_opcom_hqKnown && {["HQ"] call DUWS_fnc_opcom_captureHolds}) then {
            private _hp = (["HQ"] call fnc_site_at) getOrDefault ["pos", []];
            if (_hp isNotEqualTo []) then { ["HQ", _hp, _hp, "HQ"] call _fnc_consider };
        };
    };
    {
        private _attack = _x;
        private _kind = _attack get "kind";
        // A QRF draws on air as well, so DUWS_fnc_opcom_qrfSweep fills its own.
        if (_kind isNotEqualTo "qrf" && {([_attack] call DUWS_fnc_opcom_joinBucket) >= 0}) then {
            private _at = _attack get "pos";
            private _title = format ["Join the %1 on %2", _kind, _attack get "label"];
            ([[_at, _at, _kind isEqualTo "flank"] call _fnc_sources, _at, _at, [_attack get "target"] call DUWS_fnc_opcom_siteWorth,
                _floor, [_attack] call DUWS_fnc_opcom_attackBuckets, [_attack] call DUWS_fnc_opcom_boundForce, _title]
                call DUWS_fnc_opcom_attackPackage) params [["_members", []], "_price", "_v", "_pw", "_c", "_names"];
            if (_members isNotEqualTo []) then {
                (_out get _kind) pushBack [[_members, ["join", _attack get "id"]], _price, format ["%1 with %2", _title, _names],
                    _v, _pw, _c];
            };
        };
    } forEach DUWS_opcom_attacks;
    _out
};

DUWS_fnc_opcom_attackTargets = {
    params ["_kind"];
    (["attack", DUWS_fnc_opcom_attackSweep] call DUWS_fnc_opcom_tickCached) get _kind
};

// A member that cannot be raised or routed is refunded before the pick charges the package, so it pays only for the
// units that went; an open commits its record on the first that does.
DUWS_fnc_opcom_attackRun = {
    params ["_target"];
    _target params ["_members", "_atk"];
    _atk params ["_how", "_a", "_b", "_label", "_roles", "_kind"];
    private _attack = [];
    if (_how isEqualTo "join") then {
        private _i = DUWS_opcom_attacks findIf { (_x get "id") isEqualTo _a };
        // A pick earlier this tick may have met the ideal bar or the unit cap.
        if (_i >= 0 && {([DUWS_opcom_attacks select _i] call DUWS_fnc_opcom_joinBucket) >= 0}) then { _attack = DUWS_opcom_attacks select _i };
    };
    if (_how isEqualTo "join" && {_attack isEqualTo []}) exitWith { false };
    private _landed = 0;
    private _refund = 0;
    {
        _x params ["_unit", "_bucket", "_price"];
        private _t = [_unit] call DUWS_fnc_opcom_send;
        if (isNil "_t") then { _refund = _refund + _price } else {
            if (_attack isEqualTo []) then { _attack = [_kind, _a, _b, _label, _roles] call DUWS_fnc_opcom_attackOpen };
            [_attack, (_attack get "roles") select _bucket, _t] call DUWS_fnc_opcom_attackBind;
            _landed = _landed + 1;
        };
    } forEach _members;
    if (_landed == 0) exitWith { false };
    if (_refund > 0) then { ["OPF", _refund, "opcom_attack_refund"] call fnc_ap_adjust };
    true
};

// A QRF goes at a cluster, every sighting within a cell of the strongest: that block is the force its P(win) and muster
// read, so one QRF masses on it where lone interceptors would arrive one at a time. Air joins, as it cannot join an
// assault, since it hunts a group in the open rather than ground it must stand on. A ground unit across water stays
// out: a ferry lands men a trip at a time, and the target moves. -> targets as DUWS_fnc_opcom_attackSweep's.
DUWS_fnc_opcom_qrfSweep = {
    private _free = ([true] call DUWS_fnc_opcom_freeCombatants) apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    private _floor = [OPCOM_MUSTER_HOLD, 0] call DUWS_fnc_opcom_pWinAt;
    private _sightings = [];
    {
        private _bp = DUWS_opcom_belief_pos select _forEachIndex;
        if ([_x] call DUWS_fnc_opcom_beliefIsSighting && {[_bp] call fnc_aoi_opfor_covers}) then {
            _sightings pushBack [DUWS_opcom_belief_str select _forEachIndex, _forEachIndex];
        };
    } forEach DUWS_opcom_belief_key;
    _sightings sort false;
    private _fnc_value = {
        params ["_at"];
        private _str = 0;
        {
            if (([DUWS_opcom_belief_pos select (_x select 1), _at] call DUWS_fnc_opcom_cellDist) <= 1) then { _str = _str + (_x select 0) };
        } forEach _sightings;
        [_at, _str] call DUWS_fnc_opcom_interceptValue
    };
    private _out = [];
    private _fnc_offer = {
        params ["_at", "_buckets", "_base", "_label", "_atk"];
        private _mass = [_at] call DUWS_fnc_opcom_massAt;
        private _offers = (_free + ([DUWS_fnc_opcom_isCombatant, _at, _zones] call DUWS_fnc_opcom_hireSources)) select {
            ((DUWS_opcom_moveWater get (_x select 3)) isNotEqualTo "land") || {!([_x, _mass] call DUWS_fnc_opcom_acrossWater)}
        };
        ([_offers, _at, _at, [_at] call _fnc_value, _floor, _buckets, _base, _label] call DUWS_fnc_opcom_attackPackage)
            params [["_members", []], "_price", "_v", "_pw", "_c", "_names"];
        if (_members isNotEqualTo []) then {
            _out pushBack [[_members, _atk], _price, format ["%1 with %2", _label, _names], _v, _pw, _c];
        };
    };
    private _qrfs = DUWS_opcom_attacks select { (_x get "kind") isEqualTo "qrf" };
    private _taken = _qrfs apply { _x get "pos" };
    {
        private _key = DUWS_opcom_belief_key select (_x select 1);
        private _at = DUWS_opcom_belief_pos select (_x select 1);
        if ((_taken findIf { ([_x, _at] call DUWS_fnc_opcom_cellDist) <= 1 }) < 0) then {
            _taken pushBack _at;
            private _label = format ["QRF at %1", mapGridPosition _at];
            [_at, [[[], true, 0, 0, 0]], 0, _label, ["open", _key, _at, _label, [["attacker", [], true, "", 0, []]], "qrf"]] call _fnc_offer;
        };
    } forEach _sightings;
    {
        if (([_x] call DUWS_fnc_opcom_joinBucket) >= 0) then {
            [_x get "pos", [_x] call DUWS_fnc_opcom_attackBuckets, [_x] call DUWS_fnc_opcom_boundForce, format ["Join the %1", _x get "label"],
                ["join", _x get "id"]] call _fnc_offer;
        };
    } forEach _qrfs;
    _out
};

// One patrol per destination, for the reason one attacker goes at a zone: a second row on the same ground would only
// crowd the shortlist with the same sweep twice.
DUWS_fnc_opcom_patrolSweep = {
    if (DUWS_opcom_needCells isEqualTo []) exitWith { [] };
    private _free = ((call DUWS_fnc_opcom_free) select { [_x get "flags", _x get "moveType"] call DUWS_fnc_opcom_isPatroller })
        apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    private _pool = +DUWS_opcom_needCells;
    private _dests = [];
    for "_i" from 1 to (OPCOM_PATROL_SAMPLES min count _pool) do {
        _dests pushBack ([_pool deleteAt (floor random count _pool)] call DUWS_fnc_opcom_c2w);
    };
    private _out = [];
    {
        private _to = _x;
        // Sources that start on one point share its line: a garrison's units, or every hire raised at one zone.
        private _lines = createHashMap;
        private _offers = (_free + ([DUWS_fnc_opcom_isPatroller, _to, _zones] call DUWS_fnc_opcom_hireSources)) apply {
            _x params ["", "_from", "_force", "_mt", "_flags"];
            private _k = [_flags, _mt] call DUWS_fnc_opcom_patrolReach;
            private _key = format ["%1:%2", [_from] call DUWS_fnc_opcom_w2c, _k];
            private _sweep = _lines getOrDefault [_key, -1];
            if (_sweep < 0) then {
                _sweep = [_from, _to, _k] call DUWS_fnc_opcom_patrolValue;
                _lines set [_key, _sweep];
            };
            [_x, _sweep * ([_flags, _force] call DUWS_fnc_opcom_patrolScale)]
        };
        {
            _x params ["_src", "_v", "_pw", "_c", "_p"];
            private _ref = _src select 0;
            _out pushBack [[_ref, ["patrol", _to], _pw * _v, []], _p,
                format ["Patrol %1 with %2", mapGridPosition _to, [_ref] call DUWS_fnc_opcom_sourceName], _v, _pw, _c];
        } forEach ([_offers, _to, true] call DUWS_fnc_opcom_bestSources);
    } forEach _dests;
    _out
};

// A probe buys belief, not ground: its Value is the error it removes from the reading the stake is about to be laid
// on, so an objective no Attack can source, or one already launched on, is worth none, and a QRF's none: its target is
// a sighting, belief already fresh. One probe per objective, for the reason one patrol goes per destination. P(win) 1:
// it fights for nothing.
DUWS_fnc_opcom_probeSweep = {
    private _stakes = createHashMap;
    {
        {
            private _atk = (_x select 0) param [1, []];
            if ((_atk param [0, ""]) isEqualTo "open") then {
                _atk params ["", "_key", "_at", "_label"];
                private _c = (_stakes getOrDefault [_key, [1e9]]) select 0;
                _stakes set [_key, [_c min (_x select 5), _at, _label]];
            };
        } forEach _y;
    } forEach (["attack", DUWS_fnc_opcom_attackSweep] call DUWS_fnc_opcom_tickCached);
    {
        if ((_x get "state") isEqualTo "buildup" && {(_x get "kind") isNotEqualTo "qrf"}) then {
            _stakes set [_x get "target", [([_x] call DUWS_fnc_opcom_boundForce) * OPCOM_AP_PER_FORCE, _x get "pos", _x get "label"]];
        };
    } forEach DUWS_opcom_attacks;
    private _probed = (DUWS_opcom_taskings select { (_x get "order") isEqualTo "probe" }) apply { _x get "target" };
    private _free = ((call DUWS_fnc_opcom_free) select { [_x get "flags", _x get "moveType"] call DUWS_fnc_opcom_isPatroller })
        apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    private _out = [];
    {
        _y params ["_stake", "_at", "_label"];
        private _stale = [_at] call DUWS_fnc_opcom_blockStaleness;
        if (_stale > OPCOM_PROBE_FRESH && {(_probed findIf { _x isEqualTo _at }) < 0}) then {
            private _v = _stale * _stake * OPCOM_PROBE_SHARE;
            private _offers = (_free + ([DUWS_fnc_opcom_isPatroller, _at, _zones] call DUWS_fnc_opcom_hireSources)) apply { [_x, _v] };
            {
                _x params ["_src", "_sv", "_pw", "_c", "_p"];
                private _ref = _src select 0;
                _out pushBack [[_ref, ["probe", _at], _pw * _sv, []], _p,
                    format ["Probe %1 with %2", _label, [_ref] call DUWS_fnc_opcom_sourceName], _sv, _pw, _c];
            } forEach ([_offers, _at, false] call DUWS_fnc_opcom_bestSources);
        };
    } forEach _stakes;
    _out
};

// The combatants homed at each zone, the set its reserve pool fields (DUWS_fnc_opcom_zoneReserveSync).
DUWS_fnc_opcom_homedSweep = {
    private _out = createHashMap;
    {
        if ((_x get "order") isEqualTo "garrison" && {(_x get "status") isNotEqualTo "dead"}
            && {!("noncombat" in (_x get "flags"))}) then {
            private _hz = _x get "homeZone";
            _out set [_hz, (_out getOrDefault [_hz, 0]) + 1];
        };
    } forEach DUWS_opcom_taskings;
    _out
};

// A unit resting in garrison heals where it is, so healing is no reason to move it. P(win) 1: a unit sent to rest
// fights for nothing.
DUWS_fnc_opcom_garrisonSweep = {
    private _homed = ["homed", DUWS_fnc_opcom_homedSweep] call DUWS_fnc_opcom_tickCached;
    private _units = [true] call DUWS_fnc_opcom_freeCombatants;
    private _free = _units apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _out = [];
    {
        _x params ["_zk", "", "_zp", "_worth", "_exp"];
        if ((_homed getOrDefault [_zk, 0]) < OPCOM_CAP_GARRISON) then {
            private _zone = _x;
            private _zf = [_zk] call DUWS_fnc_opcom_zoneForce;
            private _offers = [];
            {
                private _resting = (_x get "order") isEqualTo "garrison";
                if !(_resting && {(_x get "homeZone") isEqualTo _zk}) then {
                    private _eff = _x get "effForce";
                    _offers pushBack [_free select _forEachIndex,
                        [[_x get "fullForce", _eff] select _resting, _eff, _worth, _exp, _zf] call DUWS_fnc_opcom_garrisonValue];
                };
            } forEach _units;
            {
                _offers pushBack [_x, [_worth, _exp, _x select 2, _zf] call DUWS_fnc_opcom_garrisonDefense];
            } forEach ([DUWS_fnc_opcom_isCombatant, _zp, [_zone]] call DUWS_fnc_opcom_hireSources);
            {
                private _hired = (((_x select 0) select 0) select 0) isEqualTo "hire";
                private _task = [["return", _zp, _zk], []] select _hired;
                _out pushBack ([_x, _zp, _task, format ["Garrison %1", [_zk] call DUWS_fnc_opcom_zoneLabel]]
                    call DUWS_fnc_opcom_liftOffer);
            } forEach ([_offers, _zp, false] call DUWS_fnc_opcom_bestSources);
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};
