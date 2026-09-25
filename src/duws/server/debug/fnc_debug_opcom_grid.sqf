// Locality: server -- remoteExec'd to 2 by fnc_debug_opcom_view. Reads the server-local threat grid, belief
// store and tasking store (no client sees them) and hands the whole drawable back to the requesting client,
// the way fnc_debug_aoi_circles answers for the AoI reaches. Every cell is emitted, not just those carrying
// force, so the client can paint the full-map lattice.
if (!isServer) exitWith {};
params ["_requester", ["_forceOn", false], ["_staleOn", false], ["_needOn", false]];

// The zone-port map is OPCOM init's last store, so its presence means every store below is built.
if (isNil "DUWS_opcom_zonePort") exitWith {
    ["DEBUG", "OPCOM", "overlay gather: OPCOM init not finished, nothing sent"] call fnc_log;
};

private _w = DUWS_opcom_grid_w;
private _cell = OPCOM_GRID_CELL;
private _fri = DUWS_opcom_grid_fri;
private _ene = DUWS_opcom_grid_ene;
private _land = DUWS_opcom_grid_land;
private _seen = DUWS_opcom_grid_seen;
private _tick = DUWS_opcom_tick;
private _eps = 0.05;

// [centre, fri, ene, isFront, isLand, coverAge] per cell, only for the play box (the rest of the lattice is
// never built). Front = the balance's sign differs from an orthogonal neighbour's: the zero-crossing band
// between friendly and enemy ground. A layer the requester hides is not read: its fields go as no force and age -1,
// which draw nothing, and need, cover and traffic are left off the row.
DUWS_opcom_box params ["_bMinCx", "_bMinCy", "_bMaxCx", "_bMaxCy"];
private _cells = [];
for "_iy" from _bMinCy to _bMaxCy do {
    for "_ix" from _bMinCx to _bMaxCx do {
        private _i = _iy * _w + _ix;
        private _f = 0;
        private _e = 0;
        private _front = false;
        if (_forceOn) then {
            _f = _fri select _i;
            _e = _ene select _i;
            private _bal = _f - _e;
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
        };
        // Collapse to -1 past the span so never-seen and long-expired read alike and the client needs no span.
        private _age = -1;
        if (_staleOn) then {
            _age = _tick - (_seen select _i);
            if (_age >= OPCOM_COVER_SPAN) then { _age = -1 };
        };
        private _row = [[(_ix + 0.5) * _cell, (_iy + 0.5) * _cell], _f, _e, _front, _land select _i, _age];
        if (_needOn) then {
            _row append [[_i] call DUWS_fnc_opcom_needAt, [_i] call DUWS_fnc_opcom_coverAt, [_i] call DUWS_fnc_opcom_trafficAt];
        };
        _cells pushBack _row;
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
private _wps = [];
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
    // What lands on arrival, in the tag and again on the endpoint: the order alone never says whether a MOVE
    // ends in a garrison, a build or a delivery.
    private _errand = _x getOrDefault ["errand", []];
    private _intent = switch (true) do {
        case (_errand isNotEqualTo []): {
            private _kind = toUpper (_errand select 0);
            switch (_kind) do {
                case "BUILD": {format ["BUILD %1", _errand param [2, "?"]]};
                case "MINE": {format ["MINE %1", (_errand param [2, []]) param [0, "?"]]};
                default {format ["%1 t%2", _kind, _errand param [1, "?"]]};
            };
        };
        case ((_x getOrDefault ["returnZone", ""]) isNotEqualTo ""): {format ["GARRISON %1", _x get "returnZone"]};
        case ((_x getOrDefault ["targetZone", ""]) isNotEqualTo ""): {format ["TAKE %1", _x get "targetZone"]};
        case ((_x getOrDefault ["interceptKey", ""]) isNotEqualTo ""): {format ["HUNT %1", _x get "interceptKey"]};
        case ((_x get "order") isEqualTo "guard"): {"HOLD"};
        default {""};
    };
    private _tag = format ["%1%2:%3%4%5", ["", "[*]"] select ((_x get "grp") isNotEqualTo ""), _code,
        toUpper (_x get "order"), ["", " " + _intent] select (_intent isNotEqualTo ""), _flag];
    private _p = _x get "pos";
    _tasks pushBack [[_p select 0, _p select 1], _icon, _tag];
    private _route = _x get "route";
    private _leg = _x get "leg";
    if (_leg < count _route) then {
        private _rp = _route select (count _route - 1);
        _wps pushBack [[_rp select 0, _rp select 1], [_code, format ["%1 %2", _code, _intent]] select (_intent isNotEqualTo "")];
    };
} forEach (missionNamespace getVariable ["DUWS_opcom_taskings", []]);

["DEBUG", "OPCOM", format ["overlay gather: %1 cells, %2 belief, %3 taskings, %4 waypoints -> %5", count _cells, count _bel, count _tasks, count _wps, _requester]] call fnc_log;

// Cell size travels in the payload: OPCOM_GRID_CELL is a server-only global, nil on the drawing client.
[_cells, _bel, _cell, _tasks, _wps] remoteExec ["fnc_debug_opcom_grid_draw", _requester];
