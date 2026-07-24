_handle = createDialog "startup_dialog";
waitUntil {dialog};

// WEATHER TYPE
index_weather_type_tropical = lbAdd [2100, localize "STR_DUWS_T_ex41rpdu"];
index_weather_type_arid = lbAdd [2100, localize "STR_DUWS_T_jf8jtvt7"];
index_weather_type_temperate = lbAdd [2100, localize "STR_DUWS_T_kpi5qxd0"];
index_weather_type_temperate_cold = lbAdd [2100, localize "STR_DUWS_T_jr6krtcn"];
index_weather_type_mediterranean = lbAdd [2100, localize "STR_DUWS_T_1777ggdk"];
index_weather_type_varied = lbAdd [2100, localize "STR_DUWS_T_pa387ndd"];
index_weather_type_disable = lbAdd [2100, localize "STR_DUWS_T_6dgte6s0"];
lbSetCurSel [2100, index_weather_type_disable];

// TIME OF DAY
time_of_day_dawn = lbAdd [2101, localize "STR_DUWS_T_4hmx1wzd"];
time_of_day_noon = lbAdd [2101, localize "STR_DUWS_T_95vrzwsq"];
time_of_day_evening = lbAdd [2101, localize "STR_DUWS_T_pshlpqdy"];
time_of_day_midnite = lbAdd [2101, localize "STR_DUWS_T_wmhmoeqt"];
lbSetCurSel [2101, time_of_day_dawn];

// CIVILIAN MAX SPAWN PER VISIT
// 选项值：20, 35, 50, 65, 80，默认 35
private _civSpawnValues = [20, 35, 50, 65, 80];
{
    private _index = lbAdd [2102, format ["%1", _x]];
    if (_x == 35) then { lbSetCurSel [2102, _index]; };
} forEach _civSpawnValues;

// FOB FAST TRAVEL
index_fast_travel_true = lbAdd [2103, localize "STR_DUWS_T_x4zs3lsg2"];
index_fast_travel_false = lbAdd [2103, localize "STR_DUWS_T_x4zs3lsg1"];
lbSetCurSel [2103, index_fast_travel_true];

// ZEUS PARAMS
index_zeus_params_full = lbAdd [2104, localize "STR_DUWS_T_m4bqnyut"];
index_zeus_params_blufor = lbAdd [2104, localize "STR_DUWS_T_nque25op"];
index_zeus_params_none = lbAdd [2104, localize "STR_DUWS_T_3i1vcc0n"];
lbSetCurSel [2104, index_zeus_params_blufor];

// APOCALYPSE MODE
index_apocalypse_true = lbAdd [2105, localize "STR_DUWS_T_vk37aebo"];
index_apocalypse_false = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg0"];
lbSetCurSel [2105, index_apocalypse_false];

// ========== 焦土模式（替换 VCOM） ==========
index_scorched_earth_false = lbAdd [2106, localize "STR_DUWS_T_x4zs3lsg0"];
index_scorched_earth_true = lbAdd [2106, localize "STR_DUWS_T_vk37aebo"];
lbSetCurSel [2106, index_scorched_earth_false];
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
lbSetCurSel [2107, index_timemult_1];

// ENABLE SIMPLE ZONES
index_simpzones_false = lbAdd [2108, localize "STR_DUWS_T_x4zs3lsg0"];
index_simpzones_true = lbAdd [2108, localize "STR_DUWS_T_vk37aebo"];
lbSetCurSel [2108, index_simpzones_false];

