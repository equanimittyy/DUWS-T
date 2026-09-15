// Locality: server. Builds the tasking store and its data tables once at init. Server-local, never broadcast --
// OPCOM orders only server-local groups. A tasking is a field-keyed hashMap of numbers/strings/arrays only, so a
// record stays serialisable and holds no object handle: `grp` is a live group's netId, resolved with
// groupFromNetId, never the handle (docs/info/architecture/arma_engine_gotchas.md). `pos` is the world point the
// grid samples force at, never a cell the tasking is bound to.
if (!isServer) exitWith {};

DUWS_opcom_taskings = [];
DUWS_opcom_taskSeq  = 0;

// The one buyable-unit table (docs/plans/opcom/opcom_plan.md): row -> [composition, flags]. Bare tokens resolve
// to the "none" posture, so the unit takes OPCOM's order, not a standing circuit. No price column -- a hire costs
// ceil(force * OPCOM_AP_PER_FORCE). `noncombat` keeps a row out of the garrison reserve wave (never spawns to
// defend, dies with a captured zone) regardless of armament -- a boat is armed; a separate axis from `transport`.
DUWS_opcom_recruitMenu = createHashMapFromArray [
    ["rifles",       [["squad"],     []]],
    ["weapons_team", [["wp_team"],   []]],
    ["apc",          [["apc"],       ["transport"]]],
    ["ifv",          [["ifv"],       ["transport"]]],
    ["mbt",          [["tank"],       []]],
    ["attack_heli",  [["attackheli"], []]],
    ["recon_foot",   [["recon"],      ["recon"]]],
    ["recon_car",    [["car"],       ["recon"]]],
    ["recon_heli",   [["transheli"], ["recon", "noncombat"]]],
    ["truck",        [["truck"],     ["supply", "transport", "noncombat"]]],
    ["trans_heli",   [["transheli"], ["transport", "noncombat"]]],
    ["boat",         [["boat"],      ["transport", "noncombat"]]]
];

// Composition's first token -> movement type; a token absent here defaults to "inf".
DUWS_opcom_moveType = createHashMapFromArray [
    ["squad", "inf"], ["wp_team", "inf"], ["recon", "inf"], ["team", "inf"],
    ["patrol", "inf"], ["sniper_element", "inf"], ["garrison_element", "inf"],
    ["car", "wheeled"], ["at_car", "wheeled"], ["aa_car", "wheeled"], ["truck", "wheeled"],
    ["transport", "wheeled"], ["ammo", "wheeled"], ["repair", "wheeled"],
    ["apc", "tracked"], ["ifv", "tracked"], ["tank", "tracked"], ["aa", "tracked"],
    ["transheli", "rotary"], ["attackheli", "rotary"],
    ["plane", "fixed"],
    ["boat", "boat"]
];

// Ticks to cross one grid cell, gameplay-tuned not realistic (the ~80x real spread compressed).
DUWS_opcom_speed = createHashMapFromArray [
    ["inf", 15], ["wheeled", 4], ["tracked", 8], ["rotary", 2], ["fixed", 0.5], ["boat", 4]
];

// Streaming reach in cells (Chebyshev): de-virt within K of a player. Wider for faster types so a spawn beats contact.
DUWS_opcom_streamK = createHashMapFromArray [
    ["inf", 1], ["wheeled", 2], ["tracked", 2], ["rotary", 3], ["fixed", 4], ["boat", 2]
];

DUWS_opcom_moveWater = createHashMapFromArray [
    ["inf", "land"], ["wheeled", "land"], ["tracked", "land"],
    ["rotary", "air"], ["fixed", "air"], ["boat", "water"]
];

DUWS_fnc_opcom_moveType = {
    params ["_comp"];
    DUWS_opcom_moveType getOrDefault [[_comp param [0, ""]] call DUWS_fnc_tokenName, "inf"]
};

DUWS_fnc_opcom_w2c = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    // Clamp to the play box: a point outside it resolves to the nearest edge cell, keeping routed/streamed cells inside.
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _cx = (floor ((_pos select 0) / OPCOM_GRID_CELL)) max _minCx min _maxCx;
    private _cy = (floor ((_pos select 1) / OPCOM_GRID_CELL)) max _minCy min _maxCy;
    _cy * _w + _cx
};

