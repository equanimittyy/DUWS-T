// Locality: client; the addAction/event-handler bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};
params ["_depot", "_trgNetId"];
if (isNull _depot) exitWith {};

// dedup
if (_depot getVariable ["repair_actions_done", false]) exitWith {};
_depot setVariable ["repair_actions_done", true];

private _trg = objectFromNetId _trgNetId;
if (isNull _trg) exitWith { ["ERROR", "SUPPORT", "Trigger null on client"] call fnc_log; };

// appearance/pylons dialogs pass as local code via action params, to avoid globals
private _fnc_appearance = {
    params ["_trg"];
    private _vehicles = _trg nearEntities [["Car", "Tank", "Air", "Ship"], 5];
    private _veh = _vehicles param [0, objNull];
    if (isNull _veh) exitWith {
        hint localize "STR_DUWS_T_vehicle_garage_no_vehicle";
    };

    disableSerialization;
    private _display = createDialog ["RscDisplayEmpty", false];
    private _listbox = _display ctrlCreate ["RscListBox", 1500];
    _listbox ctrlSetPosition [0.3, 0.22, 0.4, 0.4];
    _listbox ctrlCommit 0;

    // skin list: static, no refresh needed
    private _textures = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "TextureSources")) apply {configName _x};
    { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;

    // only user-source animations
    private _animations = ("true" configClasses (configFile >> "CfgVehicles" >> typeOf _veh >> "AnimationSources")) select {
        getText (_x >> "source") == "user"
    } apply {configName _x};

    private _fnc_refreshAnimList = {
        lbClear _listbox;
        { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
        {
            private _state = _veh animationSourcePhase _x;
            private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
            _listbox lbAdd _label;
        } forEach _animations;
        lbSetCurSel [1500, 0];
    };

    call _fnc_refreshAnimList;

    _display setVariable ["garage_veh", _veh];
    _display setVariable ["garage_animList", _animations];
    _display setVariable ["garage_textureList", _textures];

    // Apply button: refresh the list without closing
    private _applyBtn = _display ctrlCreate ["RscButton", 1600];
    _applyBtn ctrlSetText "Apply";
    _applyBtn ctrlSetPosition [0.35, 0.67, 0.1, 0.05];
    _applyBtn ctrlCommit 0;
    _applyBtn ctrlAddEventHandler ["ButtonClick", {
        private _parent = ctrlParent (_this select 0);
        private _veh = _parent getVariable ["garage_veh", objNull];
        if (isNull _veh) exitWith {};
        private _idx = lbCurSel 1500;
        private _text = lbText [1500, _idx];
        if (_text find "Texture:" != -1) then {
            private _texName = (_text splitString ": ") select 1;
            [_veh, _texName] call BIS_fnc_initVehicle;
        } else {
            private _animName = (_text splitString " (") select 0;
            private _state = _veh animationSourcePhase _animName;
            _veh animateSource [_animName, if (_state > 0) then {0} else {1}, true];
        };
        private _animations = _parent getVariable ["garage_animList", []];
        private _textures = _parent getVariable ["garage_textureList", []];
        private _listbox = _parent displayCtrl 1500;
        lbClear _listbox;
        { _listbox lbAdd format ["Texture: %1", _x]; } forEach _textures;
        {
            private _state = _veh animationSourcePhase _x;
            private _label = if (_state > 0) then { format ["%1 (ON)", _x] } else { format ["%1 (OFF)", _x] };
            _listbox lbAdd _label;
        } forEach _animations;
        lbSetCurSel [1500, 0];
    }];

    private _closeBtn = _display ctrlCreate ["RscButton", 1601];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetPosition [0.55, 0.67, 0.1, 0.05];
    _closeBtn ctrlCommit 0;
    _closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
};

// adjust vehicle pylons (costs 5 CP)
private _fnc_pylons = {
    params ["_trg"];
    private _vehicles = _trg nearEntities [["Air"], 5];
    private _veh = _vehicles param [0, objNull];
    if (isNull _veh) exitWith {
        hint localize "STR_DUWS_T_vehicle_garage_no_vehicle";
    };

    disableSerialization;
    private _display = createDialog ["RscDisplayEmpty", false];
private _txtHint = _display ctrlCreate ["RscText", 1000];
_txtHint ctrlSetPosition [0.2, 0.15, 0.6, 0.04];
_txtHint ctrlSetText (localize "STR_DUWS_T_PYLON_COST_HINT");
_txtHint ctrlSetBackgroundColor [0, 0, 0, 0.3];
_txtHint ctrlCommit 0;
    private _lbPylons = _display ctrlCreate ["RscListBox", 1500];
    _lbPylons ctrlSetPosition [0.2, 0.2, 0.25, 0.5];
    _lbPylons ctrlCommit 0;

    private _lbCompatible = _display ctrlCreate ["RscListBox", 1501];
    _lbCompatible ctrlSetPosition [0.5, 0.2, 0.3, 0.5];
    _lbCompatible ctrlCommit 0;

    _display setVariable ["garage_veh", _veh];

    private _pylonNamesRaw = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "pylonTopCover");
    private _pylonNames = if (_pylonNamesRaw != "") then { _pylonNamesRaw splitString ";" } else { [] };

    // helper: pylon turret path, defaulting to the vehicle body []
    private _fnc_getPylonTurret = {
        params ["_veh", "_pylonIndex"];
        private _pylonConfig = configFile >> "CfgVehicles" >> typeOf _veh >> "Components" >> "TransportPylonsComponent" >> "Pylons" >> format ["Pylon%1", _pylonIndex];
        if (isClass _pylonConfig) then {
            private _turret = getArray (_pylonConfig >> "turret");
            if (count _turret == 0) then { [] } else { _turret };
        } else {
            []
        };
    };

    // core refresh: left list plus right-hand compatible list
    private _fnc_refreshAll = {
        private _veh = _display getVariable "garage_veh";
        if (isNull _veh) exitWith {};

        private _leftIdx = lbCurSel _lbPylons;
        private _rightIdx = lbCurSel _lbCompatible;
        if (_leftIdx < 0) then { _leftIdx = 0 };

        private _pylonMags = getPylonMagazines _veh;
        lbClear _lbPylons;
        {
            private _idx = _forEachIndex;
            private _pylonName = if (count _pylonNames > _idx) then { _pylonNames select _idx } else { format ["Pylon %1", _idx + 1] };
            private _mag = _x;
            private _displayName = if (_mag != "") then {
                getText (configFile >> "CfgMagazines" >> _mag >> "displayName")
            } else {
                localize "STR_DUWS_T_empty"
            };
            _lbPylons lbAdd format ["%1: %2", _pylonName, _displayName];
        } forEach _pylonMags;

        if (_leftIdx >= lbSize _lbPylons) then { _leftIdx = 0 };
        lbSetCurSel [1500, _leftIdx];

        // refresh the right list, using a 1-based pylon index
        private _pylonIndex = _leftIdx + 1;
        private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
        private _flat = [];
        {
            if (_x isEqualType "") then {
                if (_x != "") then { _flat pushBack _x };
            } else {
                if (_x isEqualType []) then {
                    { if (_x != "") then { _flat pushBack _x } } forEach _x;
                };
            };
        } forEach _compatibleMags;

        lbClear _lbCompatible;
        _lbCompatible lbAdd localize "STR_DUWS_T_empty";
        if (count _flat == 0) then {
            _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
        } else {
            { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
        };

        if (_rightIdx < 0 || _rightIdx >= lbSize _lbCompatible) then { _rightIdx = 0 };
        lbSetCurSel [1501, _rightIdx];
    };

    _display setVariable ["refreshFn", _fnc_refreshAll];

    _lbPylons ctrlAddEventHandler ["LBSelChanged", {
        params ["_ctrl", "_newIdx"];
        private _display = ctrlParent _ctrl;
        private _veh = _display getVariable "garage_veh";
        if (isNull _veh) exitWith {};
        private _lbCompatible = _display displayCtrl 1501;
        lbClear _lbCompatible;

        private _pylonIndex = _newIdx + 1;
        private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
        private _flat = [];
        {
            if (_x isEqualType "") then {
                if (_x != "") then { _flat pushBack _x };
            } else {
                if (_x isEqualType []) then {
                    { if (_x != "") then { _flat pushBack _x } } forEach _x;
                };
            };
        } forEach _compatibleMags;

        _lbCompatible lbAdd localize "STR_DUWS_T_empty";
        if (count _flat == 0) then {
            _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
        } else {
            { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
        };
        lbSetCurSel [1501, 0];
    }];

    call _fnc_refreshAll;

    private _mountBtn = _display ctrlCreate ["RscButton", 1600];
    _mountBtn ctrlSetText "Mount";
    _mountBtn ctrlSetPosition [0.6, 0.75, 0.1, 0.05];
    _mountBtn ctrlCommit 0;
    _mountBtn ctrlAddEventHandler ["ButtonClick", {
        private _display = ctrlParent (_this select 0);
        private _veh = _display getVariable "garage_veh";
        if (isNull _veh) exitWith {};
        private _pylonIdx = lbCurSel 1500;
        private _magIdx = lbCurSel 1501;
        if (_pylonIdx < 0 || _magIdx < 0) exitWith { hint localize "STR_DUWS_T_repair_select_pylon" };

        private _pylonIndex = _pylonIdx + 1;
        private _compatibleMags = _veh getCompatiblePylonMagazines _pylonIndex;
        private _flat = [];
        {
            if (_x isEqualType "") then {
                if (_x != "") then { _flat pushBack _x };
            } else {
                if (_x isEqualType []) then {
                    { if (_x != "") then { _flat pushBack _x } } forEach _x;
                };
            };
        } forEach _compatibleMags;

        private _selectedMag = if (_magIdx == 0) then { "" } else { _flat select (_magIdx - 1) };
        private _turret = [_veh, _pylonIndex] call _fnc_getPylonTurret;

        // server call: deduct CP and set the pylon
        [netId _veh, _pylonIndex, _selectedMag, _turret, getPlayerUID player] remoteExec ["fnc_pylon_set_with_cost", 2];

        (_this select 0) spawn {
            params ["_ctrl"];
            uiSleep 0.1;
            private _display = ctrlParent _ctrl;
            if (!isNull _display) then {
                private _veh = _display getVariable ["garage_veh", objNull];
                if (isNull _veh) exitWith {};
                private _lbPylons = _display displayCtrl 1500;
                private _pylonNamesRaw = getText (configFile >> "CfgVehicles" >> typeOf _veh >> "pylonTopCover");
                private _pylonNames = if (_pylonNamesRaw != "") then { _pylonNamesRaw splitString ";" } else { [] };
                private _pylonMags = getPylonMagazines _veh;
                lbClear _lbPylons;
                {
                    private _pylonName = if (count _pylonNames > _forEachIndex) then { _pylonNames select _forEachIndex } else { format ["Pylon %1", _forEachIndex + 1] };
                    private _displayName = if (_x != "") then {
                        getText (configFile >> "CfgMagazines" >> _x >> "displayName")
                    } else {
                        localize "STR_DUWS_T_empty"
                    };
                    _lbPylons lbAdd format ["%1: %2", _pylonName, _displayName];
                } forEach _pylonMags;
                lbSetCurSel [1500, 0];

                private _compatibleMags = _veh getCompatiblePylonMagazines 1;
                private _flat = [];
                {
                    if (_x isEqualType "") then {
                        if (_x != "") then { _flat pushBack _x };
                    } else {
                        if (_x isEqualType []) then {
                            { if (_x != "") then { _flat pushBack _x } } forEach _x;
                        };
                    };
                } forEach _compatibleMags;
                private _lbCompatible = _display displayCtrl 1501;
                lbClear _lbCompatible;
                _lbCompatible lbAdd localize "STR_DUWS_T_empty";
                if (count _flat == 0) then {
                    _lbCompatible lbAdd localize "STR_DUWS_T_no_weapons_available";
                } else {
                    { _lbCompatible lbAdd getText (configFile >> "CfgMagazines" >> _x >> "displayName") } forEach _flat;
                };
                lbSetCurSel [1501, 0];
            };
        };
    }];

    private _closeBtn = _display ctrlCreate ["RscButton", 1602];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetPosition [0.35, 0.85, 0.3, 0.05];
    _closeBtn ctrlCommit 0;
    _closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
};

// one 'vehicle modification' action opens the menu; entries keep their own logic
_depot addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_VEHICLE_CUSTOMIZATION"),
    {
        params ["_t", "_c", "_i", "_args"];
        _args params ["_trg", "_fnc_appearance", "_fnc_pylons"];
        [localize "STR_DUWS_T_VEHICLE_CUSTOMIZATION", [
            [format ["%1 (2 CP)", localize "STR_DUWS_T_repair_vehicle"],       { params ["_trg"]; [player, _trg] remoteExec ["fnc_veh_repair_action", 2]; }, [_trg]],
            [localize "STR_DUWS_T_check_vehicle_status",                       { params ["_trg"]; [player, netId _trg] remoteExec ["fnc_veh_repair_check_status", 2]; }, [_trg]],
            [localize "STR_DUWS_T_vehicle_appearance",                        _fnc_appearance, [_trg]],
            [format ["%1 (5 CP)", localize "STR_DUWS_T_vehicle_pylons"],       _fnc_pylons, [_trg]]
        ]] call fnc_open_action_menu;
    },
    [_trg, _fnc_appearance, _fnc_pylons],
    90,
    true,
    true,
    "",
    "_this distance _target < 8"
];
