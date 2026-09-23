// Locality: server, [] call'd at load. The commit actions, which stake a roster unit rather than AP: which unit goes
// and what its target is worth (opcom_plan.md §Appraisal). One unit per order until Phase 5's templates muster several.
// Each sweep returns [candidates, blocked, riders] through the tick cache, so Recruit reads the blocked targets and
// the units a lift would carry whatever order the rows run in (fnc_opcom_hire).
if (!isServer) exitWith {};

// The free unit that scores best sent at _to, any below OPCOM_PWIN_FLOOR dropped. -> [tasking, Value, P(win), Cost], or
// [] when none clears the floor.
DUWS_fnc_opcom_bestSend = {
    params ["_to", "_value", "_units"];
    private _best = [];
    private _bs = -1;
    {
        private _pw = [_to, _x get "pos", _x get "effForce"] call DUWS_fnc_opcom_pWinSend;
        if (_pw >= OPCOM_PWIN_FLOOR) then {
            private _v = _value * ([_x, _to] call DUWS_fnc_opcom_unitDelay);
            private _c = [_x] call DUWS_fnc_opcom_commitCost;
            private _s = [_v, _pw, _c] call DUWS_fnc_opcom_score;
            if (_s > _bs) then { _bs = _s; _best = [_x, _v, _pw, _c] };
        };
    } forEach _units;
    _best
};

// The target carries the unit, its order and the order's own target: the pick hands an execute nothing else.
DUWS_fnc_opcom_sendRun = {
    params ["_target"];
    _target params ["_id", "_order", "_to", "_exp"];
    private _t = [_id] call DUWS_fnc_opcom_byId;
    if (isNil "_t") exitWith { false };
    if !([_t, _order, _to] call fnc_opcom_task) exitWith { false };
    // What the order is worth once committed: a lift is priced against it, stranded at a water leg or taxied over
    // dry ground (fnc_opcom_taxi, fnc_opcom_hire).
    _t set ["expValue", _exp];
    [_t] call DUWS_fnc_opcom_taxiBind;
    true
};

// One attacker per zone at a time: a second sent after the first dribbles men into a fight no-retreat turns into
// defeat in detail, which Phase 5's muster exists to prevent.
DUWS_fnc_opcom_attackSweep = {
    private _units = [false] call DUWS_fnc_opcom_freeCombatants;
    private _busy = DUWS_opcom_taskings apply { _x getOrDefault ["targetZone", ""] };
    private _out = [];
    private _blocked = [];
    private _riders = [];
    {
        private _zp = _x;
        private _zk = [_zp] call fnc_zone_key;
        if !(_zk in _busy) then {
            private _worth = [_zk] call DUWS_fnc_opcom_siteWorth;
            private _best = [_zp, _worth, _units] call DUWS_fnc_opcom_bestSend;
            if (_best isEqualTo []) then {
                _blocked pushBack [_zp, _worth];
            } else {
                _best params ["_t", "_v", "_pw", "_c"];
                _out pushBack [[_t get "id", "capture", ([_zk] call fnc_site_at) get "pos", _pw * _v], 0,
                    format ["Attack %1 with %2 %3", [_zk] call DUWS_fnc_opcom_zoneLabel, _t get "menu", _t get "id"], _v, _pw, _c];
                _riders pushBack [_t, _zp, _pw * _v];
            };
        };
    } forEach WARCOM_zones_controled_by_BLUFOR;
    [_out, _blocked, _riders]
};

