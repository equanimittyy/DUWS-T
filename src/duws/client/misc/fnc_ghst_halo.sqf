// Locality: client -- passed as an addAction function value in
// client/dialog/fnc_request_support.sqf, so it runs on whoever activates it.
/*
fnc_ghst_halo
--------------
V1.3.2 Script by: Ghost (modified).  
Added support for AI-only HALO (player not included).
Params: [typehalo, althalo, altchute, excludePlayer]
  typehalo: true=group jump (AI), false=single player
  althalo: altitude to start jump
  altchute: auto chute open altitude
  excludePlayer: if true, player does NOT jump (only AI). Requires typehalo=true.
*/
#include "..\..\shared\includes\action_style.hpp"


// AI parachute handler, defined so it is available on the server.
DUWS_fnc_aiHalo = {
    params ["_aiNetIds", "_dropPos", "_startAlt", "_chuteAlt"];
    ["INFO", "HALO", format ["AI Halo started on server with %1 units", count _aiNetIds]] call fnc_log;
    private _aiUnits = [];
    {
        private _unit = objectFromNetId _x;
        if (!isNull _unit) then {
            _aiUnits pushBack _unit;
        } else {
            ["ERROR", "HALO", format ["AI unit with netId %1 is null, skipping", _x]] call fnc_log;
        };
    } forEach _aiNetIds;

    {
        // teleport AI above the target; no bis_fnc_halo, let them free-fall
        private _offsetX = random [10, 50, 100];
        private _offsetY = random [10, 50, 100];
        _x setPos [(_dropPos select 0) + _offsetX, (_dropPos select 1) - _offsetY, _startAlt];
        if (duws_log_level >= 4) then { ["DEBUG", "HALO", format ["AI %1 setPos to %2", _x, getPos _x]] call fnc_log; };
        _x allowDamage false;
    } forEach _aiUnits;

    // auto-deploy monitor: spawn a chute and force the AI into it
    {
        [_x, _chuteAlt] spawn {
            params ["_unit", "_alt"];
            // wait until altitude drops to the chute-deploy height
            waitUntil {sleep 0.1; (getPosATL _unit select 2) <= _alt};
            if (duws_log_level >= 4) then { ["DEBUG", "HALO", format ["AI %1 deploying chute via createVehicle and moveInDriver", _unit]] call fnc_log; };
            private _chute = createVehicle ["Steerable_Parachute_F", (getPosATL _unit), [], 0, "FLY"];
            _chute setPosATL (getPosATL _unit);
            _chute allowDamage false;
            _unit assignAsDriver _chute;
            _unit moveInDriver _chute;
            // fallback: if moveInDriver fails, try moveInAny
            if (vehicle _unit != _chute) then {
                _unit moveInAny _chute;
            };
            waitUntil {sleep 0.1; (getPosATL _unit select 2) < 2};
            if (alive _unit) then {
                _unit allowDamage true;
            };
            if (!isNull _chute) then {
                _chute allowDamage true;
            };
        };
    } forEach _aiUnits;
    ["INFO", "HALO", "AI Halo processing complete"] call fnc_log;
};

// published so it can be reached by remoteExec
publicVariable "DUWS_fnc_aiHalo";

_host = _this select 0;
_caller = _this select 1;
_id = _this select 2;
_params = _this select 3;

_params params [
    ["_typehalo", false, [true, false, 0]],
    ["_althalo", 600, [0]],
    ["_altchute", 70, [0]],
    ["_excludePlayer", false, [true, false]]
];
if (_typehalo isEqualType 0) then { _typehalo = _typehalo > 0; };

if (not alive _host) exitwith {
    hint localize "STR_DUWS_T_royy580r"; 
    _host removeaction _id;
};

