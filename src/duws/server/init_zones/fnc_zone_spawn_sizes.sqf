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

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
// The band below still staggers them, which is what the spawn was doing.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size"];
    switch (_token) do {
        case "patrol": { [_pos, _size] call fnc_createoppatrol2 };
        case "team":   { [_pos, _size] call fnc_createopteam2 };
        case "sniper": { [_pos, _size] call fnc_createoppatrol_sniper };
        case "wpteam": { [_pos, _size] call fnc_createopwpteam };
        // Anything else names a vehicle class rather than a group kind.
        default        { [OPFOR_Faction_X, _token, _pos, _size] call fnc_random_veh };
    };
};

// Spawned by fnc_createzone, which no longer needs a switch to pick a function per band.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""], ["_gen", -1]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _i = DUWS_zoneSpawnTiers findIf { _size < (_x select 0) };
    if (_i < 0) exitWith {
        ["ERROR", "ZONES", format ["no spawn tier covers radius %1", _size]] call fnc_log;
    };
    (DUWS_zoneSpawnTiers select _i) params ["", "_base", "_extraMulti", "_extraSolo"];

    private _spawns = _base + ([_extraSolo, _extraMulti] select (count (call BIS_fnc_listPlayers) > 2));

    // The band is what the zone would field intact; it deploys at whatever its garrison was ground
    // down to. Without this, breaking a garrison and leaving buys the player nothing -- the same
    // fight is waiting at full strength when they come back.
    _spawns = [_spawns, [_zoneKey] call fnc_zone_strength] call fnc_zone_thin;

    {
        private _grp = [_x, _spawnPos, _size] call DUWS_fnc_zoneSpawnOne;
        if (!isNull _grp) then { _roster append (units _grp) };
        // Staggered, not batched: each of these spawns a group, and firing the whole band in one
        // frame is what the original's per-call sleep existed to avoid. None after the last.
        if (_forEachIndex < (count _spawns) - 1) then { sleep 5 };
    } forEach _spawns;

    // Settled before the peak is taken. fnc_createopfortified appends to the same roster from its
    // own thread and is normally long finished by here, but nothing enforces that, and a peak taken
    // before its crews are in undercounts the garrison -- which makes the zone quietly cheaper.
    sleep 15;

    // A band still placing when its own zone packs up must not publish anything: the sweep has
    // already deleted what it would be describing, and the capture test reads a stale peak beside
    // empty ground as a garrison wiped.
    if (_gen >= 0 && {([_zoneKey] call fnc_zone_gen) != _gen}) exitWith {
        ["INFO", "ZONES", format ["%1 torn down mid-spawn; garrison peak not published", _zoneKey]] call fnc_log;
    };

    // The strength fnc_zone_capture_ready judges this zone against, and the only place it is set.
    // fnc_zone_garrison_dropped is the only place it is cleared, and states the contract binding
    // the two.
    //
    // Anchored to the men this zone's first completed cycle placed, not to what just deployed: a
    // garrison that comes back at six tenths is still measured against the ten, so the men killed
    // last visit stay killed. Re-basing the peak on the reduced garrison would restore the whole
    // 80%-to-beat every time the zone streamed out, which is the refund attrition exists to stop.
    private _placed = [_zoneKey] call fnc_zone_garrison_count;
    private _baseVar = format ["DUWS_zoneBase_%1", _zoneKey];
    private _baseline = missionNamespace getVariable [_baseVar, 0];
    if (_baseline <= 0) then {
        _baseline = _placed;
        missionNamespace setVariable [_baseVar, _baseline];
    };
    missionNamespace setVariable [format ["DUWS_zonePeak_%1", _zoneKey], _baseline];
    ["INFO", "ZONES", format ["%1 deployed %2 men at %3 strength; garrison peak %4",
        _zoneKey, _placed, [_zoneKey] call fnc_zone_strength, _baseline]] call fnc_log;
};