// ENABLE CIVILIANS
index_civtype_off = lbAdd [2109, localize "STR_DUWS_T_civoff"];
switch (civ_mod) do {
    case "cup" : {
        index_civtype_CUPslav = lbAdd [2109, localize "STR_DUWS_T_CUPslfr"];
        index_civtype_CUPmeast = lbAdd [2109, localize "STR_DUWS_T_CUPzdr"];
        index_civtype_CUPslavw = lbAdd [2109, localize "STR_DUWS_T_CUPslfrw"];
        index_civtype_CUPmeastw = lbAdd [2109, localize "STR_DUWS_T_CUPzdrw"];
    };
    case "propfor" : {
        index_civtype_Pcoldeuro = lbAdd [2109, localize "STR_DUWS_T_lez0jp04"];
        index_civtype_Pmideast = lbAdd [2109, localize "STR_DUWS_T_wnfbjquf"];
        index_civtype_Pafrica = lbAdd [2109, localize "STR_DUWS_T_ycoll66i"];
    };
    case "cfp" : {
        index_civtype_Ccoldeuro = lbAdd [2109, localize "STR_DUWS_T_uv3r9klr"];
        index_civtype_Cmideast = lbAdd [2109, localize "STR_DUWS_T_fkysvpi4"];
        index_civtype_Cafghan = lbAdd [2109, localize "STR_DUWS_T_rlykfz31"];
        index_civtype_Cafrica = lbAdd [2109, localize "STR_DUWS_T_p7ahis16"];
    };
    case "Unsung" : {
        index_civtype_Unsung = lbAdd [2109, localize "STR_DUWS_T_5kow9zoj"];
    };
    case "ifa3" : {
        index_civtype_IFA3 = lbAdd [2109, localize "STR_DUWS_T_7yc3uncm"];
    };
};
index_civtype_med = lbAdd [2109, localize "STR_DUWS_T_1777ggdk"];
index_civtype_tanoa = lbAdd [2109, localize "STR_DUWS_T_2j83vkge"];
index_civtype_Vafrica = lbAdd [2109, localize "STR_DUWS_T_c0v3wxlw"];
index_civtype_asia = lbAdd [2109, localize "STR_DUWS_T_be1dhnmv"];
index_civtype_sumeuro = lbAdd [2109, localize "STR_DUWS_T_3tbqvi73"];
index_civtype_medw = lbAdd [2109, localize "STR_DUWS_T_1777ggdkw"];
missionNamespace setVariable ["index_civtype_medw", index_civtype_medw];
index_civtype_tanoaw = lbAdd [2109, localize "STR_DUWS_T_2j83vkgew"];
missionNamespace setVariable ["index_civtype_tanoaw", index_civtype_tanoaw];
index_civtype_asiaw = lbAdd [2109, localize "STR_DUWS_T_be1dhnmvw"];
missionNamespace setVariable ["index_civtype_asiaw", index_civtype_asiaw];
index_civtype_sumeurow = lbAdd [2109, localize "STR_DUWS_T_3tbqvi73w"];
missionNamespace setVariable ["index_civtype_sumeurow", index_civtype_sumeurow];
_index_ravage = lbAdd [2109, localize "STR_DUWS_T_ravage"];
_index_wbk = lbAdd [2109, localize "STR_DUWS_T_wbk"];
lbSetColor [2109, _index_wbk, [1,0,0,1]];
missionNamespace setVariable ["index_civtype_wbk", _index_wbk];
lbSetColor [2109, _index_ravage, [1,0,0,1]];
missionNamespace setVariable ["index_civtype_ravage", _index_ravage];

lbSetCurSel [2109, index_civtype_off];

// ENABLE HARDCORE MODE
index_hardcore_false = lbAdd [2110, localize "STR_DUWS_T_x4zs3lsg0"];
index_hardcore_true = lbAdd [2110, localize "STR_DUWS_T_vk37aebo"];
lbSetCurSel [2110, index_hardcore_false];

// 原来的限制军火库代码替换为叛军模式
index_insurgent_off = lbAdd [2111, localize "STR_DUWS_T_insoff"];
index_insurgent_on = lbAdd [2111, localize "STR_DUWS_T_inson"];
lbSetCurSel [2111, index_insurgent_off];
// 将两个选项的文字颜色设为红色
lbSetColor [2111, index_insurgent_off, [1,0,0,1]];
lbSetColor [2111, index_insurgent_on, [1,0,0,1]];

// Restore selections when returning here via the campaign screen's Back button.
if (!isNil "duws_enviro_sel") then {
    { lbSetCurSel [2100 + _forEachIndex, _x]; } forEach duws_enviro_sel;
};