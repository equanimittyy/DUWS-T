// Locality: server, [] call'd at load. An Attack's record and its per-tick runner (opcom_plan.md §Attack): the units it
// binds in role buckets, where each bucket stages, the muster that launches them together and what releases each. No-retreat turns
// a force dribbled into contact into defeat in detail, so the units stage short of the target and go at once. A bound
// unit that settles at its rally rests, so only its binding keeps the next pick off it. A role names its unit by
// tasking id, never the record, so an attack serialises on the taskings' own terms.
if (!isServer) exitWith {};

// kind -> [[role, bearings, buckets, required buckets, released by, lambda], ...], bearings in degrees off the one the
// attack comes from. A bucket holds any number of units at one rally. A role with one bearing lays its buckets a cell
// apart across its frontage; one with several stages each bucket on its own side, the weakest first, so a flank hits
// where the defenders are thinnest. "" releases it at launch; a role
// name releases it once that role's unit reads engaged, since an envelopment arriving before the defenders are
// committed to the front is worth nothing. Lambda bends its march around believed BLUFOR (fnc_opcom_task): an
// enveloping role is worth only what it reaches unseen, where the fight is the point of the fix's march.
DUWS_opcom_attackRoles = createHashMapFromArray [
    ["assault", [["attacker", [0], OPCOM_ASSAULT_CELLS, 1, "", 0]]],
    ["flank", [["fix", [0], 1, 1, "", 0], ["maneuver", [90, -90, 135, -135, 180], 5, 1, "fix", 1]]]
];

// -> the centre of the first dry cell at least _k cells from _pos's cell along _dir; [] when the two rings past it are
// water too. The distance bound, not the ring test, ends the walk: past the play box every point clamps to one cell.
DUWS_fnc_opcom_rallyAt = {
    params ["_pos", "_dir", "_k"];
    private _out = [];
    for "_d" from 0 to ((_k + 3) * OPCOM_GRID_CELL * 1.5) step (OPCOM_GRID_CELL / 2) do {
        private _p = _pos getPos [_d, _dir];
        private _ring = [_pos, _p] call DUWS_fnc_opcom_cellDist;
        if (_ring > _k + 2) exitWith {};
        private _c = [[_p] call DUWS_fnc_opcom_w2c] call DUWS_fnc_opcom_c2w;
        if (_ring >= _k && {!(surfaceIsWater _c)}) exitWith { _out = _c };
    };
    _out
};

// Believed BLUFOR in a rally's block, less the target's own: that block is the fight the fix draws, alike from every side.
DUWS_fnc_opcom_sideForce = {
    params ["_at", "_rally"];
    private _fight = [[_at] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells;
    private _ene = 0;
    {
        if !(_x in _fight) then { _ene = _ene + (DUWS_opcom_grid_ene select _x) };
    } forEach ([[_rally] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells);
    _ene
};

// -> [[role, rally, required, released by, lambda], ...], one a bucket, or [] when a role finds no dry rally. An assault
// stages where it stands instead, since it has no geometry to lose.
DUWS_fnc_opcom_stageRoles = {
    params ["_kind", "_at", "_bearing"];
    private _out = [];
    private _ok = true;
    {
        _x params ["_role", "_bearings", "_buckets", "_required", "_release", "_lambda"];
        if (count _bearings > 1) then {
            private _rallies = _bearings apply { [_at, _bearing + _x, OPCOM_RALLY_K] call DUWS_fnc_opcom_rallyAt };
            private _sides = [];
            {
                // Equal belief goes to the shorter swing, then to either side at random.
                if (_x isNotEqualTo []) then {
                    _sides pushBack [[_at, _x] call DUWS_fnc_opcom_sideForce, abs (_bearings select _forEachIndex), random 1, _forEachIndex];
                };
            } forEach _rallies;
            _sides sort true;
            if (count _sides < _required) then { _ok = false };
            { _out pushBack [_role, _rallies select (_x select 3), _forEachIndex < _required, _release, _lambda] } forEach (_sides select [0, _buckets]);
        } else {
            private _dir = _bearing + (_bearings select 0);
            private _rally = [_at, _dir, OPCOM_RALLY_K] call DUWS_fnc_opcom_rallyAt;
            if (_rally isEqualTo [] && {_kind isNotEqualTo "assault"}) then { _ok = false };
            for "_n" from 0 to (_buckets - 1) do {
                private _p = _rally;
                if (_n > 0 && {_rally isNotEqualTo []}) then {
                    private _q = [[_rally getPos [OPCOM_GRID_CELL * ceil (_n / 2), _dir + ([90, -90] select (_n mod 2 == 0))]]
                        call DUWS_fnc_opcom_w2c] call DUWS_fnc_opcom_c2w;
                    if (!(surfaceIsWater _q) && {([_at, _q] call DUWS_fnc_opcom_cellDist) >= OPCOM_RALLY_K}) then { _p = _q };
                };
                _out pushBack [_role, _p, _n < _required, _release, _lambda];
            };
        };
    } forEach (DUWS_opcom_attackRoles get _kind);
    [[], _out] select _ok
};

DUWS_fnc_opcom_attackBind = {
    params ["_attack", "_role", "_t"];
    (_role get "units") pushBack (_t get "id");
    _t set ["boundTo", _attack get "id"];
};

// _t takes the first bucket; the rest stay open for later picks to fill. _roles as DUWS_fnc_opcom_stageRoles.
DUWS_fnc_opcom_attackOpen = {
    params ["_kind", "_target", "_pos", "_label", "_roles", "_t"];
    private _id = DUWS_opcom_attackSeq;
    DUWS_opcom_attackSeq = _id + 1;
    private _attack = createHashMapFromArray [
        ["id", _id], ["kind", _kind], ["target", _target], ["pos", _pos], ["label", _label],
        ["state", "buildup"], ["since", DUWS_opcom_tick], ["creep", []],
        ["roles", _roles apply {
            _x params ["_role", "_rally", "_required", "_release", "_lambda"];
            createHashMapFromArray [["role", _role], ["units", []], ["rally", _rally], ["required", _required],
                ["release", _release], ["released", false], ["lambda", _lambda]]
        }]
    ];
    [_attack, (_attack get "roles") select 0, _t] call DUWS_fnc_opcom_attackBind;
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

// Marks rather than removes: the runner calls this mid-pass over the store. A creep still unfired is lost with its
// attack, the AP spent at commit as a lost truck's is.
DUWS_fnc_opcom_attackClose = {
    params ["_attack", "_outcome"];
    { { _x set ["boundTo", -1] } forEach ([_attack, _x] call DUWS_fnc_opcom_roleUnits) } forEach (_attack get "roles");
    _attack set ["state", "done"];
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) %4%5", _attack get "id", _attack get "kind", _attack get "label", _outcome,
        ["", ", its creep unfired"] select ((_attack get "creep") isNotEqualTo [])]] call fnc_log;
};

