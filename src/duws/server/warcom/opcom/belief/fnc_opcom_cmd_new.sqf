// Locality: server. -> a commander record from its side inputs (_inputs, [field, value] pairs), every store, layer and
// pick field in it empty. Built once per side at OPCOM init, after the grid it sizes its layers on. Server-local and
// never broadcast; the snapshot saves only the fields a load resumes (fnc_campaign_save.sqf).
params ["_inputs"];
private _cmd = createHashMapFromArray _inputs;
private _zero = DUWS_opcom_grid_land apply { 0 };

_cmd set ["belief_key", []];    // subject: an enemy group netId
_cmd set ["belief_pos", []];    // [x,y,0] as last observed, never a live lookup (the sense edge gate enforces it)
_cmd set ["belief_time", []];
_cmd set ["belief_str", []];

_cmd set ["grid_fri", +_zero];
_cmd set ["grid_ene", +_zero];
// Last-swept tick per cell, a full span in the past so an unswept cell reads max staleness via the same formula, no sentinel.
_cmd set ["grid_seen", _zero apply { -OPCOM_COVER_SPAN }];
_cmd set ["grid_traffic", +_zero];           // believed force last crossing, decayed on read
_cmd set ["grid_trafficTick", +_zero];
_cmd set ["gridStaticFri", +_zero];
_cmd set ["gridStaticEne", +_zero];
_cmd set ["gridSrc", createHashMap];
_cmd set ["gridAwake", createHashMap];
_cmd set ["gridDirty", createHashMap];
_cmd set ["gridDirtyAll", true];

_cmd set ["needStatic", +_zero];
_cmd set ["needBase", +_zero];
_cmd set ["bandCells", []];
_cmd set ["needCells", []];
_cmd set ["bandSig", []];
_cmd set ["depositSig", []];
_cmd set ["needBuilding", false];

_cmd set ["taskings", []];
_cmd set ["taskSeq", 0];
_cmd set ["attacks", []];
_cmd set ["attackSeq", 0];
// A tick, not a duration: DUWS_opcom_tick is saved.
_cmd set ["attackReadyTick", 0];
_cmd set ["supplyReadyTick", createHashMap];
// Not saved: a load starts every battery ready.
_cmd set ["batteryReadyTick", createHashMap];

_cmd set ["aiMode", "weighted"];
_cmd set ["pickOnce", ""];
// Carried as a debt, so a rate below 1 picks once every few ticks.
_cmd set ["picksPerTick", 0.5];
_cmd set ["pickDebt", 0];
_cmd set ["archetype", "balanced"];
_cmd set ["tickCache", createHashMap];
_cmd set ["aiEvents", []];
_cmd set ["aiSeq", 0];

_cmd set ["dbg_fresh", 0];
_cmd set ["dbg_route", [0, 0, 0, 0]];   // grid A* runs, cells expanded, seconds and frames this tick, for the debug line
_cmd set ["dbg_pick", []];
_cmd
