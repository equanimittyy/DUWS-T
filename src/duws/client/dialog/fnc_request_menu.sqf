// Locality: client -- an addAction function value, so it runs on whoever opens the menu.
/*
    fnc_request_menu.sqf
    The one request dialog, for the HQ and for every FOB. The FOB used to have a copy of this
    file and a copy of the layout with three listbox IDCs renamed; it differs in three things
    and no more: a shorter unit and vehicle list, a squad list without the heavy sections, and
    no supports at all.

    _this is the addAction argument array -- [target, caller, id, args] -- where args is [true]
    at a FOB. The target is the base the menu was opened on, which the BASE list needs: rest
    treats who is standing near it, and a redeploy rebuilds that base's garrison.
*/
if (!hasInterface) exitWith {};

private _site = _this param [0, objNull];
private _isFob = (_this param [3, []]) param [0, false];

private _display = createDialog ["ressourceheader", false];
if (isNull _display) exitWith {};

ctrlSetText [1000, format ["%1", commandpointsblu1]];
ctrlSetText [1001, format ["%1", zoneundercontrolblu]];
ctrlSetText [1002, format ["%1", WARCOM_blufor_ap]];

// REQUEST UNITS -- a FOB offers the first five of the faction's units, the HQ all of them.
lbAdd [2100, localize "STR_DUWS_T_zo6ih0pt"];   // 0
lbAdd [2100, ""];                               // 1

private _units = ["UNIT"] call fnc_faction_rqst_list;
if (_isFob) then { _units = _units select [0, 5] };
{
    private _displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
    lbAdd [2100, _displayName + " (" + str (_x select 2) + "cp)"];
} forEach _units;
lbSetCurSel [2100, 0];

// REQUEST SQUADS. Row indices are the argument fnc_request_squad and its FOB twin switch on,
// so the blank row that separates High Command from task forces is load-bearing padding: the
// two heavy sections a FOB cannot field are absent, which shifts every row below them.
switch (VERSION_X) do {
    case "MODERN": {
        lbAdd [2101, localize "STR_DUWS_T_zo6ih0pt"];               // 0
        lbAdd [2101, ""];                                           // 1
        lbAdd [2101, "HC " + (blufor_RECON_TEAM_X select 1)];       // 2
        lbAdd [2101, "HC " + (blufor_INF_SQUAD_X select 1)];        // 3
        lbAdd [2101, "HC " + (blufor_MOTOR_SECTION_X select 1)];    // 4
        if (!_isFob) then {
            lbAdd [2101, "HC " + (blufor_MECH_SECTION_X select 1)];  // 5
            lbAdd [2101, "HC " + (blufor_ARMOR_SECTION_X select 1)]; // 6
        };
        lbAdd [2101, ""];                                           // 7 at the HQ, 5 at a FOB
        lbAdd [2101, "TF " + (blufor_RECON_TEAM_X select 1)];
        lbAdd [2101, "TF " + (blufor_INF_SQUAD_X select 1)];
        lbAdd [2101, "TF " + (blufor_MOTOR_SECTION_X select 1)];
        lbAdd [2101, "TF " + (blufor_MECH_SECTION_X select 1)];
        lbAdd [2101, "TF " + (blufor_ARMOR_SECTION_X select 1)];
    };
};
lbSetCurSel [2101, 0];

// REQUEST VEHICLES-STATICS -- ten at a FOB against the HQ's full list.
lbAdd [2102, localize "STR_DUWS_T_zo6ih0pt"];   // 0
lbAdd [2102, ""];                               // 1

private _vehicles = ["VEHICLE"] call fnc_faction_rqst_list;
if (_isFob) then { _vehicles = _vehicles select [0, 10] };
{
    private _displayName = [configFile >> "CfgVehicles" >> (_x select 0)] call BIS_fnc_displayName;
    lbAdd [2102, _displayName + " (" + str (_x select 2) + "cp)"];
} forEach _vehicles;
lbSetCurSel [2102, 0];

[_site, _isFob] call fnc_base_menu_fill;

// A FOB buys no supports, so that half would be an empty box over a button that does nothing.
// The BASE list takes the width instead, measured off the hidden controls rather than restated
// as numbers, so a layout edit in request_menu.hpp carries through here.
if (_isFob) then {
    {
        _x params ["_hiddenIdc", "_wideIdc"];
        private _hidden = _display displayCtrl _hiddenIdc;
        private _ctrl = _display displayCtrl _wideIdc;
        private _pos = ctrlPosition _ctrl;
        _ctrl ctrlSetPosition [
            (ctrlPosition _hidden) select 0,
            _pos select 1,
            (_pos select 0) + (_pos select 2) - ((ctrlPosition _hidden) select 0),
            _pos select 3
        ];
        _ctrl ctrlCommit 0;
        _hidden ctrlShow false;
    } forEach [[1804, 1808], [2103, 2104], [1603, 1606]];
};

if (_isFob) exitWith {};

[] call fnc_support_list_fill;
