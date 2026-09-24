// Locality: server, [] call'd at load. What a hire is worth: the action it unblocks, the lift or stock it gives, and
// the defense it adds at the zone that raises it (opcom_plan.md §Value). The lift roles are fnc_opcom_demand_lift's.
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// A zone's garrison plus the combatants OPCOM has homed there, which the base ledger leaves out.
DUWS_fnc_opcom_zoneForcesSweep = {
    private _out = createHashMap;
    { _out set [_x select 0, [_x select 0] call DUWS_fnc_garrisonForce] } forEach (call DUWS_fnc_opcom_zonesOpen);
    {
        if ((_x get "order") isEqualTo "garrison" && {(_x get "status") isNotEqualTo "dead"}
            && {!("noncombat" in (_x get "flags"))}) then {
            private _hz = _x get "homeZone";
            private _cur = _out getOrDefault [_hz, -1];
            if (_cur >= 0) then { _out set [_hz, _cur + (_x get "effForce")] };
        };
    } forEach DUWS_opcom_taskings;
    _out
};

DUWS_fnc_opcom_zoneForce = {
    params ["_key"];
    (["zoneForces", DUWS_fnc_opcom_zoneForcesSweep] call DUWS_fnc_opcom_tickCached) getOrDefault [_key, 0]
};

DUWS_fnc_opcom_hireDefense = {
    params ["_worth", "_exposure", "_force", "_zoneForce"];
    _worth * _exposure * _force / ((_zoneForce + _force) max 1)
};

// Scored as if the hire already stood at each [position, Value], so OPCOM never hires for a fight it could not win.
DUWS_fnc_opcom_demandWin = {
    params ["_targets", "_force"];
    private _best = 0;
    private _at = [];
    {
        _x params ["_pos", "_v"];
        private _d = ([_pos, _force] call DUWS_fnc_opcom_pWinWith) * _v;
        if (_d > _best) then { _best = _d; _at = _pos };
    } forEach _targets;
    [_best, _at]
};

DUWS_fnc_opcom_demandCombat = {
    params ["_flags", "_force", "_moveType"];
    if ("noncombat" in _flags || {"recon" in _flags}) exitWith { [0, []] };
    // An Attack must stand in the zone to take it, so air fills no attacker's place.
    private _targets = if (_moveType in ["inf", "wheeled", "tracked"]) then { ["attackSweep"] call DUWS_fnc_opcom_commitBlocked } else { [] };
    [_targets + (["interceptSweep"] call DUWS_fnc_opcom_commitBlocked), _force] call DUWS_fnc_opcom_demandWin
};

DUWS_fnc_opcom_demandRecon = {
    params ["_flags", "_force", "_moveType", "_zones"];
    if !("recon" in _flags) exitWith { [0, []] };
    private _k = OPCOM_RECON_K getOrDefault [_moveType, 1];
    private _targets = [];
    {
        private _z = [_x, _zones] call DUWS_fnc_opcom_nearestOpen;
        if (_z isNotEqualTo []) then { _targets pushBack [_x, [_z select 2, _x, _k] call DUWS_fnc_opcom_patrolValue] };
    } forEach (["patrolSweep"] call DUWS_fnc_opcom_commitBlocked);
    [_targets, _force] call DUWS_fnc_opcom_demandWin
};

// An idle truck spares the next supply buy its hire. The saving splits across the trucks already idle, so the stock
// settles where the hire's score meets Bank's; it rests at a random open zone, since that buy's target is unknown.
DUWS_fnc_opcom_demandSupply = {
    params ["_flags", "", "", "_zones"];
    if !("supply" in _flags) exitWith { [0, []] };
    private _idle = { ((_x select 0) select 0) isEqualTo "truck" } count (call DUWS_fnc_opcom_truckSources);
    private _v = (OPCOM_AP_UNIT getOrDefault ["truck", 0]) / (_idle + 1);
    if (_v <= 0) exitWith { [0, []] };
    [_v, (selectRandom _zones) select 2]
};

// Each role reads [flags, force, moveType, zones, row] and answers [Value, the target's position], [0, []] where the
// hire serves nothing. On a tie the earlier role keeps the target.
DUWS_opcom_hireDemands = [
    DUWS_fnc_opcom_demandCombat,
    DUWS_fnc_opcom_demandRecon,
    DUWS_fnc_opcom_demandStrand,
    DUWS_fnc_opcom_demandTaxi,
    DUWS_fnc_opcom_demandSupply
];

DUWS_fnc_opcom_hireDemand = {
    private _best = [0, []];
    {
        private _d = _this call _x;
        if ((_d select 0) > (_best select 0)) then { _best = _d };
    } forEach DUWS_opcom_hireDemands;
    _best
};
