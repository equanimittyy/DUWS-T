// Locality: server, [] call'd at load. The commit actions, which stake a roster unit rather than AP: which unit goes
// and what its target is worth (opcom_plan.md §Appraisal). One unit per order until Phase 5's templates muster several.
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
            private _s = _pw * _v / (_c max 1);
            if (_s > _bs) then { _bs = _s; _best = [_x, _v, _pw, _c] };
        };
    } forEach _units;
    _best
};

// One attacker per zone at a time: a second sent after the first dribbles men into a fight no-retreat turns into
// defeat in detail, which Phase 5's muster exists to prevent.
DUWS_fnc_opcom_attackTargets = {
    private _units = [false] call DUWS_fnc_opcom_freeCombatants;
    if (_units isEqualTo []) exitWith { [] };
    private _busy = DUWS_opcom_taskings apply { _x getOrDefault ["targetZone", ""] };
    private _out = [];
    {
        private _zp = _x;
        private _zk = [_zp] call fnc_zone_key;
        if !(_zk in _busy) then {
            private _best = [_zp, [_zk] call DUWS_fnc_opcom_siteWorth, _units] call DUWS_fnc_opcom_bestSend;
            if (_best isNotEqualTo []) then {
                _best params ["_t", "_v", "_pw", "_c"];
                _out pushBack [[_zk, _t get "id"], 0,
                    format ["Attack %1 with %2 %3", [_zk] call DUWS_fnc_opcom_zoneLabel, _t get "menu", _t get "id"], _v, _pw, _c];
            };
        };
    } forEach WARCOM_zones_controled_by_BLUFOR;
    _out
};

DUWS_fnc_opcom_attackRun = {
    params ["_target"];
    _target params ["_zk", "_id"];
    private _t = [_id] call DUWS_fnc_opcom_byId;
    !isNil "_t" && {[_t, "capture", ([_zk] call fnc_site_at) get "pos"] call fnc_opcom_task}
};

// One interceptor per sighting, for the reason one attacker goes at a zone.
DUWS_fnc_opcom_interceptTargets = {
    private _units = [true] call DUWS_fnc_opcom_freeCombatants;
    if (_units isEqualTo []) exitWith { [] };
    private _busy = (DUWS_opcom_taskings select { (_x get "order") isEqualTo "intercept" }) apply { _x getOrDefault ["interceptKey", ""] };
    private _out = [];
    {
        private _key = _x;
        private _bp = DUWS_opcom_belief_pos select _forEachIndex;
        if ([_key] call DUWS_fnc_opcom_beliefIsSighting && {!(_key in _busy)} && {[_bp] call fnc_aoi_opfor_covers}) then {
            private _v = [_bp, DUWS_opcom_belief_str select _forEachIndex] call DUWS_fnc_opcom_interceptValue;
            private _best = [_bp, _v, _units] call DUWS_fnc_opcom_bestSend;
            if (_best isNotEqualTo []) then {
                _best params ["_t", "_bv", "_pw", "_c"];
                _out pushBack [[_key, _t get "id"], 0,
                    format ["Intercept at %1 with %2 %3", mapGridPosition _bp, _t get "menu", _t get "id"], _bv, _pw, _c];
            };
        };
    } forEach DUWS_opcom_belief_key;
    _out
};

DUWS_fnc_opcom_interceptRun = {
    params ["_target"];
    _target params ["_key", "_id"];
    private _t = [_id] call DUWS_fnc_opcom_byId;
    !isNil "_t" && {[_t, "intercept", _key] call fnc_opcom_task}
};

// Every recon weighs the same few destinations, drawn from the cells the need field lights: the sample is the Scout's
// siting pass, and a recon already out is on a move order and out of the roster.
DUWS_fnc_opcom_scoutTargets = {
    private _units = (call DUWS_fnc_opcom_free) select { "recon" in (_x get "flags") };
    if (_units isEqualTo [] || {DUWS_opcom_needCells isEqualTo []}) exitWith { [] };
    private _pool = +DUWS_opcom_needCells;
    private _dests = [];
    for "_i" from 1 to (OPCOM_SITE_SAMPLES min count _pool) do {
        _dests pushBack ([_pool deleteAt (floor random count _pool)] call DUWS_fnc_opcom_c2w);
    };
    private _out = [];
    {
        private _t = _x;
        private _k = OPCOM_RECON_K getOrDefault [_t get "moveType", 1];
        private _c = [_t] call DUWS_fnc_opcom_commitCost;
        private _best = [];
        private _bs = -1;
        {
            private _pw = [_x, _t get "pos", _t get "effForce"] call DUWS_fnc_opcom_pWinSend;
            if (_pw >= OPCOM_PWIN_FLOOR) then {
                private _v = ([_t get "pos", _x, _k] call DUWS_fnc_opcom_scoutValue) * ([_t, _x] call DUWS_fnc_opcom_unitDelay);
                private _s = _pw * _v / (_c max 1);
                if (_s > _bs) then { _bs = _s; _best = [_x, _v, _pw] };
            };
        } forEach _dests;
        if (_best isNotEqualTo []) then {
            _best params ["_to", "_v", "_pw"];
            _out pushBack [[_t get "id", _to], 0,
                format ["Scout %1 with %2 %3", mapGridPosition _to, _t get "menu", _t get "id"], _v, _pw, _c];
        };
    } forEach _units;
    _out
};

DUWS_fnc_opcom_scoutRun = {
    params ["_target"];
    _target params ["_id", "_to"];
    private _t = [_id] call DUWS_fnc_opcom_byId;
    !isNil "_t" && {[_t, "move", _to] call fnc_opcom_task}
};
