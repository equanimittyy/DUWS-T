// Locality: server, [] call'd at load. The manoeuvres an Attack commits as (opcom_plan.md §Release): the roles each
// binds, where each stages and what releases it. A manoeuvre is data, so a new one adds no tasking code.
if (!isServer) exitWith {};

// manoeuvre -> [[role, bearings, slots, required slots, released by, wide, lambda], ...]. A role stages on the first
// bearing, in degrees off the one the attack comes from, whose rally is dry, one cell a slot. "" releases it at launch;
// a role name releases it once that role's unit reads engaged, since an envelopment arriving before the defenders are
// committed to the front is worth nothing. A wide role stages at least OPCOM_ENVELOP_K cells out. Lambda bends its
// march around believed BLUFOR (fnc_opcom_task): an enveloping role is worth only what it reaches unseen, where the
// fight is the point of the fix's march.
DUWS_opcom_manoeuvres = createHashMapFromArray [
    ["assault", [["attacker", [0], OPCOM_ASSAULT_ROLES, 1, "", false, 0]]],
    ["flank", [["fix", [0], 1, 1, "", false, 0], ["maneuver", [90, -90], 2, 1, "fix", false, 1]]],
    ["encircle", [["fix", [0], 1, 1, "", false, 0], ["rear", [180], 2, 1, "fix", true, 1]]]
];

// -> [[role, rally, required, released by, lambda], ...], one a slot, or [] when a role finds no dry rally. An assault
// stages where it stands instead, since it has no geometry to lose.
DUWS_fnc_opcom_manoeuvreRoles = {
    params ["_name", "_at", "_bearing"];
    private _out = [];
    private _ok = true;
    {
        _x params ["_role", "_bearings", "_slots", "_required", "_release", "_wide", "_lambda"];
        private _k = [OPCOM_RALLY_K, OPCOM_ENVELOP_K] select _wide;
        private _dir = _bearing;
        private _rally = [];
        {
            _dir = _bearing + _x;
            _rally = [_at, _dir, _k] call DUWS_fnc_opcom_rallyAt;
            if (_rally isNotEqualTo []) exitWith {};
        } forEach (_bearings call BIS_fnc_arrayShuffle);
        if (_rally isEqualTo [] && {_name isNotEqualTo "assault"}) exitWith { _ok = false };
        for "_n" from 0 to (_slots - 1) do {
            // Each slot past the first steps a cell aside, alternating sides, so the frontage widens a cell a slot.
            private _p = _rally;
            if (_n > 0 && {_rally isNotEqualTo []}) then {
                private _q = [[_rally getPos [OPCOM_GRID_CELL * ceil (_n / 2), _dir + ([90, -90] select (_n mod 2 == 0))]]
                    call DUWS_fnc_opcom_w2c] call DUWS_fnc_opcom_c2w;
                if (!(surfaceIsWater _q) && {([_at, _q] call DUWS_fnc_opcom_cellDist) >= _k}) then { _p = _q };
            };
            _out pushBack [_role, _p, _n < _required, _release, _lambda];
        };
    } forEach (DUWS_opcom_manoeuvres get _name);
    [[], _out] select _ok
};

// -> [manoeuvre, roles], picked once at commit. _r is the odds' ratio with the first unit sent; the survivors weigh
// alike until the archetype leans between them.
DUWS_fnc_opcom_manoeuvrePick = {
    params ["_r", "_at", "_bearing"];
    private _options = [];
    {
        private _roles = [_x, _at, _bearing] call DUWS_fnc_opcom_manoeuvreRoles;
        if (_roles isNotEqualTo []) then { _options pushBack [_x, _roles] };
    } forEach ([["assault"], ["assault", "flank", "encircle"]] select (_r < OPCOM_BAND_CRUSH));
    selectRandom _options
};

// A held role goes in once the role it waits on reads engaged, or is lost, since then the fight is on.
DUWS_fnc_opcom_releaseHeld = {
    params ["_intent"];
    private _roles = _intent get "roles";
    {
        private _role = _x;
        if !(_role get "released") then {
            private _i = _roles findIf { (_x get "role") isEqualTo (_role get "release") };
            private _by = if (_i < 0) then { nil } else { [_intent, _roles select _i] call DUWS_fnc_opcom_roleUnit };
            if (isNil "_by" || {(_by get "status") isEqualTo "engaged"}) then { [_intent, _role] call DUWS_fnc_opcom_releaseRole };
        };
    } forEach _roles;
};
