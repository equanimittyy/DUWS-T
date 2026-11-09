// Locality: server, [] call'd at load. The loss layer: the OPFOR force killed in each cell, halving every
// OPCOM_LOSS_HALFLIFE. A QRF's Value reads it, so OPFOR stops feeding a fight it keeps losing (opcom_plan.md §QRF).
// Decayed lazily on read, never in a per-cell sweep. OPFOR's only: BLUFOR's commander hires nothing, so its QRFs
// cannot chain past the task forces it holds.
if (!isServer) exitWith {};

// side group, since a dead unit's side reads civilian (arma_engine_gotchas.md). A hull counts on top of its crew, who
// count as men. A killhouse body is a drill the player can repeat, which would hold QRFs off the base's edge.
DUWS_fnc_opcom_lossKilled = {
    params ["_killed"];
    if (_killed getVariable ["killhouse_enemy", false]) exitWith {};
    private _force = 0;
    if (_killed isKindOf "CAManBase") then {
        if (side group _killed == east) then { _force = 1 };
    } else {
        if (((crew _killed) findIf { side group _x == east }) >= 0) then { _force = [typeOf _killed] call DUWS_fnc_classPower };
    };
    if (_force <= 0) exitWith {};
    private _cmd = DUWS_opcom_cmds get "OPF";
    private _c = [getPosATL _killed] call DUWS_fnc_opcom_w2c;
    (_cmd get "grid_loss") set [_c, ([_c] call DUWS_fnc_opcom_lossAt) + _force];
    (_cmd get "grid_lossTick") set [_c, DUWS_opcom_tick];
};

DUWS_fnc_opcom_lossAt = {
    params ["_c"];
    ((_cmd get "grid_loss") select _c) * 0.5 ^ ((DUWS_opcom_tick - ((_cmd get "grid_lossTick") select _c)) / OPCOM_LOSS_HALFLIFE)
};
