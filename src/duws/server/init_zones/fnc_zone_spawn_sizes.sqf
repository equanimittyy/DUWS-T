// Locality: server -- spawned once from server/server_init.sqf to publish the table below.
//
// What OPFOR a zone gets, by radius band. This was six functions of the same shape, each a flat
// list of spawn calls with a `sleep 5` written between every pair; adding a band or retuning one
// meant editing control flow. The lists are data, so they live as data and one driver walks them.
//
// A token is a group kind, or a vehicle class fnc_random_veh understands ("car", "armored", "air").
DUWS_zoneSpawnTiers = [
    // [radius ceiling, base spawns, extra when more than two players, extra when fewer]
    [101,  ["patrol","team","patrol","patrol","car","car"],
           [], []],
    [251,  ["patrol","team","team","patrol","patrol","car","car"],
           ["patrol","armored"], ["car"]],
    [501,  ["sniper","patrol","patrol","patrol","team","wpteam","armored","car"],
           ["team","armored"], []],
    [1001, ["sniper","patrol","patrol","patrol","patrol","team","team","wpteam","armored","air","car"],
           ["patrol","team","wpteam","armored"], []],
    [1501, ["sniper","patrol","patrol","patrol","patrol","patrol","team","team","team","wpteam",
            "armored","armored","air","car"],
           ["sniper","team","wpteam","armored"], []],
    // Everything above the last ceiling. Kept as a band rather than an else so the table reads in
    // one direction.
    [1e11, ["sniper","sniper","patrol","team","wpteam","patrol","patrol","team","wpteam","team",
            "wpteam","team","patrol","team","patrol","armored","armored","armored","air","air","car"],
           [], []]
];

DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size"];
    switch (_token) do {
        case "patrol": { [_pos, _size] spawn fnc_createoppatrol2 };
        case "team":   { [_pos, _size] spawn fnc_createopteam2 };
        case "sniper": { [_pos, _size] spawn fnc_createoppatrol_sniper };
        case "wpteam": { [_pos, _size] spawn fnc_createopwpteam };
        // Anything else names a vehicle class rather than a group kind.
        default        { [OPFOR_Faction_X, _token, _pos, _size] spawn fnc_random_veh };
    };
};

// Spawned by fnc_createzone, which no longer needs a switch to pick a function per band.
fnc_zone_spawn = {
    params ["_spawnPos", "_size"];

    private _i = DUWS_zoneSpawnTiers findIf { _size < (_x select 0) };
    if (_i < 0) exitWith {
        ["ERROR", "ZONES", format ["no spawn tier covers radius %1", _size]] call fnc_log;
    };
    (DUWS_zoneSpawnTiers select _i) params ["", "_base", "_extraMulti", "_extraSolo"];

    private _spawns = _base + ([_extraSolo, _extraMulti] select (count (call BIS_fnc_listPlayers) > 2));
    {
        [_x, _spawnPos, _size] call DUWS_fnc_zoneSpawnOne;
        // Staggered, not batched: each of these spawns a group, and firing the whole band in one
        // frame is what the original's per-call sleep existed to avoid. None after the last.
        if (_forEachIndex < (count _spawns) - 1) then { sleep 5 };
    } forEach _spawns;
};
