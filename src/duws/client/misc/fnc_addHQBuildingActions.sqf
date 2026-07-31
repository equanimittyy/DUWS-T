// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
// Every command action hangs off the HQ structure, mirroring shared/functions/fnc_FOBactions.sqf.
// Splitting them across the commander and the map board meant a player who lost track of either
// prop lost the menu with it, and the commander is a killable unit.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};

params ["_hqBuilding"];

if (isNull _hqBuilding) exitWith {};

// 防重
if (_hqBuilding getVariable ["HQ_building_actions_done", false]) exitWith {};
_hqBuilding setVariable ["HQ_building_actions_done", true];

_hqBuilding addAction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"), fnc_HQ_Request_Menu, [], 100, true, true, "", "_this == player"];

if ((vehiclevarname player) in Squad_Leaders) then {
    _hqBuilding addAction [ACT_PRIMARY_MENU("STR_DUWS_T_l0xark5g"), fnc_squad_manage, [], 100, true, true, "", "_this == player"];
    _hqBuilding addAction [ACT_UTIL("STR_DUWS_T_4jabuvz6"), fnc_groupReset, [], 20, true, true, "", "_this == player"];
};

_hqBuilding addAction [ACT_PRIMARY_MENU("STR_DUWS_T_iggpsdqo"), fnc_FOBmanager, [], 100, true, true, "", "_this == player"];

// 添加显示任务冷却
_hqBuilding addAction [
    ACT_UTIL("STR_DUWS_T_SHOW_MISSION_COOLDOWNS"),
    {
        private _lines = [];
        private _missionTypes = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
        private _version = VERSION_X;
        {
            private _type = _x;
            // Mission seconds, not campaign time: nothing that drags the clock -- resting, a Zeus
            // jumping to night -- shortens the wait.
            private _remaining = [_type] call fnc_mission_cooldown_left;
            private _minutes = floor (_remaining / 60);
            private _seconds = floor (_remaining % 60);

            private _missionName = switch (_type) do {
                case 0: { localize "STR_DUWS_T_c0" };
                case 1: { localize "STR_DUWS_T_c1" };
                case 2: { localize "STR_DUWS_T_c2" };
                case 3: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c3" };
                        case "WW2":     { localize "STR_DUWS_T_c3" };
                        case "VIETNAM": { localize "STR_DUWS_T_c3" };
                        default         { localize "STR_DUWS_T_c3" };
                    };
                };
                case 4: { localize "STR_DUWS_T_c4" };
                case 5: { localize "STR_DUWS_T_c5" };
                case 6: { localize "STR_DUWS_T_c6" };
                case 7: { localize "STR_DUWS_T_c7" };
                case 8: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c8" };
                        case "WW2":     { localize "STR_DUWS_T_c8" };
                        case "VIETNAM": { localize "STR_DUWS_T_c8" };
                        default         { localize "STR_DUWS_T_c8" };
                    };
                };
                case 9: { localize "STR_DUWS_T_c9" };
                case 10: {
                    switch (VERSION_X) do {
                        case "MODERN":  { localize "STR_DUWS_T_c10" };
                        case "VIETNAM": { localize "STR_DUWS_T_c10" };
                        default         { localize "STR_DUWS_T_c10" };
                    };
                };
                case 11: { localize "STR_DUWS_T_c11" };
                case 12: { localize "STR_DUWS_T_c12" };
                case 13: { localize "STR_DUWS_T_c13" };
                case 14: { localize "STR_DUWS_T_c14" };
                case 15: { localize "STR_DUWS_T_c15" };
                case 16: { localize "STR_DUWS_T_c16" };
                default { format [localize "STR_DUWS_T_UNKNOWN_MISSION", _type] };
            };
            private _line = if (_remaining <= 0) then {
                format ["%1: %2", _missionName, localize "STR_DUWS_T_COOLDOWN_READY"]
            } else {
                format ["%1: %2m%3s", _missionName, _minutes, _seconds]
            };
            _lines pushBack _line;
        } forEach _missionTypes;
        hint (_lines joinString "\n");
    },
    [],
    20,
    true,
    true,
    "",
    "(vehiclevarname player) == 'player1'"
];
