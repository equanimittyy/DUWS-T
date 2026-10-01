// Locality: server, [] call'd at load. An Attack's record and its per-tick runner (opcom_plan.md §Attack): the units it
// binds in role buckets, where each bucket stages, the muster that launches them together and what each waits on. No-retreat turns
// a force dribbled into contact into defeat in detail, so the units stage short of the target and go at once. A bound
// unit that settles at its rally rests, so only its binding keeps the next pick off it. A role names its unit by
// tasking id, never the record, so an attack serialises on the taskings' own terms. A QRF is an attack on a sighting
// cluster: its target moves, so it lays no rally, musters where its units stand and releases them on intercept.
if (!isServer) exitWith {};

// kind -> [[role, buckets, required buckets, waits on, lambda, reach], ...]. An attack stages on one unbroken line
// across the bearing it comes from, and its roles take the line's cells in order, centre first; a bucket holds any
// number of units at one cell. A centre bucket goes straight at the target. A side bucket marches its own lane to the
// cell `reach` cells abreast of the target, a cell further for each cell further out on the line, and closes from
// there. An assault's reach 1 sweeps the cells beside the fight, where closing straight from the line would bunch the
// wave onto one fire mission's worth of ground. A flank's maneuver hooks round the fight to OPCOM_HOOK_K, the weakest
// side first, and waits there until the role it names reads engaged, since an envelopment arriving before the
// defenders are committed to the front is worth nothing. Lambda bends its march around believed BLUFOR
// (fnc_opcom_task): an enveloping role is worth only what it reaches unseen, where the fight is the point of the fix's
// march.
DUWS_opcom_attackRoles = createHashMapFromArray [
    ["assault", [["attacker", OPCOM_ASSAULT_CELLS, 1, "", 0, 1]]],
    ["flank", [["fix", 1, 1, "", 0, 0], ["maneuver", 2, 1, "fix", 1, OPCOM_HOOK_K]]]
];

// -> the centre of the first dry cell on _pos's landmass at least _k cells from _pos's cell along _dir; [] when the two
// rings past it hold none. A rally across water would put the crossing between the muster and the fight, landing the
// wave a ferry trip at a time. The distance bound, not the ring test, ends the walk: past the play box every point
// clamps to one cell.
DUWS_fnc_opcom_rallyAt = {
    params ["_pos", "_dir", "_k"];
    private _mass = [_pos] call DUWS_fnc_opcom_massAt;
    private _out = [];
    for "_d" from 0 to ((_k + 3) * OPCOM_GRID_CELL * 1.5) step (OPCOM_GRID_CELL / 2) do {
        private _p = _pos getPos [_d, _dir];
        private _ring = [_pos, _p] call DUWS_fnc_opcom_cellDist;
        if (_ring > _k + 2) exitWith {};
        private _c = [[_p] call DUWS_fnc_opcom_w2c] call DUWS_fnc_opcom_c2w;
        if (_ring >= _k && {!(surfaceIsWater _c)} && {([_c] call DUWS_fnc_opcom_massAt) == _mass}) exitWith { _out = _c };
    };
    _out
};

