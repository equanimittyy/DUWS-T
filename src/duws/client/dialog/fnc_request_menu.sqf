// Locality: client -- an addAction function value, so it runs on whoever opens the menu.
/*
    The one request dialog, for the HQ and for every FOB. A FOB differs from the HQ in three things
    and no more: a shorter unit and vehicle list, a squad list without the heavy sections, and no
    supports at all.

    _this is the addAction argument array -- [target, caller, id, args] -- where args is [true] at a
    FOB. The target is the base the menu was opened on, which the command column needs: a redeploy
    rebuilds that base's garrison.

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

// REQUEST SQUADS. High Command first, then task forces. The section token "<HC|TF>:<type>" rides in
// lbData rather than the row index the handlers once switched on: a tier-locked squad drops to the
// bottom of its section, so the position no longer names it. A section's [roster, cost] global is read
// live so the menu price cannot drift from the spawn; the catalogue and tiers are DUWS_blufor_squads.
switch (VERSION_X) do {
    case "MODERN": {
        lbAdd [2101, localize "STR_DUWS_T_zo6ih0pt"];   // heading
        lbAdd [2101, ""];                               // spacer

        private _addSquad = {
            params ["_label", "_data", "_unlocked"];
            private _i = lbAdd [2101, _label];
            lbSetData [2101, _i, _data];
            if (!_unlocked) then { lbSetColor [2101, _i, [0.5, 0.5, 0.5, 1]] };
        };
        // Locked squads drop to the bottom of their section, the ascending-capability order kept in
        // both halves. The [roster, cost] shape is checked, not assumed -- it has changed before -- and
        // a section that fails keeps its row labelled (n/a) rather than vanishing.
        private _fillSquads = {
            params ["_prefix", "_types"];
            private _open = [];
            private _locked = [];
            {
                private _row = [_x] call DUWS_fnc_squadRow;
                if !(_row isEqualTo []) then {
                    _row params ["_type", "_globalName", "", "_labelKey", "_tier"];
                    private _squad = missionNamespace getVariable [_globalName, []];
                    private _costOk = (_squad param [1, ""]) isEqualType 0;
                    if (!_costOk) then {
                        ["WARN", "UI", format ["fnc_request_menu: %1 is not [roster, cost]", _globalName]] call fnc_log;
                    };
                    private _costTxt = if (_costOk) then { str (_squad select 1) } else { "n/a" };
                    private _unlocked = ["BLU", _tier] call DUWS_fnc_ap_unlocked;
                    private _label = format ["%1 %2 (%3cp)", _prefix, localize _labelKey, _costTxt];
                    if (!_unlocked) then { _label = _label + " " + format [localize "STR_DUWS_T_tier_tag", [_tier] call DUWS_fnc_tierName] };
                    private _entry = [_label, _prefix + ":" + _type, _unlocked];
                    if (_unlocked) then { _open pushBack _entry } else { _locked pushBack _entry };
                };
            } forEach _types;
            { _x call _addSquad } forEach (_open + _locked);
        };

        // A FOB fields the light High Command squads only; task forces are unchanged.
        private _hcTypes = if (_isFob) then { ["Recon", "Inf", "Motor"] } else { ["Recon", "Inf", "Motor", "Mech", "Armor"] };
        ["HC", _hcTypes] call _fillSquads;
        lbAdd [2101, ""];   // spacer between High Command and task forces
        ["TF", ["Recon", "Inf", "Motor", "Mech", "Armor"]] call _fillSquads;
    };
};
lbSetCurSel [2101, 0];

// REQUEST VEHICLES-STATICS -- ten at a FOB against the HQ's full list. Rows are gated on the BLUFOR
// AP ladder: a locked one stays, greyed and tier-tagged, sorted below the unlocked. The faction-list
// index rides in lbData because the sort breaks the position the handler once read off lbCurSel.
lbAdd [2102, localize "STR_DUWS_T_zo6ih0pt"];   // 0
lbAdd [2102, ""];                               // 1

private _vehicles = ["VEHICLE"] call fnc_faction_rqst_list;
if (_isFob) then { _vehicles = _vehicles select [0, 10] };
private _vehRows = [];
{
    private _class = _x select 0;
    private _displayName = [configFile >> "CfgVehicles" >> _class] call BIS_fnc_displayName;
    private _tier = [_class] call DUWS_fnc_vehTier;
    _vehRows pushBack [
        _displayName + " (" + str (_x select 2) + "cp)",
        _tier,
        ["BLU", _tier] call DUWS_fnc_ap_unlocked,
        str _forEachIndex
    ];
} forEach _vehicles;
[2102, _vehRows] call DUWS_fnc_tierListFill;
lbSetCurSel [2102, 0];

// Mission Timers is a fixed button rather than a command slot, so its Game Master gate has to hide
// the control: a player without it sees the quarter of the row empty rather than the row close up.
if !((vehiclevarname player) in (missionNamespace getVariable ["game_master", []])) then {
    (_display displayCtrl 1609) ctrlShow false;
};

[_display, _site, _isFob] call fnc_command_fill;

// A FOB buys no supports, so the strip goes entirely. The main window keeps its size.
if (_isFob) exitWith {
    { (_display displayCtrl _x) ctrlShow false } forEach [1804, 2103, 1603];
};

[] call fnc_support_list_fill;
