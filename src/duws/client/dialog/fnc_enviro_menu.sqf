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

// ENABLE SIMPLE ZONES
index_simpzones_false = lbAdd [2108, localize "STR_DUWS_T_x4zs3lsg0"];
index_simpzones_true = lbAdd [2108, localize "STR_DUWS_T_vk37aebo"];
[2108, index_simpzones_false] call _setDefault;

// MORE URBAN
index_more_urban_yes = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg2"];
index_more_urban_no = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg1"];
[2105, index_more_urban_yes] call _setDefault;

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

// Adds a row only when every body model it needs is present, so a set backed by a mod or DLC that
// is not loaded never appears as a dead choice that would spawn nothing. Probes are the lead models
// the set draws from in CIV_FACTIONS.sqf, so a hidden row could not have filled anyway.
private _addCivIf = {
    params ["_labelKey", "_value", "_probes"];
    if (_probes findIf { !isClass (configFile >> "CfgVehicles" >> _x) } != -1) exitWith { -1 };
    [_labelKey, _value] call _addCiv
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
    // Every set is offered only when the body models it draws from are loaded, so the list shows
    // exactly what this install can spawn. One presence check per set replaces the old civ_mod
    // switch, which both left CUP/CFP/propfor sets ungated at the tail and could never reach the
    // Unsung/IFA3 cases (civ_mod detection only ever sets vanilla/cup/propfor/cfp). Probes are lead
    // models from CIV_FACTIONS.sqf; a mixed CUP+CFP set probes a CFP class so CUP alone won't pass.
    // NONE and med carry none: Off is always offered and med is vanilla base classes, the default.
    private _civSets = [
        ["STR_DUWS_T_civoff",    "NONE",       []],
        ["STR_DUWS_T_1777ggdk",  "med",        []],
        ["STR_DUWS_T_2j83vkge",  "tanoa",      ["C_Man_casual_4_F_tanoan"]],
        ["STR_DUWS_T_c0v3wxlw",  "Vafrica",    ["C_man_p_beggar_F_afro"]],
        ["STR_DUWS_T_be1dhnmv",  "asia",       ["C_man_p_beggar_F_asia"]],
        ["STR_DUWS_T_3tbqvi73",  "sumeuro",    ["C_Man_1_enoch_F"]],
        ["STR_DUWS_T_1777ggdkw", "MAX_WOMENm", ["Max_woman1"]],
        ["STR_DUWS_T_2j83vkgew", "MAX_WOMENt", ["Max_woman1", "C_Man_casual_4_F_tanoan"]],
        ["STR_DUWS_T_be1dhnmvw", "MAX_WOMENa", ["Max_woman1", "C_man_p_beggar_F_asia"]],
        ["STR_DUWS_T_3tbqvi73w", "MAX_WOMENs", ["Max_woman1", "C_Man_1_enoch_F"]],
        ["STR_DUWS_T_CUPslfr",   "CUPslav",    ["CUP_C_C_Bully_01"]],
        ["STR_DUWS_T_CUPzdr",    "CUPmeast",   ["CUP_C_TK_Man_01"]],
        ["STR_DUWS_T_CUPslfrw",  "CUPslavw",   ["CUP_C_C_Bully_01", "Max_woman1"]],
        ["STR_DUWS_T_CUPzdrw",   "CUPmeastw",  ["CUP_C_TK_Man_01", "Max_Tak_woman1"]],
        ["STR_DUWS_T_uv3r9klr",  "Ccoldeuro",  ["CFP_C_CHERNO_WIN_Civilian_02"]],
        ["STR_DUWS_T_fkysvpi4",  "Cmideast",   ["CFP_C_ME_Civ_2_01"]],
        ["STR_DUWS_T_rlykfz31",  "Cafghan",    ["CFP_C_AFG_Civilian_02"]],
        ["STR_DUWS_T_p7ahis16",  "Cafrica",    ["CFP_C_AFRCHRISTIAN_Civ_8_01"]],
        ["STR_DUWS_T_lez0jp04",  "Pcoldeuro",  ["LOP_CHR_Civ_Citizen_03"]],
        ["STR_DUWS_T_wnfbjquf",  "Pmideast",   ["LOP_Tak_Civ_Man_06"]],
        ["STR_DUWS_T_ycoll66i",  "Pafrica",    ["LOP_AFR_Civ_Man_01"]],
        ["STR_DUWS_T_5kow9zoj",  "Unsung",     ["uns_civilian1"]],
        ["STR_DUWS_T_7yc3uncm",  "IFA3",       ["LIB_CIV_Citizen_1"]]
    ];
    private _iMed = -1;
    {
        private _i = _x call _addCivIf;
        if ((_x select 1) == "med") then { _iMed = _i };
    } forEach _civSets;

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
    private _idcs = [2100,2101,2102,2103,2104,2105,2106,2108,2109,2110];
    { lbSetCurSel [_idcs select _forEachIndex, _x]; } forEach duws_enviro_sel;
};

// PRESET
// Filled last so the row reflects whatever the restore above ended on: a player who came back
// from the campaign screen having changed something there is already on Custom.
duws_preset_classic = lbAdd [2200, localize "STR_DUWS_T_preset_classic"];
duws_preset_hardcore = lbAdd [2200, localize "STR_DUWS_T_preset_hardcore"];
duws_preset_custom = lbAdd [2200, localize "STR_DUWS_T_preset_custom"];
lbSetCurSel [2200, switch (duws_preset) do {
    case "hardcore": { duws_preset_hardcore };
    case "custom": { duws_preset_custom };
    default { duws_preset_classic };
}];

// Attached from here rather than declared per combo in the dialog config, so that filling the
// combos above -- twelve preselections and a restore, all of which raise LBSelChanged -- cannot
// trip them before the screen is ready.
private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
{
    (_display displayCtrl _x) ctrlAddEventHandler ["LBSelChanged", {
        if (duws_preset_applying) exitWith {};
        lbSetCurSel [2200, duws_preset_custom];
    }];
} forEach [2100,2101,2102,2103,2104,2105,2106,2108,2109,2110];

duws_preset_applying = false;
// Writes the description line under the row. Re-applies the preset too, which is a no-op:
// Classic is the defaults every combo above already holds, and Custom changes nothing at all.
[] call fnc_startup_preset_apply;