// One interceptor per sighting, for the reason one attacker goes at a zone.
DUWS_fnc_opcom_interceptSweep = {
    private _units = [true] call DUWS_fnc_opcom_freeCombatants;
    private _busy = (DUWS_opcom_taskings select { (_x get "order") isEqualTo "intercept" }) apply { _x getOrDefault ["interceptKey", ""] };
    private _out = [];
    private _blocked = [];
    private _riders = [];
    {
        private _key = _x;
        private _bp = DUWS_opcom_belief_pos select _forEachIndex;
        if ([_key] call DUWS_fnc_opcom_beliefIsSighting && {!(_key in _busy)} && {[_bp] call fnc_aoi_opfor_covers}) then {
            private _v = [_bp, DUWS_opcom_belief_str select _forEachIndex] call DUWS_fnc_opcom_interceptValue;
            private _best = [_bp, _v, _units] call DUWS_fnc_opcom_bestSend;
            if (_best isEqualTo []) then {
                _blocked pushBack [_bp, _v];
            } else {
                _best params ["_t", "_bv", "_pw", "_c"];
                _out pushBack [[_t get "id", "intercept", _key, _pw * _bv], 0,
                    format ["Intercept at %1 with %2 %3", mapGridPosition _bp, _t get "menu", _t get "id"], _bv, _pw, _c];
                _riders pushBack [_t, _bp, _pw * _bv];
            };
        };
    } forEach DUWS_opcom_belief_key;
    [_out, _blocked, _riders]
};

// Every recon weighs the same few destinations, drawn from the cells the need field lights: the sample is the Scout's
// siting pass, and a recon already out is on a move order and out of the roster.
DUWS_fnc_opcom_scoutSweep = {
    private _units = (call DUWS_fnc_opcom_free) select { "recon" in (_x get "flags") };
    if (DUWS_opcom_needCells isEqualTo []) exitWith { [[], [], []] };
    private _pool = +DUWS_opcom_needCells;
    private _dests = [];
    for "_i" from 1 to (OPCOM_SITE_SAMPLES min count _pool) do {
        _dests pushBack ([_pool deleteAt (floor random count _pool)] call DUWS_fnc_opcom_c2w);
    };
    private _out = [];
    private _riders = [];
    private _taken = _dests apply { false };
    {
        private _t = _x;
        private _k = OPCOM_RECON_K getOrDefault [_t get "moveType", 1];
        private _c = [_t] call DUWS_fnc_opcom_commitCost;
        private _best = [];
        private _bs = -1;
        {
            private _pw = [_x, _t get "pos", _t get "effForce"] call DUWS_fnc_opcom_pWinSend;
            if (_pw >= OPCOM_PWIN_FLOOR) then {
                _taken set [_forEachIndex, true];
                private _v = ([_t get "pos", _x, _k] call DUWS_fnc_opcom_scoutValue) * ([_t, _x] call DUWS_fnc_opcom_unitDelay);
                private _s = [_v, _pw, _c] call DUWS_fnc_opcom_score;
                if (_s > _bs) then { _bs = _s; _best = [_x, _v, _pw] };
            };
        } forEach _dests;
        if (_best isNotEqualTo []) then {
            _best params ["_to", "_v", "_pw"];
            _out pushBack [[_t get "id", "move", _to, _pw * _v], 0,
                format ["Scout %1 with %2 %3", mapGridPosition _to, _t get "menu", _t get "id"], _v, _pw, _c];
            _riders pushBack [_t, _to, _pw * _v];
        };
    } forEach _units;
    private _blocked = [];
    { if !(_taken select _forEachIndex) then { _blocked pushBack _x } } forEach _dests;
    [_out, _blocked, _riders]
};

// Recruit reads every sweep's blocked targets and riders off this table, so a new commit order registers here and
// nothing downstream names it.
DUWS_opcom_commitSweeps = createHashMapFromArray [
    ["attackSweep", DUWS_fnc_opcom_attackSweep],
    ["interceptSweep", DUWS_fnc_opcom_interceptSweep],
    ["scoutSweep", DUWS_fnc_opcom_scoutSweep]
];

DUWS_fnc_opcom_commitSweep = {
    params ["_key"];
    [_key, DUWS_opcom_commitSweeps get _key] call DUWS_fnc_opcom_tickCached
};

DUWS_fnc_opcom_commitTargets = { params ["_key"]; ([_key] call DUWS_fnc_opcom_commitSweep) select 0 };
DUWS_fnc_opcom_commitBlocked = { params ["_key"]; ([_key] call DUWS_fnc_opcom_commitSweep) select 1 };

// -> [[tasking, destination, Value], ...]: each order the pick may commit this tick.
DUWS_fnc_opcom_pendingRiders = {
    private _out = [];
    { _out append (([_x] call DUWS_fnc_opcom_commitSweep) select 2) } forEach DUWS_opcom_commitSweeps;
    _out
};
