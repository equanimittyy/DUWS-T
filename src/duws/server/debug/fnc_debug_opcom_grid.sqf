// Locality: server -- remoteExec'd to 2 by fnc_debug_opcom_view. Reads the server-local threat grid, belief
// store and tasking store (no client sees them) and hands the whole drawable back to the requesting client,
// the way fnc_debug_aoi_circles answers for the AoI reaches. Every cell is emitted, not just those carrying
// force, so the client can paint the full-map lattice.
if (!isServer) exitWith {};
params ["_requester"];
if (isNil "DUWS_opcom_grid_w") exitWith {
    ["DEBUG", "OPCOM", "overlay gather: grid not built yet, nothing sent"] call fnc_log;
};

private _w = DUWS_opcom_grid_w;
private _cell = OPCOM_GRID_CELL;
private _fri = DUWS_opcom_grid_fri;
private _ene = DUWS_opcom_grid_ene;
private _land = DUWS_opcom_grid_land;
private _eps = 0.05;

// [centre, fri, ene, isFront, isLand] per cell, only for the play box (the rest of the lattice is never
// built). Front = the balance's sign differs from an orthogonal neighbour's: the zero-crossing band between
// friendly and enemy ground.
(missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_bMinCx", "_bMinCy", "_bMaxCx", "_bMaxCy"];
private _cells = [];
for "_iy" from _bMinCy to _bMaxCy do {
    for "_ix" from _bMinCx to _bMaxCx do {
        private _i = _iy * _w + _ix;
        private _f = _fri select _i;
        private _e = _ene select _i;
        private _bal = _f - _e;
        private _front = false;
        if (abs _bal > _eps) then {
            {
                _x params ["_dx", "_dy"];
                private _nx = _ix + _dx;
                private _ny = _iy + _dy;
                if (_nx >= _bMinCx && {_nx <= _bMaxCx} && {_ny >= _bMinCy} && {_ny <= _bMaxCy}) then {
                    private _nbal = (_fri select (_ny * _w + _nx)) - (_ene select (_ny * _w + _nx));
                    if (_nbal * _bal < 0) then { _front = true };
                };
            } forEach [[1, 0], [-1, 0], [0, 1], [0, -1]];
        };
        _cells pushBack [[(_ix + 0.5) * _cell, (_iy + 0.5) * _cell], _f, _e, _front, _land select _i];
    };
};

// Belief stamps: position, age in ticks, and the stamped threat (headcount with humans weighted).
private _bel = [];
{
    _bel pushBack [_x, DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex), DUWS_opcom_belief_str select _forEachIndex];
} forEach DUWS_opcom_belief_pos;

// Taskings -> [pos, OPFOR box icon, "KIND-ID:ORDER" tag]. KIND is the recruit-menu row (RECON_HELI, TRANS_HELI,
// RIFLES...), so rows sharing a comp token (recon_heli/trans_heli both build ["transheli"]) still read apart;
// the icon still gives the domain silhouette. ID is the tasking id, keeping two of one kind apart. [*] = a live
// unit (pos frozen at its de-virt cell); trailing [F] = carrying a rider, [R] = riding a lift or waiting at a shore for one.
private _tasks = [];
{
    private _mt = _x get "moveType";
    private _icon = switch (_mt) do {
        case "tracked": {"o_armor"}; case "wheeled": {"o_motor_inf"};
        case "boat": {"o_naval"}; case "rotary": {"o_air"}; case "fixed": {"o_air"};
        default {"o_inf"};
    };
    private _tok = toUpper (_x getOrDefault ["menu", [(_x get "comp") param [0, ""]] call DUWS_fnc_tokenName]);
    private _code = format ["%1-%2", _tok, _x get "id"];
    private _flag = switch (true) do {
        case ((_x get "carrying") >= 0): {" [F]"};
        case ((_x get "ridingOn") >= 0 || {(_x getOrDefault ["strandTicks", 0]) > 0}): {" [R]"};
        default {""};
    };
    private _tag = format ["%1%2:%3%4", ["", "[*]"] select ((_x get "grp") isNotEqualTo ""), _code, toUpper (_x get "order"), _flag];
    private _p = _x get "pos";
    _tasks pushBack [[_p select 0, _p select 1], _icon, _tag];
} forEach (missionNamespace getVariable ["DUWS_opcom_taskings", []]);

["DEBUG", "OPCOM", format ["overlay gather: %1 cells, %2 belief, %3 taskings -> %4", count _cells, count _bel, count _tasks, _requester]] call fnc_log;

// Cell size travels in the payload: OPCOM_GRID_CELL is a server-only global, nil on the drawing client.
[_cells, _bel, _cell, _tasks] remoteExec ["fnc_debug_opcom_grid_draw", _requester];
