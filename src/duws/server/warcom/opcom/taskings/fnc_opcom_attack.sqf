// Locality: server, [] call'd at load. An Attack's record and its per-tick runner (opcom_plan.md §Attack): the units it
// binds in role buckets, where each bucket stages, the muster that launches them together and what releases each. No-retreat turns
// a force dribbled into contact into defeat in detail, so the units stage short of the target and go at once. A bound
// unit that settles at its rally rests, so only its binding keeps the next pick off it. A role names its unit by
// tasking id, never the record, so an attack serialises on the taskings' own terms. A QRF is an attack on a sighting
// cluster: its target moves, so it lays no rally, musters where its units stand and releases them on intercept.
if (!isServer) exitWith {};

// kind -> [[role, bearings, buckets, required buckets, released by, lambda], ...], bearings in degrees off the one the
// attack comes from. A bucket holds any number of units at one rally. A role with one bearing lays its buckets in one
// unbroken line across its frontage, and each side bucket marches its own lane to the cell abreast of the target
// before it closes: buckets closing straight from the line would bunch onto one fire mission's worth of ground and
// leave the cells beside the fight unswept. A role with several bearings stages each bucket on its own side, the
// weakest first, so a flank hits where the defenders are thinnest. "" releases it at launch; a role
// name releases it once that role's unit reads engaged, since an envelopment arriving before the defenders are
// committed to the front is worth nothing. Lambda bends its march around believed BLUFOR (fnc_opcom_task): an
// enveloping role is worth only what it reaches unseen, where the fight is the point of the fix's march.
DUWS_opcom_attackRoles = createHashMapFromArray [
    ["assault", [["attacker", [0], OPCOM_ASSAULT_CELLS, 1, "", 0]]],
    ["flank", [["fix", [0], 1, 1, "", 0], ["maneuver", [90, -90, 135, -135, 180], 5, 1, "fix", 1]]]
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

// -> [[role, rally, required, released by, lambda, lane], ...], one a bucket, or [] when a role finds no dry rally. An
// assault stages where it stands instead, since it has no geometry to lose. A lane is [] for a bucket that goes straight
// at the target.
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
            { _out pushBack [_role, _rallies select (_x select 3), _forEachIndex < _required, _release, _lambda, []] } forEach (_sides select [0, _buckets]);
        } else {
            private _dir = _bearing + (_bearings select 0);
            private _rally = [_at, _dir, OPCOM_RALLY_K] call DUWS_fnc_opcom_rallyAt;
            if (_rally isEqualTo [] && {_kind isNotEqualTo "assault"}) then { _ok = false };
            private _mass = [_at] call DUWS_fnc_opcom_massAt;
            // Snapped to the grid's eight directions, so a line on a diagonal bearing still steps a whole cell.
            private _perp = 45 * round ((_dir + 90) / 45);
            private _across = {
                params ["_p", "_i"];
                [(_p select 0) + _i * OPCOM_GRID_CELL * round (sin _perp), (_p select 1) + _i * OPCOM_GRID_CELL * round (cos _perp), 0]
            };
            private _onMass = { params ["_p"]; !(surfaceIsWater _p) && {([_p] call DUWS_fnc_opcom_massAt) == _mass} };
            // A blocked side slides the line rather than breaking it; a bucket past what the ground holds stacks on
            // the rally.
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
            for "_n" from 0 to (_buckets - 1) do {
                private _i = _line param [_n, 0];
                private _p = _rally;
                private _lane = [];
                if (_i != 0) then {
                    _p = [_rally, _i] call _across;
                    _lane = [_at, _i] call _across;
                    if !([_lane] call _onMass) then { _lane = [] };
                };
                _out pushBack [_role, _p, _n < _required, _release, _lambda, _lane];
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

// _roles as DUWS_fnc_opcom_stageRoles; the caller binds the units.
DUWS_fnc_opcom_attackOpen = {
    params ["_kind", "_target", "_pos", "_label", "_roles"];
    private _id = DUWS_opcom_attackSeq;
    DUWS_opcom_attackSeq = _id + 1;
    private _attack = createHashMapFromArray [
        ["id", _id], ["kind", _kind], ["target", _target], ["pos", _pos], ["label", _label],
        ["state", "buildup"], ["since", DUWS_opcom_tick], ["creep", []],
        ["roles", _roles apply {
            _x params ["_role", "_rally", "_required", "_release", "_lambda", "_lane"];
            createHashMapFromArray [["role", _role], ["units", []], ["rally", _rally], ["required", _required],
                ["release", _release], ["released", false], ["lambda", _lambda], ["lane", _lane]]
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
            if ((_x get "interceptKey") isNotEqualTo _key) then {
                _x set ["hold", 0];
                if !([_x, "intercept", _key, "", [], _role get "lambda"] call fnc_opcom_task) then { _x set ["boundTo", -1] };
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
    ["INFO", "OPCOM", format ["attack %1 (%2 %3) %4%5", _attack get "id", _attack get "kind", _attack get "label", _outcome,
        ["", ", its creep unfired"] select ((_attack get "creep") isNotEqualTo [])]] call fnc_log;
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
// it first, and DUWS_fnc_opcom_converge releases it again onto the target.
DUWS_fnc_opcom_releaseRole = {
    params ["_attack", "_role"];
    _role set ["released", true];
    private _order = [["capture", _attack get "pos"], ["intercept", _attack get "target"]] select ((_attack get "kind") isEqualTo "qrf");
    if ((_role get "lane") isNotEqualTo []) then { _order = ["move", _role get "lane"] };
    {
        _x set ["hold", 0];
        if !(([_x] + _order + ["", [], _role get "lambda"]) call fnc_opcom_task) then { _x set ["boundTo", -1] };
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

// A bucket closes on the target once every unit of it stands on its lane out of contact. The engine's read of the fight,
// not belief, since only recon clears a sighting, and a stale one in the lane's cell would park the bucket until it
// expired. A virtual unit renders near any real BLUFOR, so one standing unrendered has no fight in its cell.
DUWS_fnc_opcom_converge = {
    params ["_attack"];
    {
        private _role = _x;
        if ((_role get "released") && {(_role get "lane") isNotEqualTo []}
            && {(([_attack, _role] call DUWS_fnc_opcom_roleUnits) findIf {
                ([_x] call DUWS_fnc_opcom_marching) || {(_x get "status") isEqualTo "engaged"}
            }) < 0}) then {
            _role set ["lane", []];
            [_attack, _role] call DUWS_fnc_opcom_releaseRole;
        };
    } forEach (_attack get "roles");
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
    private _qrf = (_attack get "kind") isEqualTo "qrf";
    if (_qrf && {!([_attack] call DUWS_fnc_opcom_qrfFollow)}) exitWith {
        [_attack, "dropped: the sighting is no longer believed"] call DUWS_fnc_opcom_attackClose;
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
        && {(_units findIf { [_x] call DUWS_fnc_opcom_marching }) < 0};
    if (_ready && {_r >= OPCOM_MUSTER_IDEAL}) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    if (DUWS_opcom_tick - (_attack get "since") < ([OPCOM_MUSTER_EXPIRY, OPCOM_QRF_EXPIRY] select _qrf)) exitWith {};
    if (_r >= OPCOM_MUSTER_MIN) exitWith { [_attack, _r] call DUWS_fnc_opcom_launch };
    [_attack, format ["abandoned at %1:1, short of the minimum", _r toFixed 2]] call DUWS_fnc_opcom_attackClose;
};

// A unit lost once the attack runs leaves the rest to finish it. A bucket still held waits at rest on its rally, so
// only the released ones say whether the attack is over, and one still on its lane has yet to close.
DUWS_fnc_opcom_executionStep = {
    params ["_attack"];
    {
        private _role = _x;
        _role set ["units", ([_attack, _role] call DUWS_fnc_opcom_roleUnits) apply { _x get "id" }];
    } forEach (_attack get "roles");
    private _roles = (_attack get "roles") select { (_x get "units") isNotEqualTo [] };
    _attack set ["roles", _roles];
    if (_roles isEqualTo []) exitWith { [_attack, "aborted: every unit was lost"] call DUWS_fnc_opcom_attackClose };
    if ((_attack get "kind") isEqualTo "qrf") then {
        [_attack] call DUWS_fnc_opcom_qrfRekey;
        // Following the lead keeps the next QRF off the same cluster.
        [_attack] call DUWS_fnc_opcom_qrfFollow;
    };
    [_attack] call DUWS_fnc_opcom_releaseHeld;
    [_attack] call DUWS_fnc_opcom_converge;
    if ((_attack get "creep") isNotEqualTo []) then { [_attack] call DUWS_fnc_opcom_creepStep };
    private _busy = _roles findIf {
        (_x get "released") && {(_x get "lane") isNotEqualTo []
            || {(([_attack, _x] call DUWS_fnc_opcom_roleUnits) findIf { [_x] call DUWS_fnc_opcom_marching }) >= 0}}
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
