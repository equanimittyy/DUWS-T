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
    true
};

DUWS_fnc_opcom_sendTaxiableRun = {
    params ["_target"];
    if !([_target] call DUWS_fnc_opcom_sendRun) exitWith { false };
    [[_target select 0] call DUWS_fnc_opcom_byId] call DUWS_fnc_opcom_taxiBind;
    true
};

// One attacker per holding at a time: a second sent after the first dribbles men into a fight no-retreat turns into
// defeat in detail, which Phase 5's muster exists to prevent.
//
// Zones and towns on the same terms. What differs is how the ground answers: a zone flips on presence, a town only
// by having its garrison cleared, so a town with no garrison is no target -- there would be nothing to beat, and
// reputation rather than a fight is what owns it.
DUWS_fnc_opcom_attackSweep = {
    private _units = [false] call DUWS_fnc_opcom_freeCombatants;
    private _busy = DUWS_opcom_taskings apply { _x getOrDefault ["targetZone", ""] };
    private _out = [];
    private _blocked = [];
    private _riders = [];
    // _to scores the send and prices a lift; _at is the order's own target, which a zone reads off the site store
    // because a held position and the one its trigger filed differ in z.
    private _fnc_consider = {
        params ["_key", "_to", "_at", "_label"];
        if (_key in _busy) exitWith {};
        private _worth = [_key] call DUWS_fnc_opcom_siteWorth;
        private _best = [_to, _worth, _units] call DUWS_fnc_opcom_bestSend;
        if (_best isEqualTo []) exitWith { _blocked pushBack [_to, _worth] };
        _best params ["_t", "_v", "_pw", "_c"];
        _out pushBack [[_t get "id", "capture", _at, _pw * _v], 0,
            format ["Attack %1 with %2 %3", _label, _t get "menu", _t get "id"], _v, _pw, _c];
        _riders pushBack [_t, _to, _pw * _v];
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

// Every free unit weighs the same few destinations, drawn from the cells the need field lights: the sample is the
// Patrol's siting pass, and a unit already out is on a move order and out of the roster. Behind the recon rows stands
// every free land combatant, air excepted, which cannot hold the ground it swept. The two kinds scale on different
// axes, a recon on the reach of its certain bubble and a combatant on the threat it walks with (fnc_opcom_patrol).
//
// One patrol per destination, for the reason one attacker goes at a zone: the best unit takes it, and a second row on
// the same ground would only crowd the shortlist with the same sweep twice.
DUWS_fnc_opcom_patrolSweep = {
    private _recon = (call DUWS_fnc_opcom_free) select { "recon" in (_x get "flags") };
    private _units = _recon + ([false] call DUWS_fnc_opcom_freeCombatants);
    if (DUWS_opcom_needCells isEqualTo []) exitWith { [[], [], []] };
    private _pool = +DUWS_opcom_needCells;
    private _dests = [];
    for "_i" from 1 to (OPCOM_SITE_SAMPLES min count _pool) do {
        _dests pushBack ([_pool deleteAt (floor random count _pool)] call DUWS_fnc_opcom_c2w);
    };
    private _out = [];
    private _blocked = [];
    // Hoisted out of the pairwise loop the widened pool runs units x destinations times: none of these vary by it.
    private _costs = _units apply { [_x] call DUWS_fnc_opcom_commitCost };
    private _reaches = _units apply { [_x] call DUWS_fnc_opcom_patrolReach };
    private _scales = _units apply { [_x] call DUWS_fnc_opcom_patrolScale };
    private _cells = _units apply { [_x get "pos"] call DUWS_fnc_opcom_w2c };
    {
        private _to = _x;
        // A garrison's units all stand on its one point, so one line serves many: memoised per origin cell and reach.
        private _lines = createHashMap;
        private _best = [];
        private _bs = -1;
        // Blocked stays the recon shortfall: it is what values a recon hire (fnc_opcom_demand), and ground a
        // combatant swept without certainty is still ground a recon would have read.
        private _reconFree = false;
        {
            private _t = _x;
            private _pw = [_to, _t get "pos", _t get "effForce"] call DUWS_fnc_opcom_pWinSend;
            if (_pw >= OPCOM_PWIN_FLOOR) then {
                if ("recon" in (_t get "flags")) then { _reconFree = true };
                private _k = _reaches select _forEachIndex;
                private _key = format ["%1:%2", _cells select _forEachIndex, _k];
                private _sweep = _lines getOrDefault [_key, -1];
                if (_sweep < 0) then {
                    _sweep = [_t get "pos", _to, _k] call DUWS_fnc_opcom_patrolValue;
                    _lines set [_key, _sweep];
                };
                private _v = _sweep * (_scales select _forEachIndex) * ([_t, _to] call DUWS_fnc_opcom_unitDelay);
                private _c = _costs select _forEachIndex;
                private _s = [_v, _pw, _c] call DUWS_fnc_opcom_score;
                if (_s > _bs) then { _bs = _s; _best = [_t, _v, _pw, _c] };
            };
        } forEach _units;
        if (!_reconFree) then { _blocked pushBack _to };
        if (_best isNotEqualTo []) then {
            _best params ["_t", "_v", "_pw", "_c"];
            _out pushBack [[_t get "id", "move", _to, _pw * _v], 0,
                format ["Patrol %1 with %2 %3", mapGridPosition _to, _t get "menu", _t get "id"], _v, _pw, _c];
        };
    } forEach _dests;
    // No riders: a patrol is sent without a taxi (sendRun), so a lift hired on its order would carry no one.
    [_out, _blocked, []]
};

// Recruit reads every sweep's blocked targets and riders off this table, so a new commit order registers here and
// nothing downstream names it.
DUWS_opcom_commitSweeps = createHashMapFromArray [
    ["attackSweep", DUWS_fnc_opcom_attackSweep],
    ["interceptSweep", DUWS_fnc_opcom_interceptSweep],
    ["patrolSweep", DUWS_fnc_opcom_patrolSweep]
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
