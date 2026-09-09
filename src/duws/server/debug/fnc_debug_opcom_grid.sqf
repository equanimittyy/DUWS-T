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

// [centre, fri, ene, isFront, isLand] per cell. Front = the balance's sign differs from an orthogonal
// neighbour's: the zero-crossing band between friendly and enemy ground.
private _cells = [];
for "_i" from 0 to (_w * _w - 1) do {
    private _f = _fri select _i;
    private _e = _ene select _i;
    private _ix = _i mod _w;
    private _iy = floor (_i / _w);
    private _bal = _f - _e;
    private _front = false;
    if (abs _bal > _eps) then {
        {
            _x params ["_dx", "_dy"];
            private _nx = _ix + _dx;
            private _ny = _iy + _dy;
            if (_nx >= 0 && {_nx < _w} && {_ny >= 0} && {_ny < _w}) then {
                private _nbal = (_fri select (_ny * _w + _nx)) - (_ene select (_ny * _w + _nx));
                if (_nbal * _bal < 0) then { _front = true };
            };
        } forEach [[1, 0], [-1, 0], [0, 1], [0, -1]];
    };
    _cells pushBack [[(_ix + 0.5) * _cell, (_iy + 0.5) * _cell], _f, _e, _front, _land select _i];
};

// Belief stamps: position, age in ticks, and the stamped threat (headcount with humans weighted).
private _bel = [];
{
    _bel pushBack [_x, DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex), DUWS_opcom_belief_str select _forEachIndex];
} forEach DUWS_opcom_belief_pos;

// Taskings -> [pos, OPFOR box icon, "CODE:ORDER" tag]. Label is derived, not a stored order: FERRY while
// carrying a rider, RIDING while carried. A [*] prefix marks a live unit (pos frozen at its de-virt point).
private _tasks = [];
{
    private _mt = _x get "moveType";
    private _icon = switch (_mt) do {
        case "tracked": {"o_armor"}; case "wheeled": {"o_motor_inf"};
        case "boat": {"o_naval"}; case "rotary": {"o_air"}; case "fixed": {"o_air"};
        default {"o_inf"};
    };
    private _code = switch (_mt) do {
        case "tracked": {"ARM"}; case "wheeled": {"MOT"};
        case "boat": {"BOAT"}; case "rotary": {"HELI"}; case "fixed": {"JET"};
        default {"INF"};
    };
    if ("transport" in (_x get "flags")) then { _code = "T" + _code };
    private _label = switch (true) do {
        case ((_x get "carrying") >= 0): {"FERRY"};
        case ((_x get "ridingOn") >= 0): {"RIDING"};
        default { toUpper (_x get "order") };
    };
    private _tag = format ["%1%2:%3", ["", "[*]"] select ((_x get "grp") isNotEqualTo ""), _code, _label];
    private _p = _x get "pos";
    _tasks pushBack [[_p select 0, _p select 1], _icon, _tag];
} forEach (missionNamespace getVariable ["DUWS_opcom_taskings", []]);

["DEBUG", "OPCOM", format ["overlay gather: %1 cells, %2 belief, %3 taskings -> %4", count _cells, count _bel, count _tasks, _requester]] call fnc_log;

// Cell size travels in the payload: OPCOM_GRID_CELL is a server-only global, nil on the drawing client.
[_cells, _bel, _cell, _tasks] remoteExec ["fnc_debug_opcom_grid_draw", _requester];