DUWS_fnc_opcom_c2w = {
    params ["_ci"];
    private _w = DUWS_opcom_grid_w;
    [((_ci mod _w) + 0.5) * OPCOM_GRID_CELL, ((floor (_ci / _w)) + 0.5) * OPCOM_GRID_CELL, 0]
};

// A tasking record by id, or nil (the ferry binds transport<->rider by id, not handle).
DUWS_fnc_opcom_byId = {
    params ["_id"];
    private _i = DUWS_opcom_taskings findIf { (_x get "id") == _id };
    if (_i < 0) exitWith { nil };
    DUWS_opcom_taskings select _i
};

// Nearest navigable-water cell centre -- a boat's launch point (it cannot rest on the land zone that raised it).
DUWS_fnc_opcom_nearestWater = {
    params ["_pos"];
    private _best = _pos;
    private _bd = 1e12;
    {
        if (_x >= 0) then {
            private _c = [_forEachIndex] call DUWS_fnc_opcom_c2w;
            private _dd = _pos distance2D _c;
            if (_dd < _bd) then { _bd = _dd; _best = _c };
        };
    } forEach DUWS_opcom_grid_water;
    _best
};

// Ports: the water cell each coastal zone owns for its boats (recruit spawn point, garrison anchor).
// Zone key -> cell index, assigned once at tasking init from the router's own water mask: nearest
// navigable cell within 3 Chebyshev steps, contested cells to the nearer zone (ties by key), the loser
// falling to its nearest unclaimed land-adjacent cell. A zone with no entry refuses boats outright.
DUWS_fnc_opcom_portOf = {
    params ["_key"];
    DUWS_opcom_zonePort getOrDefault [_key, -1]
};

DUWS_fnc_opcom_ports_init = {
    DUWS_opcom_zonePort = createHashMap;
    private _w = DUWS_opcom_grid_w;
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];

    private _fnc_landAdj = {
        params ["_ni"];
        private _ix = _ni mod _w;
        private _iy = floor (_ni / _w);
        private _found = false;
        for "_dy" from -1 to 1 do {
            for "_dx" from -1 to 1 do {
                if (!_found && {_dx != 0 || _dy != 0}) then {
                    private _nx = _ix + _dx;
                    private _ny = _iy + _dy;
                    if (_nx >= _minCx && {_nx <= _maxCx} && {_ny >= _minCy} && {_ny <= _maxCy}) then {
                        _found = DUWS_opcom_grid_land select (_ny * _w + _nx);
                    };
                };
            };
        };
        _found
    };

    private _cands = [];
    {
        if ((_x select [0, 5]) == "zone_") then {
            private _zpos = ([_x] call fnc_site_at) getOrDefault ["pos", []];
            if (_zpos isNotEqualTo []) then {
                private _ci = [_zpos] call DUWS_fnc_opcom_w2c;
                private _cx = _ci mod _w;
                private _cy = floor (_ci / _w);
                private _list = [];
                for "_dy" from -3 to 3 do {
                    for "_dx" from -3 to 3 do {
                        private _nx = _cx + _dx;
                        private _ny = _cy + _dy;
                        if (_nx >= _minCx && {_nx <= _maxCx} && {_ny >= _minCy} && {_ny <= _maxCy}) then {
                            private _ni = _ny * _w + _nx;
                            if ((DUWS_opcom_grid_water select _ni) >= 0) then {
                                _list pushBack [_zpos distance2D ([_ni] call DUWS_fnc_opcom_c2w), _ni];
                            };
                        };
                    };
                };
                if (_list isNotEqualTo []) then {
                    _list sort true;
                    _cands pushBack [_list select 0 select 0, _x, _list];
                };
            };
        };
    } forEach keys DUWS_sites;

    // Nearest-paired zones claim first, so a contested cell keeps its closest zone.
    _cands sort true;

    private _claimed = createHashMap;
    {
        _x params ["_bestD", "_key", "_list"];
        private _done = false;
        {
            private _ni = _x select 1;
            if (!_done && {!(_claimed getOrDefault [_ni, false])}) then {
                // A zone's own nearest cell needs no land check; a fallback must reach land.
                if (_forEachIndex == 0 || { [_ni] call _fnc_landAdj }) then {
                    DUWS_opcom_zonePort set [_key, _ni];
                    _claimed set [_ni, true];
                    _done = true;
                };
            };
        } forEach _list;
    } forEach _cands;
};

call DUWS_fnc_opcom_ports_init;
