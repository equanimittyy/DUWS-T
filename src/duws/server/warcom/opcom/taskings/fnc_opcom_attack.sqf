// Locality: server, [] call'd at load. An Attack's record and its per-tick runner (opcom_plan.md §Attack): the units it
// binds in roles, where each stages, the muster that launches them together and what releases each. No-retreat turns
// a force dribbled into contact into defeat in detail, so the units stage short of the target and go at once. A bound
// unit that settles at its rally rests, so only its binding keeps the next pick off it. A role names its unit by
// tasking id, never the record, so an attack serialises on the taskings' own terms.
if (!isServer) exitWith {};

// kind -> [[role, bearings, slots, required slots, released by, lambda], ...], bearings in degrees off the one the
// attack comes from. A role with one bearing widens its frontage a cell a slot; one with several stages each slot on
// its own side, the weakest first, so a flank hits where the defenders are thinnest. "" releases it at launch; a role
// name releases it once that role's unit reads engaged, since an envelopment arriving before the defenders are
// committed to the front is worth nothing. Lambda bends its march around believed BLUFOR (fnc_opcom_task): an
// enveloping role is worth only what it reaches unseen, where the fight is the point of the fix's march.
DUWS_opcom_attackRoles = createHashMapFromArray [
    ["assault", [["attacker", [0], OPCOM_ASSAULT_ROLES, 1, "", 0]]],
    ["flank", [["fix", [0], 1, 1, "", 0], ["maneuver", [90, -90, 135, -135, 180], 2, 1, "fix", 1]]]
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

// -> [[role, rally, required, released by, lambda], ...], one a slot, or [] when a role finds no dry rally. An assault
// stages where it stands instead, since it has no geometry to lose.
DUWS_fnc_opcom_stageRoles = {
    params ["_kind", "_at", "_bearing"];
    private _out = [];
    private _ok = true;
    {
        _x params ["_role", "_bearings", "_slots", "_required", "_release", "_lambda"];
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
            { _out pushBack [_role, _rallies select (_x select 3), _forEachIndex < _required, _release, _lambda] } forEach (_sides select [0, _slots]);
        } else {
            private _dir = _bearing + (_bearings select 0);
            private _rally = [_at, _dir, OPCOM_RALLY_K] call DUWS_fnc_opcom_rallyAt;
            if (_rally isEqualTo [] && {_kind isNotEqualTo "assault"}) then { _ok = false };
            for "_n" from 0 to (_slots - 1) do {
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
    _role set ["unit", _t get "id"];
    _t set ["boundTo", _attack get "id"];
};

// _t takes the first role; a role past it stays open for a later pick to fill. _roles as DUWS_fnc_opcom_stageRoles.
DUWS_fnc_opcom_attackOpen = {
    params ["_kind", "_target", "_pos", "_label", "_roles", "_t"];
    private _id = DUWS_opcom_attackSeq;
    DUWS_opcom_attackSeq = _id + 1;
    private _attack = createHashMapFromArray [
        ["id", _id], ["kind", _kind], ["target", _target], ["pos", _pos], ["label", _label],
        ["state", "buildup"], ["since", DUWS_opcom_tick], ["creep", []],
        ["roles", _roles apply {
            _x params ["_role", "_rally", "_required", "_release", "_lambda"];
            createHashMapFromArray [["role", _role], ["unit", -1], ["rally", _rally], ["required", _required],
                ["release", _release], ["released", false], ["lambda", _lambda]]
        }]
    ];
    [_attack, (_attack get "roles") select 0, _t] call DUWS_fnc_opcom_attackBind;
    DUWS_opcom_attacks pushBack _attack;
    _attack
};

// -> the role's tasking, or nil once it is lost: dead, gone, or taken out of the attack by a hand order.
DUWS_fnc_opcom_roleUnit = {
    params ["_attack", "_role"];
    private _t = [_role get "unit"] call DUWS_fnc_opcom_byId;
    if (isNil "_t" || {(_t get "status") isEqualTo "dead"} || {(_t getOrDefault ["boundTo", -1]) != (_attack get "id")}) exitWith { nil };
    _t
};

// Marks rather than removes: the runner calls this mid-pass over the store. A creep still unfired is lost with its
// attack, the AP spent at commit as a lost truck's is.
DUWS_fnc_opcom_attackClose = {
    params ["_attack", "_outcome"];
    {
        private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then { _t set ["boundTo", -1] };
    } forEach (_attack get "roles");
    _attack set ["state", "done"];
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) %4%5", _attack get "id", _attack get "kind", _attack get "label", _outcome,
        ["", ", its creep unfired"] select ((_attack get "creep") isNotEqualTo [])]] call fnc_log;
};

