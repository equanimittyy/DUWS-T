// Locality: client -- an addAction function value, so it runs on whoever opens the menu.
/*
    fnc_request_menu.sqf
    The one request dialog, for the HQ and for every FOB. The FOB used to have a copy of this
    file and a copy of the layout with three listbox IDCs renamed; it differs in three things
    and no more: a shorter unit and vehicle list, a squad list without the heavy sections, and
    no supports at all.

    _this is the addAction argument array -- [target, caller, id, args] -- where args is [true]
    at a FOB. The target is the base the menu was opened on, which the command column needs: a
    redeploy rebuilds that base's garrison.

    Every global read here belongs to another file and reaches this one by broadcast, so each read
    falls back rather than naming the global bare. An SQF runtime error unwinds the whole script and
    `call` does not contain it, so one stale name in the fill takes down every section after it: the
    menu comes up with the lists below the fault empty, no command column and no supports, and only
    the RPT says why. A fallback keeps the rest of the menu standing and leaves the fault one row.
*/
if (!hasInterface) exitWith {};

private _site = _this param [0, objNull];
private _isFob = (_this param [3, []]) param [0, false];

private _display = createDialog ["ressourceheader", false];
if (isNull _display) exitWith {};

// Kept for fnc_request_map_view, which closes this dialog to show the map and rebuilds it after.
// uiNamespace because it is display state, and the mission namespace is written into save games.
uiNamespace setVariable ["DUWS_requestMenu_ctx", [_site, _isFob]];

// These three are drawn before any row is added, so they are the reads with the whole menu behind
// them. "--" is the honest answer for a pool whose value has not arrived: a defaulted 0 would read
// as an empty account.
ctrlSetText [1000, format ["%1", missionNamespace getVariable ["commandpointsblu1", "--"]]];
ctrlSetText [1001, format ["%1", missionNamespace getVariable ["zoneundercontrolblu", "--"]]];
ctrlSetText [1002, format ["%1", missionNamespace getVariable ["WARCOM_blufor_ap", "--"]]];

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
//
// A section's global is [roster, cost], written by server/init_hq/fnc_BLUFOR_squad_init.sqf. The
// name is menu text and lives here; the price is read live off that broadcast so the two cannot
// disagree. The shape is checked rather than assumed -- it has changed under this file before, and
// a section that fails the check has to keep its row anyway or every index below it shifts.
private _section = {
    params ["_prefix", "_nameKey", "_var"];
    private _def = missionNamespace getVariable [_var, []];
    if ((_def param [1, ""]) isEqualType 0) exitWith {
        format ["%1 %2 (%3cp)", _prefix, localize _nameKey, _def select 1]
    };
    ["WARN", "UI", format ["fnc_request_menu: %1 is %2, not [roster, cost]", _var, _def]] call fnc_log;
    format ["%1 %2 (n/a)", _prefix, localize _nameKey]
};

switch (VERSION_X) do {
    case "MODERN": {
        lbAdd [2101, localize "STR_DUWS_T_zo6ih0pt"];               // 0
        lbAdd [2101, ""];                                           // 1
        lbAdd [2101, ["HC", "STR_DUWS_T_SQUAD_RECON", "blufor_RECON_TEAM_X"] call _section];       // 2
        lbAdd [2101, ["HC", "STR_DUWS_T_SQUAD_INF", "blufor_INF_SQUAD_X"] call _section];          // 3
        lbAdd [2101, ["HC", "STR_DUWS_T_SQUAD_MOTOR", "blufor_MOTOR_SECTION_X"] call _section];    // 4
        if (!_isFob) then {
            lbAdd [2101, ["HC", "STR_DUWS_T_SQUAD_MECH", "blufor_MECH_SECTION_X"] call _section];  // 5
            lbAdd [2101, ["HC", "STR_DUWS_T_SQUAD_ARMOR", "blufor_ARMOR_SECTION_X"] call _section]; // 6
        };
        lbAdd [2101, ""];                                           // 7 at the HQ, 5 at a FOB
        lbAdd [2101, ["TF", "STR_DUWS_T_SQUAD_RECON", "blufor_RECON_TEAM_X"] call _section];
        lbAdd [2101, ["TF", "STR_DUWS_T_SQUAD_INF", "blufor_INF_SQUAD_X"] call _section];
        lbAdd [2101, ["TF", "STR_DUWS_T_SQUAD_MOTOR", "blufor_MOTOR_SECTION_X"] call _section];
        lbAdd [2101, ["TF", "STR_DUWS_T_SQUAD_MECH", "blufor_MECH_SECTION_X"] call _section];
        lbAdd [2101, ["TF", "STR_DUWS_T_SQUAD_ARMOR", "blufor_ARMOR_SECTION_X"] call _section];
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

[_display, _site, _isFob] call fnc_command_fill;

// Hidden rather than absent: the MISSIONS box is a fixed layout with nothing below to slide up.
if ((vehiclevarname player) != "player1") then {
    (_display displayCtrl 1607) ctrlShow false;
};

// A FOB buys no supports, so the strip goes entirely. The main window keeps its size.
if (_isFob) exitWith {
    { (_display displayCtrl _x) ctrlShow false } forEach [1804, 2103, 1603];
};

[] call fnc_support_list_fill;
