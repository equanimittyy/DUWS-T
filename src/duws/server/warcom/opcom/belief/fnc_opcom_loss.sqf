// Locality: server, [] call'd at load. OPFOR's recent losses, one row per kill: the cell it died in, the BLUFOR group
// that killed it and its force, halving every OPCOM_LOSS_HALFLIFE. A QRF's rest reads the kills in its block or by its
// cluster's groups, so OPFOR stops feeding a fight it keeps losing, and the group that won it carries the record when
// it moves on (opcom.md §QRF). One row per kill rather than a ledger per cell and another per group, so a kill
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

// -> true while the cluster on _cells and _keys rests: from when its loss reaches OPCOM_QRF_RELAX_AT until the rest's
// own loss decays to OPCOM_QRF_LOSS_FREE. Two marks, not one: at a single mark a wave comes back as fast as the loss
// decays below it, so the fight never pauses. A rest overlapping the cluster's ground or groups holds it, so it keeps
// the fight's ground from a new group and follows the winners when they move. High-to-low: a forward deleteAt skips a
// row.
DUWS_fnc_opcom_qrfRelaxing = {
    params ["_cells", "_keys"];
    private _relax = _cmd get "qrfRelax";
    for "_i" from (count _relax - 1) to 0 step -1 do {
        if (((_relax select _i) call DUWS_fnc_opcom_lossFor) <= OPCOM_QRF_LOSS_FREE) then { _relax deleteAt _i };
    };
    if ((_relax findIf {
        _x params ["_rc", "_rk"];
        (_cells findIf { _x in _rc }) >= 0 || {(_keys findIf { _x in _rk }) >= 0}
    }) >= 0) exitWith { true };
    if (([_cells, _keys] call DUWS_fnc_opcom_lossFor) < OPCOM_QRF_RELAX_AT) exitWith { false };
    _relax pushBack [_cells, _keys];
    true
};
