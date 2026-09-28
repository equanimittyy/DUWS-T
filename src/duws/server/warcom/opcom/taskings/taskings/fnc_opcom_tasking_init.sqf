// Locality: server. Builds the tasking store and its data tables once at init. Server-local, never broadcast --
// OPCOM orders only server-local groups. A tasking is a field-keyed hashMap of numbers/strings/arrays only, so a
// record stays serialisable and holds no object handle: `grp` is a live group's netId, resolved with
// groupFromNetId, never the handle (docs/info/architecture/arma_engine_gotchas.md). `pos` is the world point the
// grid samples force at, never a cell the tasking is bound to.
if (!isServer) exitWith {};

DUWS_opcom_taskings = [];
DUWS_opcom_taskSeq  = 0;
DUWS_opcom_attacks = [];
DUWS_opcom_attackSeq = 0;
// A tick, not a duration: DUWS_opcom_tick is saved.
DUWS_opcom_attackReadyTick = 0;
DUWS_opcom_rapportReadyTick = 0;
// Not saved: a load starts every battery ready.
DUWS_opcom_batteryReadyTick = createHashMap;

// The one buyable-unit table (docs/plans/opcom/opcom_plan.md): row -> [composition, flags]. Bare tokens resolve
// to the "none" posture, so the unit takes OPCOM's order, not a standing circuit. No price column -- OPCOM_AP_UNIT
// prices a row by its id. `noncombat` keeps a row out of the garrison reserve pool (never spawns to
// defend, dies with a captured zone) regardless of armament -- a boat is armed; a separate axis from `transport`.
// `transportable` lets a row ride a ferry lift: only men fit a cabin, so a hull drives its road route instead.
DUWS_opcom_recruitMenu = createHashMapFromArray [
    ["rifles",       [["squad"],     ["transportable"]]],
    ["weapons_team", [["wp_team"],   ["transportable"]]],
    ["car",          [["car"],       ["transport"]]],
    ["apc",          [["apc"],       ["transport"]]],
    ["ifv",          [["ifv"],       ["transport"]]],
    ["mbt",          [["tank"],       []]],
    ["attack_heli",  [["attackheli"], []]],
    ["jet",          [["plane"],      []]],
    ["recon_foot",   [["recon"],      ["recon", "transportable"]]],
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

// A tasking record by id, or nil (the ferry binds transport<->rider by id, not handle).
DUWS_fnc_opcom_byId = {
    params ["_id"];
    private _i = DUWS_opcom_taskings findIf { (_x get "id") == _id };
    if (_i < 0) exitWith { nil };
    DUWS_opcom_taskings select _i
};

// A resting unit an order may draw on -- never one an attack still binds, nor one garrisoned in a contested zone,
// which holds ground under assault.
DUWS_fnc_opcom_drawable = {
    params ["_t"];
    (_t get "order") in ["guard", "garrison"]
    && {(_t getOrDefault ["boundTo", -1]) < 0}
    && {(_t getOrDefault ["carrying", -1]) < 0}
    && {(_t getOrDefault ["status", ""]) isNotEqualTo "engaged"}
    && {!(((_t get "order") isEqualTo "garrison") && {[_t get "homeZone"] call DUWS_fnc_opcom_siteContested})}
};

// The complement of the two rests, never a list of names: an order added to the table is out on the ground by
// default rather than forgotten by its readers (fnc_debug_opcom_ai, fnc_intel_payout).
DUWS_fnc_opcom_marching = { params ["_t"]; !((_t get "order") in ["guard", "garrison"]) };

call DUWS_fnc_opcom_ports_init;
