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
    params ["_target", "", "_action"];
    private _t = [_target] call DUWS_fnc_opcom_send;
    if (isNil "_t") exitWith { false };
    private _task = _target select 1;
    if (_task isNotEqualTo []) then { [_action, _task select 1, _t] call DUWS_fnc_opcom_intentOpen };
    true
};

// One Attack per holding at a time: a second sent after the first dribbles men into a fight no-retreat turns into
// defeat in detail. It commits as a manoeuvre the odds pick (fnc_opcom_manoeuvres), its units stage and launch
// together (fnc_opcom_buildup), and each slot still open is a target of its own, filled by a later pick.
//
// Zones and towns on the same terms. What differs is how the ground answers: a zone flips on presence, a town only
// by having its garrison cleared, so a town with no garrison is no target -- there would be nothing to beat, and
// reputation rather than a fight is what owns it.
//
// A target is [source ref, task, expValue, lift, attack]: attack ["open", key, target, label, roles, manoeuvre] commits a
// new Attack, and ["join", intent id, slot] fills a slot of one still staging.
DUWS_fnc_opcom_attackSweep = {
    private _fits = { params ["_f", "_m"]; [_f, _m, false] call DUWS_fnc_opcom_isCombatant };
    private _free = ([false] call DUWS_fnc_opcom_freeCombatants) apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    // A muster commits below the odds it launches at, so only a hopeless one holds.
    private _floor = [OPCOM_MUSTER_HOLD, 0] call DUWS_fnc_opcom_pWinAt;
    private _attacks = DUWS_opcom_intents select { (_x get "action") isEqualTo "attack" };
    private _busy = (DUWS_opcom_taskings apply { _x getOrDefault ["targetZone", ""] }) + (_attacks apply { _x get "target" });
    private _out = [];
    // _to scores the send; _at is the order's own target, which a zone reads off the site store because a held
    // position and the one its trigger filed differ in z.
    private _fnc_consider = {
        params ["_key", "_to", "_at", "_label"];
        if (_key in _busy) exitWith {};
        private _worth = [_key] call DUWS_fnc_opcom_siteWorth;
        private _edge = ([_key] call fnc_site_at) getOrDefault ["radius", 0];
        private _offers = (_free + ([_fits, _to, _zones] call DUWS_fnc_opcom_hireSources)) apply { [_x, _worth] };
        {
            private _pw = _x select 2;
            ([sqrt (_pw / ((1 - _pw) max 0.001)), _at, _at getDir ((_x select 0) select 1), _edge] call DUWS_fnc_opcom_manoeuvrePick)
                params ["_m", "_roles"];
            (_roles select 0) params ["", "_rally", "", "", "_lambda"];
            private _stage = [["move", _rally, "", [], _lambda], []] select (_rally isEqualTo []);
            private _c = [_x, [_rally, _to] select (_rally isEqualTo []), _stage, format ["Attack %1 (%2)", _label, _m]]
                call DUWS_fnc_opcom_liftOffer;
            (_c select 0) pushBack ["open", _key, _at, _label, _roles, _m];
            _out pushBack _c;
        } forEach ([_offers, _to, true, 0, 0, _floor] call DUWS_fnc_opcom_bestSources);
    };
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
    {
        private _intent = _x;
        private _roles = _intent get "roles";
        private _slot = _roles findIf { (_x get "unit") < 0 };
        if ((_intent get "state") isEqualTo "buildup" && {_slot >= 0}) then {
            private _role = _roles select _slot;
            private _r = [_intent] call DUWS_fnc_opcom_musterRatio;
            if ((_role get "required") || {_r < OPCOM_MUSTER_IDEAL}) then {
                private _at = _intent get "pos";
                private _base = [_intent] call DUWS_fnc_opcom_boundForce;
                private _rally = _role get "rally";
                private _stage = [["move", _rally, "", [], _role get "lambda"], []] select (_rally isEqualTo []);
                private _worth = [_intent get "target"] call DUWS_fnc_opcom_siteWorth;
                private _offers = (_free + ([_fits, _at, _zones] call DUWS_fnc_opcom_hireSources)) apply { [_x, _worth] };
                {
                    private _c = [_x, [_rally, _at] select (_rally isEqualTo []), _stage,
                        format ["Join the attack on %1 as %2", _intent get "label", _role get "role"]] call DUWS_fnc_opcom_liftOffer;
                    (_c select 0) pushBack ["join", _intent get "id", _slot];
                    _out pushBack _c;
                } forEach ([_offers, _at, true, 0, 0, _floor, _base] call DUWS_fnc_opcom_bestSources);
            };
        };
    } forEach _attacks;
    _out
};