// Believed BLUFOR in a jump-off's block, less the target's own: that block is the fight the fix draws, alike from every
// side.
DUWS_fnc_opcom_sideForce = {
    params ["_at", "_jump"];
    private _fight = [[_at] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells;
    private _ene = 0;
    {
        if !(_x in _fight) then { _ene = _ene + (DUWS_opcom_grid_ene select _x) };
    } forEach ([[_jump] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells);
    _ene
};

// -> [[role, rally, required, waits on, lambda, lane], ...], one a bucket, or [] when a required bucket finds no ground.
// An assault with no dry rally stages where it stands instead, since it has no geometry to lose. A lane is [] for a
// bucket that goes straight at the target.
DUWS_fnc_opcom_stageRoles = {
    params ["_kind", "_at", "_bearing"];
    private _roles = DUWS_opcom_attackRoles get _kind;
    private _rally = [_at, _bearing, OPCOM_RALLY_K] call DUWS_fnc_opcom_rallyAt;
    if (_rally isEqualTo [] && {_kind isNotEqualTo "assault"}) exitWith { [] };
    private _buckets = 0;
    { _buckets = _buckets + (_x select 1) } forEach _roles;
    private _mass = [_at] call DUWS_fnc_opcom_massAt;
    // Snapped to the grid's eight directions, so a line on a diagonal bearing still steps a whole cell.
    private _perp = 45 * round ((_bearing + 90) / 45);
    private _across = {
        params ["_p", "_i"];
        [(_p select 0) + _i * OPCOM_GRID_CELL * round (sin _perp), (_p select 1) + _i * OPCOM_GRID_CELL * round (cos _perp), 0]
    };
    private _onMass = { params ["_p"]; !(surfaceIsWater _p) && {([_p] call DUWS_fnc_opcom_massAt) == _mass} };
    // A blocked side slides the line rather than breaking it; a bucket past what the ground holds stacks on the rally.
    private _line = [0];
    private _edge = [1, -1];
    while {_rally isNotEqualTo [] && {count _line < _buckets} && {_edge isNotEqualTo [0, 0]}} do {
        {
            if (_x != 0 && {count _line < _buckets}) then {
                private _q = [_rally, _x] call _across;
                if ([_q] call _onMass && {([_at, _q] call DUWS_fnc_opcom_cellDist) >= OPCOM_RALLY_K}) then {
                    _line pushBack _x;
                    _edge set [_forEachIndex, _x + ([-1, 1] select (_x > 0))];
                } else {
                    _edge set [_forEachIndex, 0];
                };
            };
        } forEach +_edge;
    };
    private _out = [];
    private _ok = true;
    private _n = 0;
    {
        _x params ["_role", "_count", "_required", "_waits", "_lambda", "_reach"];
        private _mine = [];
        for "_k" from 1 to _count do {
            private _i = _line param [_n, 0];
            _n = _n + 1;
            private _p = _rally;
            private _lane = [];
            if (_i != 0) then {
                _p = [_rally, _i] call _across;
                _lane = [_at, _i + ([-1, 1] select (_i > 0)) * (_reach - 1)] call _across;
                if !([_lane] call _onMass) then { _lane = [] };
            };
            // A hook with no side to hook round is no bucket.
            if (_reach <= 1 || {_lane isNotEqualTo []}) then {
                private _weak = if (_reach > 1) then { [_at, _lane] call DUWS_fnc_opcom_sideForce } else { 0 };
                _mine pushBack [_weak, _k, _p, _lane];
            };
        };
        _mine sort true;
        if (count _mine < _required) then { _ok = false };
        { _out pushBack [_role, _x select 2, _forEachIndex < _required, _waits, _lambda, _x select 3] } forEach _mine;
    } forEach _roles;
    [[], _out] select _ok
};

DUWS_fnc_opcom_attackBind = {
    params ["_attack", "_role", "_t"];
    (_role get "units") pushBack (_t get "id");
    _t set ["boundTo", _attack get "id"];
};

// _roles as DUWS_fnc_opcom_stageRoles; the caller binds the units.
DUWS_fnc_opcom_attackOpen = {
    params ["_kind", "_target", "_pos", "_label", "_roles"];
    private _id = DUWS_opcom_attackSeq;
    DUWS_opcom_attackSeq = _id + 1;
    private _attack = createHashMapFromArray [
        ["id", _id], ["kind", _kind], ["target", _target], ["pos", _pos], ["label", _label],
        ["state", "buildup"], ["since", DUWS_opcom_tick], ["staged", -1], ["creep", []],
        ["roles", _roles apply {
            _x params ["_role", "_rally", "_required", "_waits", "_lambda", "_lane"];
            createHashMapFromArray [["role", _role], ["units", []], ["rally", _rally], ["required", _required],
                ["waits", _waits], ["lambda", _lambda], ["lane", _lane]]
        }]
    ];
    DUWS_opcom_attacks pushBack _attack;
    _attack
};

// -> the bucket's taskings still in the attack; a unit dead, gone, or taken out of it by a hand order is lost.
DUWS_fnc_opcom_roleUnits = {
    params ["_attack", "_role"];
    private _out = [];
    {
        private _t = [_x] call DUWS_fnc_opcom_byId;
        if (!isNil "_t" && {(_t get "status") isNotEqualTo "dead"} && {(_t getOrDefault ["boundTo", -1]) == (_attack get "id")}) then {
            _out pushBack _t;
        };
    } forEach (_role get "units");
    _out
};

// -> false once the QRF's lead sighting is no longer believed; else moves the attack onto it.
DUWS_fnc_opcom_qrfFollow = {
    params ["_attack"];
    private _i = DUWS_opcom_belief_key findIf { _x isEqualTo (_attack get "target") };
    if (_i < 0) exitWith { false };
    _attack set ["pos", +(DUWS_opcom_belief_pos select _i)];
    true
};

// Once a look disproves the lead, the group a unit's look found instead becomes the whole QRF's, a unit back on guard
// included, so the QRF hunts on as one. A unit that finds a nearer group while the lead stands is left to fight it:
// pulling it back would re-order the QRF every tick two units' looks disagree.
DUWS_fnc_opcom_qrfRekey = {
    params ["_attack"];
    private _believed = { params ["_key"]; (DUWS_opcom_belief_key findIf { _x isEqualTo _key }) >= 0 };
    if ([_attack get "target"] call _believed) exitWith {};
    private _units = [];
    { _units append ([_attack, _x] call DUWS_fnc_opcom_roleUnits) } forEach (_attack get "roles");
    private _i = _units findIf { (_x get "order") isEqualTo "intercept" && {[_x get "interceptKey"] call _believed} };
    if (_i < 0) exitWith {};
    private _key = (_units select _i) get "interceptKey";
    _attack set ["target", _key];
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) hunts %4", _attack get "id", _attack get "kind", _attack get "label", _key]] call fnc_log;
    {
        private _role = _x;
        {
            if ((_x get "interceptKey") isNotEqualTo _key && {(_x getOrDefault ["ridingOn", -1]) < 0}) then {
                _x set ["hold", 0];
                if !([_x, "intercept", _key, "", [], _role get "lambda"] call fnc_opcom_task) then { _x set ["boundTo", -1] };
            };
        } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
    } forEach (_attack get "roles");
};

// A QRF rider takes no order while its lift holds it: a live one refuses, and the refusal unbinds it from the attack,
// and a virtual one would be steered off its carry. So the launch, a rekey and the break-off pass it by, and it joins
// the hunt here once set down. After the launch no QRF unit but a dropped rider is on `move`.
DUWS_fnc_opcom_qrfLand = {
    params ["_attack"];
    {
        private _role = _x;
        {
            if ((_x get "order") isEqualTo "move" && {(_x getOrDefault ["ridingOn", -1]) < 0}) then {
                _x set ["hold", 0];
                if !([_x, "intercept", _attack get "target", "", [], _role get "lambda"] call fnc_opcom_task) then { _x set ["boundTo", -1] };
            };
        } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
    } forEach (_attack get "roles");
};

// Marks rather than removes: the runner calls this mid-pass over the store. A creep still unfired is lost with its
// attack, the AP spent at commit as a lost truck's is.
DUWS_fnc_opcom_attackClose = {
    params ["_attack", "_outcome"];
    { { _x set ["boundTo", -1] } forEach ([_attack, _x] call DUWS_fnc_opcom_roleUnits) } forEach (_attack get "roles");
    _attack set ["state", "done"];
    if ((_attack get "kind") isNotEqualTo "qrf") then {
        OPCOM_ATTACK_COOLDOWN params ["_min", "_max"];
        private _n = _min + floor random (_max - _min + 1);
        DUWS_opcom_attackReadyTick = DUWS_opcom_tick + _n;
        _outcome = format ["%1; no assault or flank for %2 ticks", _outcome, _n];
    };
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) %4%5", _attack get "id", _attack get "kind", _attack get "label", _outcome,
        ["", ", its creep unfired"] select ((_attack get "creep") isNotEqualTo [])]] call fnc_log;
};