DUWS_fnc_opcom_boundForce = {
    params ["_attack"];
    private _force = 0;
    {
        private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then { _force = _force + (_t get "effForce") };
    } forEach (_attack get "roles");
    _force
};

// The force an attack binds over the believed BLUFOR force at its target, both as the 3x3 block reads them.
DUWS_fnc_opcom_musterRatio = {
    params ["_attack"];
    ([_attack get "pos"] call DUWS_fnc_opcom_blockForce) params ["", "_ene"];
    ([_attack] call DUWS_fnc_opcom_boundForce) * (call DUWS_fnc_opcom_blockGain) / (_ene + 1)
};

// A role that cannot take the order leaves the attack, and the execution step drops it.
DUWS_fnc_opcom_releaseRole = {
    params ["_attack", "_role"];
    _role set ["released", true];
    private _t = [_attack, _role] call DUWS_fnc_opcom_roleUnit;
    if (isNil "_t") exitWith {};
    _t set ["hold", 0];
    if !([_t, "capture", _attack get "pos", "", [], _role get "lambda"] call fnc_opcom_task) then { _t set ["boundTo", -1] };
};

// A held role goes in once the role it waits on reads engaged, or is lost, since then the fight is on.
DUWS_fnc_opcom_releaseHeld = {
    params ["_attack"];
    private _roles = _attack get "roles";
    {
        private _role = _x;
        if !(_role get "released") then {
            private _i = _roles findIf { (_x get "role") isEqualTo (_role get "release") };
            private _by = if (_i < 0) then { nil } else { [_attack, _roles select _i] call DUWS_fnc_opcom_roleUnit };
            if (isNil "_by" || {(_by get "status") isEqualTo "engaged"}) then { [_attack, _role] call DUWS_fnc_opcom_releaseRole };
        };
    } forEach _roles;
};

// Every role released at launch goes at once, so the attack arrives as one wave; a slot still open is dropped.
DUWS_fnc_opcom_launch = {
    params ["_attack", "_r"];
    _attack set ["roles", (_attack get "roles") select { private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit; !isNil "_t" }];
    _attack set ["state", "execution"];
    { if ((_x get "release") isEqualTo "") then { [_attack, _x] call DUWS_fnc_opcom_releaseRole } } forEach (_attack get "roles");
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) launches %4 unit(s) at %5:1", _attack get "id", _attack get "kind",
        _attack get "label", count (_attack get "roles"), _r toFixed 2]] call fnc_log;
};

DUWS_fnc_opcom_buildupStep = {
    params ["_attack"];
    if !([_attack get "target"] call DUWS_fnc_opcom_captureHolds) exitWith {
        [_attack, "dropped: the target is no longer BLUFOR's"] call DUWS_fnc_opcom_attackClose;
    };
    private _units = [];
    private _lost = false;
    {
        if ((_x get "unit") >= 0) then {
            private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit;
            if (isNil "_t") then { _lost = true } else { _units pushBack _t };
        };
    } forEach (_attack get "roles");
    // A loss while staging means BLUFOR found the rally: the survivors go free rather than wait there for the next.
    if (_lost) exitWith { [_attack, "aborted: a staging unit was lost"] call DUWS_fnc_opcom_attackClose };
    private _r = [_attack] call DUWS_fnc_opcom_musterRatio;
    private _ready = ((_attack get "roles") findIf { (_x get "required") && {(_x get "unit") < 0} }) < 0
        && {(_units findIf { [_x] call DUWS_fnc_opcom_marching }) < 0};
    if (_ready && {_r >= OPCOM_MUSTER_IDEAL}) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    if (DUWS_opcom_tick - (_attack get "since") < OPCOM_MUSTER_EXPIRY) exitWith {};
    if (_r >= OPCOM_MUSTER_MIN) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    [_attack, format ["abandoned at %1:1, short of the minimum", _r toFixed 2]] call DUWS_fnc_opcom_attackClose;
};

// A unit lost once the attack runs leaves the rest to finish it. A role still held waits at rest on its rally, so only
// the released ones say whether the attack is over.
DUWS_fnc_opcom_executionStep = {
    params ["_attack"];
    private _roles = (_attack get "roles") select { private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit; !isNil "_t" };
    _attack set ["roles", _roles];
    if (_roles isEqualTo []) exitWith { [_attack, "aborted: every unit was lost"] call DUWS_fnc_opcom_attackClose };
    [_attack] call DUWS_fnc_opcom_releaseHeld;
    if ((_attack get "creep") isNotEqualTo []) then { [_attack] call DUWS_fnc_opcom_creepStep };
    private _busy = _roles findIf {
        private _t = [_attack, _x] call DUWS_fnc_opcom_roleUnit;
        (_x get "released") && {!isNil "_t"} && {[_t] call DUWS_fnc_opcom_marching}
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