DUWS_fnc_opcom_attackTargets = { ["attack", DUWS_fnc_opcom_attackSweep] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_attackRun = {
    params ["_target"];
    (_target select 4) params ["_kind", "_a", "_b", "_label", "_roles", "_m"];
    if (_kind isEqualTo "join") exitWith {
        private _i = DUWS_opcom_intents findIf { (_x get "id") isEqualTo _a };
        if (_i < 0) exitWith { false };
        private _intent = DUWS_opcom_intents select _i;
        // Checked before the slot is read: a launch drops the slots it leaves open.
        if ((_intent get "state") isNotEqualTo "buildup") exitWith { false };
        private _role = (_intent get "roles") select _b;
        if ((_role get "unit") >= 0) exitWith { false };
        private _t = [_target] call DUWS_fnc_opcom_send;
        if (isNil "_t") exitWith { false };
        [_intent, _role, _t] call DUWS_fnc_opcom_intentBind;
        true
    };
    private _t = [_target] call DUWS_fnc_opcom_send;
    if (isNil "_t") exitWith { false };
    (["attack", _a, _t, _roles, "buildup", _b, _label] call DUWS_fnc_opcom_intentOpen) set ["manoeuvre", _m];
    true
};

// One interceptor per sighting, for the reason one attacker goes at a zone.
DUWS_fnc_opcom_interceptSweep = {
    private _free = ([true] call DUWS_fnc_opcom_freeCombatants) apply { [_x] call DUWS_fnc_opcom_freeSource };
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    private _busy = (DUWS_opcom_taskings select { (_x get "order") isEqualTo "intercept" }) apply { _x getOrDefault ["interceptKey", ""] };
    private _out = [];
    {
        private _key = _x;
        private _bp = DUWS_opcom_belief_pos select _forEachIndex;
        if ([_key] call DUWS_fnc_opcom_beliefIsSighting && {!(_key in _busy)} && {[_bp] call fnc_aoi_opfor_covers}) then {
            private _v = [_bp, DUWS_opcom_belief_str select _forEachIndex] call DUWS_fnc_opcom_interceptValue;
            private _offers = (_free + ([DUWS_fnc_opcom_isCombatant, _bp, _zones] call DUWS_fnc_opcom_hireSources))
                apply { [_x, _v] };
            {
                _out pushBack ([_x, _bp, ["intercept", _key], format ["Intercept at %1", mapGridPosition _bp]]
                    call DUWS_fnc_opcom_liftOffer);
            } forEach ([_offers, _bp, true] call DUWS_fnc_opcom_bestSources);
        };
    } forEach DUWS_opcom_belief_key;
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
    for "_i" from 1 to (OPCOM_SITE_SAMPLES min count _pool) do {
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
// on, so an objective no Attack can source, or one already launched on, is worth none. One probe per objective, for
// the reason one patrol goes per destination. P(win) 1: it fights for nothing.
DUWS_fnc_opcom_probeSweep = {
    private _stakes = createHashMap;
    {
        private _atk = (_x select 0) param [4, []];
        if ((_atk param [0, ""]) isEqualTo "open") then {
            _atk params ["", "_key", "_at", "_label"];
            private _c = (_stakes getOrDefault [_key, [1e9]]) select 0;
            _stakes set [_key, [_c min (_x select 5), _at, _label]];
        };
    } forEach (call DUWS_fnc_opcom_attackTargets);
    private _probed = [];
    {
        if ((_x get "action") isEqualTo "probe") then { _probed pushBack (_x get "target") };
        if ((_x get "action") isEqualTo "attack" && {(_x get "state") isEqualTo "buildup"}) then {
            _stakes set [_x get "target", [([_x] call DUWS_fnc_opcom_boundForce) * OPCOM_AP_PER_FORCE, _x get "pos", _x get "label"]];
        };
    } forEach DUWS_opcom_intents;
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
