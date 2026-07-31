// Locality: client -- called from the request dialog, so it runs on whoever opened it.
/*
    fnc_base_menu_fill.sqf
    Fills the BASE list with the command entries that used to hang off the HQ and the FOB as
    separate scroll actions. One builder for both, since a FOB carries the same command set
    minus what only the HQ has.

    What stayed on the scroll wheel is everything a player reaches for without asking command
    first -- the arsenal, HALO, quick kits, the AI rearm, the killhouse teleports, the black
    market. Those are bought supports or field kit; a menu two clicks deep is the wrong home
    for them.

    A row that cannot apply is absent rather than greyed, matching the supports list beside
    it: an index that was never added cannot be selected, so the dispatch needs no second
    condition per row.

    Row shape: [label, code, args, colour]. The list is stashed for fnc_base_menu_select
    because lbSetData carries strings only, so CODE cannot ride in the row itself.
*/
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};

// _site: the object the menu was opened on. Rest/Heal treats what is standing near it and
// the FOB redeploy rebuilds that FOB's garrison, so both need to know which base this is.
params [["_site", objNull], ["_isFob", false]];

private _rows = [];

// Command menus keep the caps the scroll bucket gave them: the case is a property of the
// bucket, not of the string.
if ((vehiclevarname player) in Squad_Leaders) then {
    _rows pushBack [toUpper (localize "STR_DUWS_T_l0xark5g"), { [] call fnc_squad_manage }, [], ACT_ROW_PRIMARY_MENU];
};

_rows pushBack [toUpper (localize "STR_DUWS_T_iggpsdqo"), { [] call fnc_FOBmanager }, [], ACT_ROW_PRIMARY_MENU];

// HQ only: this one came off the HQ terminal, which a FOB does not have.
if (!_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_INTELRECRUIT_TITLE", {
        [localize "STR_DUWS_T_INTELRECRUIT_TITLE", [
            [localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION", { [player] remoteExec ["fnc_intelAnalysis", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PARTISANS",        { [player] remoteExec ["fnc_hirePartisans", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PMC",              { [player] remoteExec ["fnc_hirePMC", 2]; }, [], [1,0.667,0,1]]
        ]] call fnc_open_action_menu;
    }, [], ACT_ROW_SECONDARY_MENU];
};

// Server-side cooldown check for both bases now. The FOB's copy stamped and published the
// timestamp from its own client, so two players triggering it inside one propagation window
// both passed; here one machine decides.
if ((vehiclevarname player) in game_master) then {
    _rows pushBack [localize "STR_DUWS_T_9eiwr3bt", {
        params ["_site"];
        [player, _site] remoteExec ["fnc_restHealServer", 2];
    }, [_site], ACT_ROW_AMBIENT];
};

if (!_isFob && {(vehiclevarname player) in Squad_Leaders}) then {
    _rows pushBack [localize "STR_DUWS_T_4jabuvz6", { [] call fnc_groupReset }, [], ACT_ROW_AMBIENT];
};

if ((vehiclevarname player) == "player1") then {
    _rows pushBack [localize "STR_DUWS_T_SHOW_MISSION_COOLDOWNS", { [] call fnc_mission_cooldowns_show }, [], ACT_ROW_AMBIENT];
};

// Last, for the reason the scroll bucket put it lowest: a mis-clicked spend costs more than
// a row one line further down does.
if (_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", { _this call fnc_redeployFOB }, [_site], ACT_ROW_COMMIT];
} else {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", {
        // Advisory only; fnc_redeployHQUnits checks and charges on the server.
        if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };
        [player] remoteExec ["fnc_redeployHQUnits", 2];
    }, [], ACT_ROW_COMMIT];
};

lbClear 2104;
{
    private _i = lbAdd [2104, _x select 0];
    lbSetColor [2104, _i, _x select 3];
} forEach _rows;
lbSetCurSel [2104, 0];

// uiNamespace, not missionNamespace: rows hold CODE, which is not serializable, and the
// mission namespace is written into save games.
uiNamespace setVariable ["DUWS_baseMenu_rows", _rows];
