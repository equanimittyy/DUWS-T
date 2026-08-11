// Locality: server -- read at zone generation and hardpoint build, both server-side. Definitions only.
//
// Era resolvers for the two composition systems. VERSION_X names the asset era; MODERN is the only one
// built, and it is the guaranteed floor: an unmapped era resolves to the MODERN set rather than to
// nothing, so a new VERSION_X can never hand a caller an empty list and spawn a zone with no centre or
// a hardpoint as bare men on open ground. A future era overrides by adding its own case / globals; a
// slot it omits still falls back to MODERN, so a partial era set mixes safely with the baseline.

// [] call fnc_zone_prefab_set -> [weightedPrefabList, simpleZoneEntry] for the current era.
//   weightedPrefabList rows: [label, fortified, builderFn, weight]; simpleZoneEntry: [label, fortified, builderFn].
fnc_zone_prefab_set = {
    private _modern = [
        [
            ["Vehicle Refit", true, fnc_modern_vehfittingstation, 0.1],
            ["Storage Bunker", true, fnc_modern_StorageBunker, 0.12],
            ["Comm Station", true, fnc_modern_CommStation, 0.14],
            ["Recon Outpost", true, fnc_modern_reconOutpost, 0.1],
            ["Outpost", true, fnc_modern_outpost1, 0.1],
            ["Outpost", true, fnc_modern_Outpost2, 0.1],
            ["Field Hospital", true, fnc_modern_FieldHospital, 0.2]
        ],
        ["Outpost", true, fnc_modern_simple_zone]
    ];
    switch (VERSION_X) do {
        case "MODERN": { _modern };
        default { _modern };
    }
};

// [_type] call fnc_hardpoint_comp -> composition rows for the current era, MODERN baseline as the floor.
// A non-MODERN era supplies DUWS_hardpointComp_<era>_<type>; a type it omits falls back to the bare
// MODERN global. MODERN itself has no prefixed set, so it reads the bare globals directly.
fnc_hardpoint_comp = {
    params ["_type"];
    private _rows = [];
    if (VERSION_X != "MODERN") then {
        _rows = missionNamespace getVariable [format ["DUWS_hardpointComp_%1_%2", toLower VERSION_X, _type], []];
    };
    if (_rows isEqualTo []) then {
        _rows = missionNamespace getVariable ["DUWS_hardpointComp_" + _type, []];
    };
    _rows
};