// Off capture, or its target stays busy to the attack sweep. Guard, not return: an engaged group ignores a move order
// (arma_engine_gotchas.md).
DUWS_fnc_opcom_attackBreak = {
    params ["_attack", "_outcome"];
    {
        {
            if ((_x getOrDefault ["ridingOn", -1]) < 0) then {
                _x set ["hold", 0];
                [_x, "guard"] call fnc_opcom_task;
            };
        } forEach ([_attack, _x] call DUWS_fnc_opcom_roleUnits);
    } forEach (_attack get "roles");
    [_attack, _outcome] call DUWS_fnc_opcom_attackClose;
};

DUWS_fnc_opcom_bucketForce = {
    params ["_attack", "_role"];
    private _force = 0;
    { _force = _force + (_x get "effForce") } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
    _force
};

// -> [[rally, required, force, units, lambda], ...], each bucket as it stands (DUWS_fnc_opcom_attackPackage).
DUWS_fnc_opcom_attackBuckets = {
    params ["_attack"];
    (_attack get "roles") apply {
        [_x get "rally", _x get "required", [_attack, _x] call DUWS_fnc_opcom_bucketForce, count (_x get "units"), _x get "lambda"]
    }
};

// An assault or flank moves virtually as one column, so a fast hull reaches neither its rally nor the fight ahead.
DUWS_fnc_opcom_attackPace = {
    params ["_attack"];
    private _pace = 0;
    {
        {
            if ([_x] call DUWS_fnc_opcom_marching) then {
                private _mt = _x get "moveType";
                private _tr = [_x getOrDefault ["ridingOn", -1]] call DUWS_fnc_opcom_byId;
                if (!isNil "_tr") then { _mt = _tr get "moveType" };
                _pace = _pace max (DUWS_opcom_speed getOrDefault [_mt, 30]);
            };
        } forEach ([_attack, _x] call DUWS_fnc_opcom_roleUnits);
    } forEach (_attack get "roles");
    _pace
};

