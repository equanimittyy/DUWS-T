// Locality: server. Builds the tasking store and its data tables once at OPCOM init. Server-local, never
// broadcast -- OPCOM orders only server-local groups. Read by fnc_opcom_task_step.
//
// A tasking is a hashMap keyed by field name, values kept to numbers/strings/arrays so a record stays
// serialisable and holds no object handle: `grp` is a live group's netId string (resolved with
// groupFromNetId), never the handle (docs/info/architecture/arma_engine_gotchas.md). Fields: id;
// order (assault/scout/supply/move/guard/garrison); target [x,y]; pos (world point the grid reads force at,
// never the reverse); moveType; comp (bare tokens); flags; fullForce; effForce (what the grid deposits);
// route; leg; routeMode; status; grp; hold (earliest tick to re-issue the order); homeZone.
if (!isServer) exitWith {};

DUWS_opcom_taskings = [];
DUWS_opcom_taskSeq  = 0;

// The one place a buyable unit is priced and flagged (docs/plans/opcom/opcom_plan.md). Row -> [composition,
// flags]. Bare tokens resolve to the "none" posture, so the unit takes OPCOM's order, not a standing
// circuit. No price column: a hire costs ceil(force * OPCOM_AP_PER_FORCE), so no price can drift from worth.
DUWS_opcom_recruitMenu = createHashMapFromArray [
    ["rifles",       [["squad"],     []]],
    ["weapons_team", [["wp_team"],   []]],
    ["apc",          [["apc"],       ["transport"]]],
    ["ifv",          [["ifv"],       ["transport"]]],
    ["mbt",          [["tank"],       []]],
    ["attack_heli",  [["attackheli"], []]],
    ["recon_foot",   [["recon"],      ["recon"]]],
    ["recon_car",    [["car"],       ["recon"]]],
    ["recon_heli",   [["transheli"], ["recon"]]],
    ["truck",        [["truck"],     ["supply", "transport"]]],
    ["trans_heli",   [["transheli"], ["transport"]]],
    ["boat",         [["boat"],      ["transport"]]]
];

// Composition token -> movement type. The first token of a composition decides (P3 rows are single-token).
// A token absent here defaults to "inf" -- the safe floor, since only ground types are gated to land.
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

// Per-type speed as ticks to cross one grid cell -- gameplay-tuned, not realistic: the true spread (a jet
// outruns a foot soldier ~80x) is compressed so the virtual layer neither crawls nor teleports.
DUWS_opcom_speed = createHashMapFromArray [
    ["inf", 30], ["wheeled", 15], ["tracked", 20], ["rotary", 5], ["fixed", 2], ["boat", 10]
];

// Per-type streaming reach in cells (Chebyshev): a tasking de-virtualises when its cell closes within K of
// any player's cell. Wider for faster types so a spawn still beats contact at the fixed tick rate.
DUWS_opcom_streamK = createHashMapFromArray [
    ["inf", 1], ["wheeled", 2], ["tracked", 2], ["rotary", 4], ["fixed", 8], ["boat", 2]
];

// Per-type water rule for routing: "land" routes over land cells only (water impassable), "air" treats
// every cell passable, "water" is the mirror -- water only, land impassable.
DUWS_opcom_moveWater = createHashMapFromArray [
    ["inf", "land"], ["wheeled", "land"], ["tracked", "land"],
    ["rotary", "air"], ["fixed", "air"], ["boat", "water"]
];

// Grid<->world helpers. A tasking's position is a world point the grid only samples, never a bound cell, so
// both directions convert on demand.
DUWS_fnc_opcom_moveType = {
    params ["_comp"];
    DUWS_opcom_moveType getOrDefault [[_comp param [0, ""]] call DUWS_fnc_tokenName, "inf"]
};

DUWS_fnc_opcom_w2c = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    private _cx = (floor ((_pos select 0) / OPCOM_GRID_CELL)) max 0 min (_w - 1);
    private _cy = (floor ((_pos select 1) / OPCOM_GRID_CELL)) max 0 min (_w - 1);
    _cy * _w + _cx
};

DUWS_fnc_opcom_c2w = {
    params ["_ci"];
    private _w = DUWS_opcom_grid_w;
    [((_ci mod _w) + 0.5) * OPCOM_GRID_CELL, ((floor (_ci / _w)) + 0.5) * OPCOM_GRID_CELL, 0]
};

// A tasking record by id, or nil. The ferry binds a transport to a rider by id, not by handle.
DUWS_fnc_opcom_byId = {
    params ["_id"];
    private _i = DUWS_opcom_taskings findIf { (_x get "id") == _id };
    if (_i < 0) exitWith { nil };
    DUWS_opcom_taskings select _i
};

// Nearest navigable-water cell centre to a world point -- a boat's launch point, since it cannot rest on the
// land zone that raised it. Falls back to the point itself on a landlocked map (which fields no boats anyway).
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
