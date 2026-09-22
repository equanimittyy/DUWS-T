// Locality: client -- an addAction function value, so it runs on whoever opened the menu.
/*
    Developer tools, attached to the player in client_init.sqf behind the Debug mission
    parameter and game_master. The addAction opens the root page; a page row or a Back row
    passes the page name. Rows are deliberately not localised: this is a dev surface, so
    English strings here spare the stringtable a set of tags no player ever reads.
*/
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the addAction: this function is publicVariable'd, so every
// client holds a copy it can call. Rows here make the server do work on demand, and the point
// of the game_master gate is that one machine decides when that happens.
if (!((vehiclevarname player) in game_master)) exitWith {};

private _page = "root";
if (_this isEqualType "") then { _page = _this } else {
    // Read here, before any dialog opens: a row runs with the dialog down and the pointer gone, so a
    // later read is a guess at what the player was looking at.
    DUWS_dbgCursor = cursorObject;
};
private _cursorName = [typeOf DUWS_dbgCursor, str DUWS_dbgCursor] select (typeOf DUWS_dbgCursor isEqualTo "");

switch (_page) do {
    case "root": {
        private _rows = [];
        if (!isNull DUWS_dbgCursor) then {
            _rows pushBack [format ["Cursor: %1 >", _cursorName], fnc_debug_menu, "cursor", DBG_PAGE];
        };
        _rows append [
            ["Missions >",           fnc_debug_menu,      "missions", DBG_PAGE],
            ["Economy >",            fnc_debug_econ_menu, [],         DBG_PAGE],
            ["OPCOM >",              fnc_debug_menu,      "opcom",    DBG_PAGE],
            ["Zones & hardpoints >", fnc_debug_menu,      "zones",    DBG_PAGE],
            ["World >",              fnc_debug_menu,      "world",    DBG_PAGE],
            ["Views >",              fnc_debug_menu,      "views",    DBG_PAGE]
        ];
        ["Debug", _rows] call fnc_open_action_menu;
    };

    case "cursor": {
        private _rows = [
            DBG_BACK("root"),
            ["Flag as searchable >", fnc_debug_search_menu, [DUWS_dbgCursor], DBG_PAGE]
        ];
        if (DUWS_dbgCursor isKindOf "House") then {
            _rows pushBack ["Furnish >", fnc_debug_furnish_menu, [DUWS_dbgCursor], DBG_PAGE];
        };
        if (DUWS_dbgCursor isKindOf "CAManBase" && {side DUWS_dbgCursor == civilian}) then {
            _rows pushBack ["Force civilian mission", {
                [_this, player, "WORK", true] remoteExec ["fnc_civ_mission_request", 2];
            }, DUWS_dbgCursor, DBG_ACTION];
        };
        [format ["Cursor: %1", _cursorName], _rows] call fnc_open_action_menu;
    };

    case "missions": {
        ["Missions", [
            DBG_BACK("root"),
            ["Start a side mission now >", fnc_debug_mission_menu,      "start",    DBG_PAGE],
            ["Re-roll mission offers >",   fnc_debug_mission_menu,      "reroll",   DBG_PAGE],
            ["Spawn random event >",       fnc_debug_random_event_menu, ["player"], DBG_PAGE]
        ]] call fnc_open_action_menu;
    };

    case "opcom": {
        ["OPCOM", [
            DBG_BACK("root"),
            ["Mode: off",           { ["aimode", "off", "", "", player] remoteExec ["fnc_debug_opcom", 2] },    [], DBG_ACTION],
            ["Mode: random",        { ["aimode", "random", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
            ["Mode: weighted",      { ["aimode", "weighted", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
            ["Pick once: random",   { ["pickonce", "random", "", "", player] remoteExec ["fnc_debug_opcom", 2] },   [], DBG_ACTION],
            ["Pick once: weighted", { ["pickonce", "weighted", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
            ["Orders >",            fnc_debug_opcom_menu, [], DBG_PAGE],
            ["Force emission (click map)", {
                ["Click a zone or OPFOR hardpoint to read its force emission.",
                    "Dev tool: the OPCOM force-grid deposit and its source -- (live), (ledger) or (nominal).",
                    { params ["_pos"]; [_pos, player] remoteExec ["fnc_debug_force_emission", 2] }] call fnc_debug_map_click;
            }, [], DBG_MAP],
            ["Grid drift check",    { ["griddrift", "", "", "", player] remoteExec ["fnc_debug_opcom", 2] },    [], DBG_ACTION],
            ["Clear store",         { ["clear", "", "", "", player] remoteExec ["fnc_debug_opcom", 2] },        [], DBG_DANGER]
        ]] call fnc_open_action_menu;
    };

    case "zones": {
        ["Zones & hardpoints", [
            DBG_BACK("root"),
            ["Garrison ledger (click map)", {
                ["Click a zone or town to read its garrison ledger.",
                    "Dev tool: tier, max, available and dead tokens with the strength maths.",
                    { params ["_pos"]; [_pos, player] remoteExec ["fnc_debug_garrison_query", 2] }] call fnc_debug_map_click;
            }, [], DBG_MAP],
            ["Stow / deploy nearest zone", {
                [getPos player] remoteExec ["fnc_duws_toggleNearestZone", 2];
                hint "Composition streaming: toggling the nearest zone.\n\nStowed compositions are deleted and rebuilt from a record,\nso destroyed parts stay gone and crates keep what is left\nin them. Refused while a gun still has its gunner.";
            }, [], DBG_ACTION],
            ["Spawn OPFOR hardpoint >", fnc_debug_hardpoint_menu, "opfor",  DBG_PAGE],
            ["Spawn BLUFOR hardpoint >", fnc_debug_hardpoint_menu, "blufor", DBG_PAGE],
            ["Clear dev hardpoints", {
                [] remoteExec ["fnc_debug_clear_hardpoints", 2];
                hint "Clearing every dev-spawned hardpoint.\n\nThe defenders are deleted and the composition drops its\npersistent flag; the map sweep collects the props once\nno player is within 300 m.";
            }, [], DBG_DANGER],
            ["Recon burst (click map)", {
                ["Click the map to fire an OP recon burst there.",
                    "Dev tool: reveals every BLUFOR within 1 km to OPFOR and cards each player, at 100%.",
                    {
                        params ["_pos"];
                        [_pos] remoteExec ["DUWS_fnc_hardpointOPBurst", 2];
                        hint "OP recon burst fired at the marked spot.\n\nDev tool: every BLUFOR within 1 km is revealed to OPFOR\nand each player carded, at 100% (no per-wake roll).";
                    }] call fnc_debug_map_click;
            }, [], DBG_MAP]
        ]] call fnc_open_action_menu;
    };

    case "world": {
        ["World", [
            DBG_BACK("root"),
            ["Force garbage clean", {
                [] remoteExec ["fnc_duws_forceCleanup", 2];
                hint "Map cleanup: sweeping now.\n\nLifetimes are treated as elapsed, so all litter goes\nexcept: within 300 m of a player, flagged persistent,\na player's last vehicle, a unit still fighting within\n1.5 km of a player, or an intact vehicle parked within\n250 m of the HQ, a FOB or the MHQ. Counts land in the log.";
            }, [], DBG_DANGER],
            ["Spawn intel items (drop-test)", { [player] remoteExec ["fnc_debug_spawn_intel", 2] },  [], DBG_ACTION],
            ["Simulate intel search",         { [player] remoteExec ["fnc_debug_intel_search", 2] }, [], DBG_ACTION],
            ["Force intel reveal",            { [player, "combat", true] remoteExec ["fnc_debug_intel_search", 2] }, [], DBG_ACTION],
            ["Reset disguise cooldowns", {
                [player] remoteExec ["fnc_disguise_resetCooldown", 2];
                hint "Disguise cooldowns reset.\n\nBoth the civilian and the enemy disguise can activate again.";
            }, [], DBG_ACTION],
            ["Calibrate furniture fronts >",  { call fnc_debug_furnish_calibrate },                   [], DBG_PAGE]
        ]] call fnc_open_action_menu;
    };

    case "views": {
        private _toggle = {
            params ["_label", "_on", "_code"];
            [format ["%1 [%2]", _label, ["off", "on"] select _on], _code, [], [DBG_OFF, DBG_ON] select _on]
        };
        ["Views", [
            DBG_BACK("root"),
            ["AoI reaches", count (missionNamespace getVariable ["DUWS_dbgAoiMarkers", []]) > 0, fnc_debug_aoi_view] call _toggle,
            ["OPCOM grid", missionNamespace getVariable ["DUWS_dbgOpcomOn", false], fnc_debug_opcom_view] call _toggle,
            ["Staleness labels", missionNamespace getVariable ["DUWS_dbgOpcomCoverOn", true], {
                DUWS_dbgOpcomCoverOn = !(missionNamespace getVariable ["DUWS_dbgOpcomCoverOn", true]);
                hint format ["OPCOM grid: staleness labels %1.", ["off", "on"] select DUWS_dbgOpcomCoverOn];
            }] call _toggle,
            ["Need & cover labels", missionNamespace getVariable ["DUWS_dbgOpcomNeedOn", false], {
                DUWS_dbgOpcomNeedOn = !(missionNamespace getVariable ["DUWS_dbgOpcomNeedOn", false]);
                hint format ["OPCOM grid: need (N), cover (C) and traffic (T) labels %1.", ["off", "on"] select DUWS_dbgOpcomNeedOn];
            }] call _toggle,
            ["OPCOM AI overlay", missionNamespace getVariable ["DUWS_dbgOpcomAiOn", false], fnc_debug_opcom_ai_overlay] call _toggle
        ]] call fnc_open_action_menu;
    };
};