DUWS_fnc_opcom_boundForce = {
    params ["_attack"];
    private _force = 0;
    { _force = _force + ([_attack, _x] call DUWS_fnc_opcom_bucketForce) } forEach (_attack get "roles");
    _force
};

// The force an attack binds over the believed BLUFOR force at its target, both as the 3x3 block reads them.
DUWS_fnc_opcom_musterRatio = {
    params ["_attack"];
    ([_attack get "pos"] call DUWS_fnc_opcom_blockForce) params ["", "_ene"];
    ([_attack] call DUWS_fnc_opcom_boundForce) * (call DUWS_fnc_opcom_blockGain) / (_ene + 1)
};

// -> the bucket the next unit joins, -1 when none should: an empty required bucket at any odds, else, while the muster
// is short of the ideal bar, the bucket with the least force, so the frontage and the sides fill evenly.
DUWS_fnc_opcom_joinBucket = {
    params ["_attack"];
    private _roles = _attack get "roles";
    private _n = 0;
    { _n = _n + count (_x get "units") } forEach _roles;
    if ((_attack get "state") isNotEqualTo "buildup" || {_n >= OPCOM_ATTACK_UNITS}) exitWith { -1 };
    private _i = _roles findIf { (_x get "required") && {(_x get "units") isEqualTo []} };
    if (_i >= 0) exitWith { _i };
    if (([_attack] call DUWS_fnc_opcom_musterRatio) >= OPCOM_MUSTER_IDEAL) exitWith { -1 };
    private _least = [];
    { _least pushBack [[_attack, _x] call DUWS_fnc_opcom_bucketForce, _forEachIndex] } forEach _roles;
    _least sort true;
    (_least select 0) select 1
};