mapclick = false;
if (!(["HALO", "clickpos = _pos; mapclick = true; ['HALO'] call fnc_mapclick_release; true;"] call fnc_mapclick_claim)) exitWith {};
openMap true;
player setVariable["Saved_Loadout", getUnitLoadout player];
// Banner not chatbox: the engine draws hints/chat beneath the open map, so a map-display
// control is the only prompt visible during selection. Same surface HQ placement uses.
waitUntil { !isNull findDisplay 12 };
[format ["<t size='2' color='#00ffff'>%1</t><br/>%2", localize "STR_DUWS_T_halo_select_title", localize "STR_DUWS_T_vtkkn80v"]] call fnc_map_prompt;
waituntil {mapclick or !(visiblemap)};
// Released on the abort path too: the player closing the map ends the jump, and without this
// the slot would stay owned by a mode that is no longer running.
["HALO"] call fnc_mapclick_release;
if (!visibleMap) exitwith {
    hint localize "STR_DUWS_T_q639bywa";
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};
_pos = clickpos;
// Selection is done; close the map so the confirm dialog below draws on top of it.
openMap false;

// Everyone who will actually leave the plane: the player unless excluded, plus any on-foot
// AI in the squad. Counted once here so the price reflects the real headcount, and reused by
// the AI dispatch below rather than gathered twice.
private _aiUnits = [];
if (_typehalo) then {
    _aiUnits = (units group _caller) select {
        isNull objectParent _x && {!isPlayer _x}
    };
};
private _jumpers = (count _aiUnits) + ([1, 0] select _excludePlayer);

if (_jumpers <= 0) exitWith {
    hint localize "STR_DUWS_T_halo_no_units";
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};

// 1 CP per jumper per 5 km from HQ, distance rounded up so any real jump costs something.
private _distKm = ceil ((PosOfBLUHQ distance2D _pos) / 1000);
private _cost = _jumpers * ceil (_distKm / 5);

// Advisory read before the confirm, so the player is not asked to fund a jump they cannot
// afford. fnc_pool_spend below stays the authoritative gate against a mid-window change.
if (commandpointsblu1 < _cost) exitWith {
    hint format [localize "STR_DUWS_T_p6sb3ply", _cost];
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};

if !([format [localize "STR_DUWS_T_halo_confirm", _jumpers, _distKm, _cost], localize "STR_DUWS_T_halo_confirm_title", true, true] call BIS_fnc_guiMessage) exitWith {
    hint localize "STR_DUWS_T_q639bywa";
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};

if !(["CP", _cost] call fnc_pool_spend) exitWith {
    hint format [localize "STR_DUWS_T_p6sb3ply", _cost];
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};

if (_typehalo) then {
    if (count _aiUnits > 0) then {
        private _aiNetIds = _aiUnits apply {netId _x};
        ["INFO", "HALO", format ["Client sending AI Halo request for %1 units", count _aiNetIds]] call fnc_log;
        if (isServer) then {
            // single-player: call directly
            [_aiNetIds, _pos, _althalo, _altchute] call DUWS_fnc_aiHalo;
        } else {
            // multiplayer: hand off to the server
            [_aiNetIds, _pos, _althalo, _altchute] remoteExec ["DUWS_fnc_aiHalo", 2];
        };
    } else {
        ["INFO", "HALO", "No AI units to jump"] call fnc_log;
    };
};

if (!_excludePlayer) then {
    _caller setpos [(_pos select 0)+30, _pos select 1, _althalo];
    titleCut ["", "BLACK IN", 5];
    openMap false;

    _bis_fnc_halo_action = _caller addaction [ACT_MOVE("STR_DUWS_T_bd22lcos"),"A3\functions_f\misc\fn_HALO.sqf",[],70,true,true,"Eject","true"];
    sleep 5;
    hint localize "STR_DUWS_T_sjk84cdc";

    waituntil {sleep 0.1;(position _caller select 2) <= _altchute};
    _caller removeaction _bis_fnc_halo_action;

    if ((vehicle _caller) iskindof "ParachuteBase") exitwith {
        waitUntil {sleep 0.1;isTouchingGround player};
        player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
    };

    hint localize "STR_DUWS_T_o3yt6tzg";
    [_caller] spawn bis_fnc_halo;

    waitUntil {sleep 0.1;isTouchingGround player};
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
} else {
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
    openMap false;
};