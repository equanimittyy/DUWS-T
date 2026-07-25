/*
    fnc_civ_setup_array.sqf
    Builds civ_array (the civilian body-model pool) on the server, independent of whether the
    ambient population spawns. PMC and partisan hiring draw their unit models from civ_array,
    so it must be populated even when civilians are OFF (CIV_PRESENCE == "NONE").
*/
if (!isServer) exitWith {};

[] call compile preprocessFileLineNumbers "duws\shared\factions\CIV_FACTIONS.sqf";
missionNamespace setVariable ["civ_array", civ_array];