// A unit that cannot take the order leaves the attack, and the execution step drops it. A bucket with a lane marches
// it first, and DUWS_fnc_opcom_converge releases it again onto the target. A lane outside the target's block is a
// hook, which goes round the fight rather than through it.
DUWS_fnc_opcom_releaseRole = {
    params ["_attack", "_role"];
    private _order = [["capture", _attack get "pos"], ["intercept", _attack get "target"]] select ((_attack get "kind") isEqualTo "qrf");
    private _lane = _role get "lane";
    private _avoid = [];
    if (_lane isNotEqualTo []) then {
        _order = ["move", _lane];
        if (([_attack get "pos", _lane] call DUWS_fnc_opcom_cellDist) > 1) then {
            _avoid = [[_attack get "pos"] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells;
        };
    };
    {
        if ((_x getOrDefault ["ridingOn", -1]) < 0) then {
            _x set ["hold", 0];
            if !(([_x] + _order + ["", [], _role get "lambda", _avoid]) call fnc_opcom_task) then { _x set ["boundTo", -1] };
        };
    } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
};

// A bucket stops waiting on a role once that role reads engaged, has lost every unit or has ended its fight, and never
// waits again, since a lull in the fix's fight would otherwise park a hook at its jump-off. It then closes on the
// target once every unit of it stands on its lane out of contact. The engine's read of the fight, not belief, since
// only recon clears a sighting, and a stale one in the lane's cell would park the bucket until it expired. A virtual
// unit renders near any real BLUFOR, so one standing unrendered has no fight in its cell.
DUWS_fnc_opcom_converge = {
    params ["_attack"];
    private _roles = _attack get "roles";
    {
        private _role = _x;
        if ((_role get "lane") isNotEqualTo []) then {
            if ((_role get "waits") isNotEqualTo "") then {
                private _by = [];
                { if ((_x get "role") isEqualTo (_role get "waits")) then { _by append ([_attack, _x] call DUWS_fnc_opcom_roleUnits) } } forEach _roles;
                if ((_by findIf { (_x get "status") isEqualTo "engaged" }) >= 0
                    || {(_by findIf { [_x] call DUWS_fnc_opcom_marching }) < 0}) then { _role set ["waits", ""] };
            };
            if ((_role get "waits") isEqualTo ""
                && {(([_attack, _role] call DUWS_fnc_opcom_roleUnits) findIf {
                    ([_x] call DUWS_fnc_opcom_marching) || {(_x get "status") isEqualTo "engaged"}
                }) < 0}) then {
                _role set ["lane", []];
                [_attack, _role] call DUWS_fnc_opcom_releaseRole;
            };
        };
    } forEach _roles;
};

// Every bucket sets off at once, so nothing dribbles into contact; a bucket still empty is dropped.
DUWS_fnc_opcom_launch = {
    params ["_attack", "_r"];
    _attack set ["roles", (_attack get "roles") select { (_x get "units") isNotEqualTo [] }];
    _attack set ["state", "execution"];
    private _n = 0;
    { _n = _n + count (_x get "units") } forEach (_attack get "roles");
    { [_attack, _x] call DUWS_fnc_opcom_releaseRole } forEach (_attack get "roles");
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) launches %4 unit(s) in %5 bucket(s) at %6:1", _attack get "id",
        _attack get "kind", _attack get "label", _n, count (_attack get "roles"), _r toFixed 2]] call fnc_log;
};