DUWS_fnc_opcom_bucketForce = {
    params ["_attack", "_role"];
    private _force = 0;
    { _force = _force + (_x get "effForce") } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
    _force
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

// A unit that cannot take the order leaves the attack, and the execution step drops it.
DUWS_fnc_opcom_releaseRole = {
    params ["_attack", "_role"];
    _role set ["released", true];
    {
        _x set ["hold", 0];
        if !([_x, "capture", _attack get "pos", "", [], _role get "lambda"] call fnc_opcom_task) then { _x set ["boundTo", -1] };
    } forEach ([_attack, _role] call DUWS_fnc_opcom_roleUnits);
};

// A held bucket goes in once any unit of the role it waits on reads engaged, or that role is lost, since then the fight
// is on.
DUWS_fnc_opcom_releaseHeld = {
    params ["_attack"];
    private _roles = _attack get "roles";
    {
        private _role = _x;
        if !(_role get "released") then {
            private _by = [];
            { if ((_x get "role") isEqualTo (_role get "release")) then { _by append ([_attack, _x] call DUWS_fnc_opcom_roleUnits) } } forEach _roles;
            if (_by isEqualTo [] || {(_by findIf { (_x get "status") isEqualTo "engaged" }) >= 0}) then {
                [_attack, _role] call DUWS_fnc_opcom_releaseRole;
            };
        };
    } forEach _roles;
};

// Every bucket released at launch goes at once, so the attack arrives as one wave; a bucket still empty is dropped.
DUWS_fnc_opcom_launch = {
    params ["_attack", "_r"];
    _attack set ["roles", (_attack get "roles") select { (_x get "units") isNotEqualTo [] }];
    _attack set ["state", "execution"];
    private _n = 0;
    { _n = _n + count (_x get "units") } forEach (_attack get "roles");
    { if ((_x get "release") isEqualTo "") then { [_attack, _x] call DUWS_fnc_opcom_releaseRole } } forEach (_attack get "roles");
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) launches %4 unit(s) in %5 bucket(s) at %6:1", _attack get "id",
        _attack get "kind", _attack get "label", _n, count (_attack get "roles"), _r toFixed 2]] call fnc_log;
};

DUWS_fnc_opcom_buildupStep = {
    params ["_attack"];
    if !([_attack get "target"] call DUWS_fnc_opcom_captureHolds) exitWith {
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
        && {(_units findIf { [_x] call DUWS_fnc_opcom_marching }) < 0};
    if (_ready && {_r >= OPCOM_MUSTER_IDEAL}) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    if (DUWS_opcom_tick - (_attack get "since") < OPCOM_MUSTER_EXPIRY) exitWith {};
    if (_r >= OPCOM_MUSTER_MIN) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    [_attack, format ["abandoned at %1:1, short of the minimum", _r toFixed 2]] call DUWS_fnc_opcom_attackClose;
};

// A unit lost once the attack runs leaves the rest to finish it. A bucket still held waits at rest on its rally, so
// only the released ones say whether the attack is over.
DUWS_fnc_opcom_executionStep = {
    params ["_attack"];
    {
        private _role = _x;
        _role set ["units", ([_attack, _role] call DUWS_fnc_opcom_roleUnits) apply { _x get "id" }];
    } forEach (_attack get "roles");
    private _roles = (_attack get "roles") select { (_x get "units") isNotEqualTo [] };
    _attack set ["roles", _roles];
    if (_roles isEqualTo []) exitWith { [_attack, "aborted: every unit was lost"] call DUWS_fnc_opcom_attackClose };
    [_attack] call DUWS_fnc_opcom_releaseHeld;
    if ((_attack get "creep") isNotEqualTo []) then { [_attack] call DUWS_fnc_opcom_creepStep };
    private _busy = _roles findIf {
        (_x get "released") && {(([_attack, _x] call DUWS_fnc_opcom_roleUnits) findIf { [_x] call DUWS_fnc_opcom_marching }) >= 0}
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
