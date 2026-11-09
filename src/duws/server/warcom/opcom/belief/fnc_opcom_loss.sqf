// Locality: server, [] call'd at load. OPFOR's recent losses, one row per kill: the cell it died in, the BLUFOR group
// that killed it and its force, halving every OPCOM_LOSS_HALFLIFE. A QRF's Value reads the kills in its block or by its
// cluster's groups, so OPFOR stops feeding a fight it keeps losing, and the group that won it carries the record when
// it moves on (opcom_plan.md §QRF). One row per kill rather than a ledger per cell and another per group, so a kill
// that is on both counts once. OPFOR's only: BLUFOR's commander hires nothing, so its QRFs cannot chain past the task
// forces it holds.
if (!isServer) exitWith {};

// side group, since a dead unit's side reads civilian (arma_engine_gotchas.md). A hull counts on top of its crew, who
// count as men. A killhouse body is a drill the player can repeat, which would hold QRFs off the base's edge. A kill
// with no instigator names the hull, whose group is unreliable, so the credit goes to its commander's. Rows go in tick
// order, so the oldest drop off the front: past five half-lives a kill weighs under a thirtieth of itself.
DUWS_fnc_opcom_lossKilled = {
    params ["_killed", "_killer", "_instigator"];
    if (_killed getVariable ["killhouse_enemy", false]) exitWith {};
    private _force = 0;
    if (_killed isKindOf "CAManBase") then {
        if (side group _killed == east) then { _force = 1 };
    } else {
        if (((crew _killed) findIf { side group _x == east }) >= 0) then { _force = [typeOf _killed] call DUWS_fnc_classPower };
    };
    if (_force <= 0) exitWith {};
    private _by = [_instigator, _killer] select (isNull _instigator);
    if !(_by isKindOf "CAManBase") then { _by = effectiveCommander _by };
    private _key = ["", netId group _by] select (side group _by == west);
    private _losses = (DUWS_opcom_cmds get "OPF") get "losses";
    while { _losses isNotEqualTo [] && {DUWS_opcom_tick - ((_losses select 0) select 3) > 5 * OPCOM_LOSS_HALFLIFE} } do {
        _losses deleteAt 0;
    };
    _losses pushBack [[getPosATL _killed] call DUWS_fnc_opcom_w2c, _key, _force, DUWS_opcom_tick];
};

// -> the OPFOR force killed in one of _cells or by a group _keys names, each kill once, decayed.
DUWS_fnc_opcom_lossFor = {
    params ["_cells", "_keys"];
    private _sum = 0;
    {
        _x params ["_c", "_key", "_f", "_tick"];
        if (_c in _cells || {_key in _keys}) then { _sum = _sum + _f * 0.5 ^ ((DUWS_opcom_tick - _tick) / OPCOM_LOSS_HALFLIFE) };
    } forEach (_cmd get "losses");
    _sum
};
