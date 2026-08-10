// Locality: client -- inherited from client/dialog/fnc_startup_closed.sqf.

// Raised while the screen fills itself in, and read by every LBSelChanged handler below:
// lbSetCurSel fires the same event a player's click does, so without this the act of
// preselecting the defaults would read as the player editing them. Set before the dialog
// exists, since the combos' own handlers are live from the moment it does.
duws_preset_applying = true;
if (isNil "duws_preset") then { duws_preset = "classic" };
// [idc, index] per combo, filled by _setDefault below and re-applied when a preset is chosen.
duws_enviro_defaults = [];

createDialog "startup_dialog";
waitUntil {dialog};

// Marks a combo's default entry with a localised "(Default)" suffix at runtime, not
// in the stringtable, so shared Yes/No labels stay unchanged elsewhere.
private _setDefault = {
    params ["_idc", "_i"];
    duws_enviro_defaults pushBack [_idc, _i];
    lbSetCurSel [_idc, _i];
    lbSetText [_idc, _i, (lbText [_idc, _i]) + " " + (localize "STR_DUWS_T_default_suffix")];
};

// WEATHER TYPE
index_weather_type_tropical = lbAdd [2100, localize "STR_DUWS_T_ex41rpdu"];
index_weather_type_arid = lbAdd [2100, localize "STR_DUWS_T_jf8jtvt7"];
index_weather_type_temperate = lbAdd [2100, localize "STR_DUWS_T_kpi5qxd0"];
index_weather_type_temperate_cold = lbAdd [2100, localize "STR_DUWS_T_jr6krtcn"];
index_weather_type_mediterranean = lbAdd [2100, localize "STR_DUWS_T_1777ggdk"];
index_weather_type_varied = lbAdd [2100, localize "STR_DUWS_T_pa387ndd"];
index_weather_type_disable = lbAdd [2100, localize "STR_DUWS_T_6dgte6s0"];
[2100, index_weather_type_disable] call _setDefault;

// TIME OF DAY
time_of_day_dawn = lbAdd [2101, localize "STR_DUWS_T_4hmx1wzd"];
time_of_day_noon = lbAdd [2101, localize "STR_DUWS_T_95vrzwsq"];
time_of_day_evening = lbAdd [2101, localize "STR_DUWS_T_pshlpqdy"];
time_of_day_midnite = lbAdd [2101, localize "STR_DUWS_T_wmhmoeqt"];
[2101, time_of_day_dawn] call _setDefault;

// CIVILIAN DENSITY
// option values: 5, 10, 15, 20 (default 15)
private _civDensityValues = [5, 10, 15, 20];
{
    private _index = lbAdd [2102, format ["%1", _x]];
    if (_x == 15) then { [2102, _index] call _setDefault; };
} forEach _civDensityValues;

// FOB FAST TRAVEL
index_fast_travel_true = lbAdd [2103, localize "STR_DUWS_T_x4zs3lsg2"];
index_fast_travel_false = lbAdd [2103, localize "STR_DUWS_T_x4zs3lsg1"];
[2103, index_fast_travel_true] call _setDefault;

// ZEUS PARAMS
index_zeus_params_full = lbAdd [2104, localize "STR_DUWS_T_m4bqnyut"];
index_zeus_params_blufor = lbAdd [2104, localize "STR_DUWS_T_nque25op"];
index_zeus_params_none = lbAdd [2104, localize "STR_DUWS_T_3i1vcc0n"];
[2104, index_zeus_params_blufor] call _setDefault;

// War escalation (replaces the old scorched-earth mode).
lbAdd [2106, localize "STR_DUWS_T_x4zs3lsg0"];
index_escalation_true = lbAdd [2106, localize "STR_DUWS_T_vk37aebo"];
[2106, index_escalation_true] call _setDefault;
// =========================================

// TIME MULITPLIER
index_timemult_1 = lbAdd [2107, "1x"];
index_timemult_2 = lbAdd [2107, "2x"];
index_timemult_4 = lbAdd [2107, "4x"];
index_timemult_8 = lbAdd [2107, "8x"];
index_timemult_16 = lbAdd [2107, "16x"];
index_timemult_24 = lbAdd [2107, "24x"];
index_timemult_32 = lbAdd [2107, "32x"];
index_timemult_60 = lbAdd [2107, "60x"];
[2107, index_timemult_1] call _setDefault;

// ENABLE SIMPLE ZONES
index_simpzones_false = lbAdd [2108, localize "STR_DUWS_T_x4zs3lsg0"];
index_simpzones_true = lbAdd [2108, localize "STR_DUWS_T_vk37aebo"];
[2108, index_simpzones_false] call _setDefault;

// ENABLE CIVILIANS
// Each row carries its CIV_PRESENCE value as item data rather than recording its index in a
// global: the game mode decides which rows exist, so an index means nothing outside the list it
// was added to. fnc_process_enviro_menu.sqf reads the value straight back off the row.
private _addCiv = {
    params ["_labelKey", "_value"];
    private _i = lbAdd [2109, localize _labelKey];
    lbSetData [2109, _i, _value];
    _i
};

