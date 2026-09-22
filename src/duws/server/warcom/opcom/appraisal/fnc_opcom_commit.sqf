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