DUWS_fnc_opcom_buildupStep = {
    params ["_attack"];
    private _qrf = (_attack get "kind") isEqualTo "qrf";
    if (_qrf && {!([_attack] call DUWS_fnc_opcom_qrfFollow)}) exitWith {
        [_attack, "dropped: the sighting is no longer believed"] call DUWS_fnc_opcom_attackClose;
    };
    if (_qrf && {[_attack get "pos"] call DUWS_fnc_opcom_inBaseCells}) exitWith {
        [_attack, "dropped: the sighting entered the base cells"] call DUWS_fnc_opcom_attackClose;
    };
    if (!_qrf && {!([_attack get "target"] call DUWS_fnc_opcom_captureHolds)}) exitWith {
        [_attack, "dropped: the target is no longer BLUFOR's"] call DUWS_fnc_opcom_attackClose;
    };
    private _units = [];
    private _lost = false;
    {
        private _live = [_attack, _x] call DUWS_fnc_opcom_roleUnits;
        if (count _live < count (_x get "units")) then { _lost = true };
        _units append _live;
    } forEach (_attack get "roles");
    // A loss while staging means BLUFOR found the rally: the survivors go free rather than wait there for the next.
    if (_lost) exitWith { [_attack, "aborted: a staging unit was lost"] call DUWS_fnc_opcom_attackClose };
    private _r = [_attack] call DUWS_fnc_opcom_musterRatio;
    private _ready = ((_attack get "roles") findIf { (_x get "required") && {(_x get "units") isEqualTo []} }) < 0
        && {(_units findIf { ([_x] call DUWS_fnc_opcom_marching) && {(_x getOrDefault ["ridingOn", -1]) < 0} }) < 0};
    if (_ready && {_r >= ([OPCOM_MUSTER_MIN, OPCOM_MUSTER_IDEAL] select _qrf)}) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    // A unit sent to join restarts the wait, since it is what a muster short of the minimum waits for.
    private _staged = -1;
    if (_ready && {!_qrf}) then {
        _staged = _attack getOrDefault ["staged", -1];
        if (_staged < 0) then { _staged = DUWS_opcom_tick };
    };
    _attack set ["staged", _staged];
    if (DUWS_opcom_tick - (_attack get "since") < ([OPCOM_MUSTER_EXPIRY, OPCOM_QRF_EXPIRY] select _qrf)
        && {_staged < 0 || {DUWS_opcom_tick - _staged < OPCOM_MUSTER_STAGED}}) exitWith {};
    private _bar = [OPCOM_ATTACK_BREAK, OPCOM_MUSTER_MIN] select _qrf;
    if (_r >= _bar) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    [_attack, format ["abandoned at %1:1, short of %2:1", _r toFixed 2, _bar]] call DUWS_fnc_opcom_attackClose;
};

// A unit lost once the attack runs leaves the rest to finish it. A bucket still on its lane has yet to close, so it keeps
// the attack open while it rests there.
DUWS_fnc_opcom_executionStep = {
    params ["_attack"];
    {
        private _role = _x;
        _role set ["units", ([_attack, _role] call DUWS_fnc_opcom_roleUnits) apply { _x get "id" }];
    } forEach (_attack get "roles");
    private _roles = (_attack get "roles") select { (_x get "units") isNotEqualTo [] };
    _attack set ["roles", _roles];
    if (_roles isEqualTo []) exitWith { [_attack, "aborted: every unit was lost"] call DUWS_fnc_opcom_attackClose };
    private _qrf = (_attack get "kind") isEqualTo "qrf";
    if (_qrf) then {
        [_attack] call DUWS_fnc_opcom_qrfRekey;
        // Following the lead keeps the next QRF off the same cluster.
        [_attack] call DUWS_fnc_opcom_qrfFollow;
    };
    if (_qrf && {[_attack get "pos"] call DUWS_fnc_opcom_inBaseCells}) exitWith {
        [_attack, "broken off: the sighting entered the base cells"] call DUWS_fnc_opcom_attackBreak;
    };
    if (_qrf) then { [_attack] call DUWS_fnc_opcom_qrfLand };
    private _r = [_attack] call DUWS_fnc_opcom_musterRatio;
    if (_r < OPCOM_ATTACK_BREAK) exitWith {
        [_attack, format ["failed at %1:1, below the break-off bar", _r toFixed 2]] call DUWS_fnc_opcom_attackBreak;
    };
    [_attack] call DUWS_fnc_opcom_converge;
    if ((_attack get "creep") isNotEqualTo []) then { [_attack] call DUWS_fnc_opcom_creepStep };
    private _busy = _roles findIf {
        (_x get "lane") isNotEqualTo [] || {(([_attack, _x] call DUWS_fnc_opcom_roleUnits) findIf { [_x] call DUWS_fnc_opcom_marching }) >= 0}
    };
    if (_busy < 0) then { [_attack, "done"] call DUWS_fnc_opcom_attackClose };
};

// After the task step, so an order that ended this tick frees its unit before the pick.
DUWS_fnc_opcom_attackStep = {
    {
        if ((_x get "state") isEqualTo "buildup") then { [_x] call DUWS_fnc_opcom_buildupStep } else { [_x] call DUWS_fnc_opcom_executionStep };
    } forEach DUWS_opcom_attacks;
    DUWS_opcom_attacks = DUWS_opcom_attacks select { (_x get "state") isNotEqualTo "done" };
};