// The apocalypse mode draws its crowd from the mod it names, so those two rows are the whole list
// and civilians cannot be turned off; every other mode gets the list without them.
if (duws_gamemode == "apocalypse") then {
    private _iRavage = ["STR_DUWS_T_ravage", "RAVAGE"] call _addCiv;
    private _iWbk = ["STR_DUWS_T_wbk", "WBK"] call _addCiv;
    lbSetColor [2109, _iRavage, [1,0,0,1]];
    lbSetColor [2109, _iWbk, [1,0,0,1]];
    [2109, _iRavage] call _setDefault;
} else {
    ["STR_DUWS_T_civoff", "NONE"] call _addCiv;
    switch (civ_mod) do {
        case "cup" : {
            ["STR_DUWS_T_CUPslfr", "CUPslav"] call _addCiv;
            ["STR_DUWS_T_CUPzdr", "CUPmeast"] call _addCiv;
            ["STR_DUWS_T_CUPslfrw", "CUPslavw"] call _addCiv;
            ["STR_DUWS_T_CUPzdrw", "CUPmeastw"] call _addCiv;
        };
        case "propfor" : {
            ["STR_DUWS_T_lez0jp04", "Pcoldeuro"] call _addCiv;
            ["STR_DUWS_T_wnfbjquf", "Pmideast"] call _addCiv;
            ["STR_DUWS_T_ycoll66i", "Pafrica"] call _addCiv;
        };
        case "cfp" : {
            ["STR_DUWS_T_uv3r9klr", "Ccoldeuro"] call _addCiv;
            ["STR_DUWS_T_fkysvpi4", "Cmideast"] call _addCiv;
            ["STR_DUWS_T_rlykfz31", "Cafghan"] call _addCiv;
            ["STR_DUWS_T_p7ahis16", "Cafrica"] call _addCiv;
        };
        case "Unsung" : {
            ["STR_DUWS_T_5kow9zoj", "Unsung"] call _addCiv;
        };
        case "ifa3" : {
            ["STR_DUWS_T_7yc3uncm", "IFA3"] call _addCiv;
        };
    };
    private _iMed = ["STR_DUWS_T_1777ggdk", "med"] call _addCiv;
    ["STR_DUWS_T_2j83vkge", "tanoa"] call _addCiv;
    ["STR_DUWS_T_c0v3wxlw", "Vafrica"] call _addCiv;
    ["STR_DUWS_T_be1dhnmv", "asia"] call _addCiv;
    ["STR_DUWS_T_3tbqvi73", "sumeuro"] call _addCiv;
    ["STR_DUWS_T_1777ggdkw", "MAX_WOMENm"] call _addCiv;
    ["STR_DUWS_T_2j83vkgew", "MAX_WOMENt"] call _addCiv;
    ["STR_DUWS_T_be1dhnmvw", "MAX_WOMENa"] call _addCiv;
    ["STR_DUWS_T_3tbqvi73w", "MAX_WOMENs"] call _addCiv;

    [2109, _iMed] call _setDefault;
};

// ENABLE HARDCORE MODE
index_hardcore_false = lbAdd [2110, localize "STR_DUWS_T_x4zs3lsg0"];
index_hardcore_true = lbAdd [2110, localize "STR_DUWS_T_vk37aebo"];
[2110, index_hardcore_false] call _setDefault;

// Restore selections when returning here via the campaign screen's Back button. The combos are no
// longer a contiguous 2100-range, so the restore zips stored values against an explicit idc list
// that MUST stay in lockstep with the snapshot in fnc_process_enviro_menu.sqf.
if (!isNil "duws_enviro_sel") then {
    private _idcs = [2100,2101,2102,2103,2104,2106,2107,2108,2109,2110];
    { lbSetCurSel [_idcs select _forEachIndex, _x]; } forEach duws_enviro_sel;
};

// PRESET
// Filled last so the row reflects whatever the restore above ended on: a player who came back
// from the campaign screen having changed something there is already on Custom.
duws_preset_classic = lbAdd [2200, localize "STR_DUWS_T_preset_classic"];
duws_preset_custom = lbAdd [2200, localize "STR_DUWS_T_preset_custom"];
lbSetCurSel [2200, [duws_preset_classic, duws_preset_custom] select (duws_preset == "custom")];

// Attached from here rather than declared per combo in the dialog config, so that filling the
// combos above -- twelve preselections and a restore, all of which raise LBSelChanged -- cannot
// trip them before the screen is ready.
private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
{
    (_display displayCtrl _x) ctrlAddEventHandler ["LBSelChanged", {
        if (duws_preset_applying) exitWith {};
        lbSetCurSel [2200, duws_preset_custom];
    }];
} forEach [2100,2101,2102,2103,2104,2106,2107,2108,2109,2110];

duws_preset_applying = false;
// Writes the description line under the row. Re-applies the preset too, which is a no-op:
// Classic is the defaults every combo above already holds, and Custom changes nothing at all.
[] call fnc_startup_preset_apply;
