// Locality: client -- invoked from a dialog action.
// Snapshot selections so the campaign screen's Back button can restore them.
// Must read before closeDialog while the controls still exist.
duws_enviro_sel = [2100,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111] apply { lbCurSel _x };

closeDialog 0;

// Weather type
_index = lbCurSel 2100;
switch (_index) do
{
    case index_weather_type_tropical:
    {
        weather_type = "tropical";
    };
    case index_weather_type_arid:
    {
        weather_type = "arid";
    };
    case index_weather_type_temperate:
    {
        weather_type = "temperate";
    };
    case index_weather_type_temperate_cold:
    {
        weather_type = "temperate_cold";
    };
    case index_weather_type_mediterranean:
    {
        weather_type = "mediterranean";
    };
    case index_weather_type_varied:
    {
        weather_type = "varied";
    };
    case index_weather_type_disable:
    {
        dynamic_weather_enable = false;
    };
};

// TIME OF DAY
_index = lbCurSel 2101;
switch (_index) do {
    case time_of_day_dawn:{ time_of_day = 6; };
    case time_of_day_noon:{ time_of_day = 12; };
    case time_of_day_evening:{ time_of_day = 18; };
    case time_of_day_midnite:{ time_of_day = 0; };
};

// CIVILIAN MAX SPAWN PER VISIT
private _civSpawnValues = [5, 10, 20, 35, 50, 65, 80];
private _index = lbCurSel 2102;
private _selectedValue = 35; // 默认
if (_index >= 0 && _index < count _civSpawnValues) then {
    _selectedValue = _civSpawnValues select _index;
};
missionNamespace setVariable ["civ_maxSpawnPerVisit", _selectedValue, true];
diag_log format ["[ENVIRO] Civ max spawn per visit set to: %1", _selectedValue];

// FAST TRAVEL
_index = lbCurSel 2103;
switch (_index) do
{
    case index_fast_travel_false: { enable_fast_travel = false; };
    case index_fast_travel_true: { enable_fast_travel = true; };
};

// ZEUS PARAMS
_index = lbCurSel 2104;
switch (_index) do
{
    case index_zeus_params_full: { ZeusStatus = 2; };
    case index_zeus_params_blufor: { ZeusStatus = 1; };
    case index_zeus_params_none: { ZeusStatus = 0; };
};

// APOCALYPSE MODE
_index = lbCurSel 2105;
switch (_index) do
{
    case index_apocalypse_true: { apocalypse_mode = true; };
    case index_apocalypse_false: { apocalypse_mode = false; };
};
publicVariable "apocalypse_mode";

// ========== 焦土模式 ==========
_index = lbCurSel 2106;
scorched_earth_enabled = (_index == index_scorched_earth_true);
publicVariable "scorched_earth_enabled";

// ENABLE TIME MULTI
_index = lbCurSel 2107;
switch (_index) do
{
    case index_timemult_1: { time_Multiplier = 1; };
    case index_timemult_2: { time_Multiplier = 2; };
    case index_timemult_4: { time_Multiplier = 4; };
    case index_timemult_8: { time_Multiplier = 8; };
    case index_timemult_16: { time_Multiplier = 16; };
    case index_timemult_24: { time_Multiplier = 24; };
    case index_timemult_32: { time_Multiplier = 32; };
    case index_timemult_60: { time_Multiplier = 60; };
};

// ENABLE SIMPLE ZONES
_index = lbCurSel 2108;
switch (_index) do
{
    case index_simpzones_false: { simple_zones_enable = false; };
    case index_simpzones_true: { simple_zones_enable = true; };
};

// ENABLE CIVILIANS
_index = lbCurSel 2109;
switch (_index) do
{
    case index_civtype_off: { CIV_PRESENCE = "NONE"; };
    case index_civtype_med: { CIV_PRESENCE = "med"; };
    case index_civtype_tanoa: { CIV_PRESENCE = "tanoa"; };
    case index_civtype_Vafrica: { CIV_PRESENCE = "Vafrica"; };
    case index_civtype_asia: { CIV_PRESENCE = "asia"; };
    case index_civtype_sumeuro: { CIV_PRESENCE = "sumeuro"; };
    if (civ_mod == "cup") then {
        case index_civtype_CUPslav: { CIV_PRESENCE = "CUPslav"; };
        case index_civtype_CUPmeast: { CIV_PRESENCE = "CUPmeast"; };
        case index_civtype_CUPslavw: { CIV_PRESENCE = "CUPslavw"; };
        case index_civtype_CUPmeastw: { CIV_PRESENCE = "CUPmeastw"; };
    };
    if (civ_mod == "propfor") then {
        case index_civtype_Pcoldeuro: { CIV_PRESENCE = "Pcoldeuro"; };
        case index_civtype_Pmideast: { CIV_PRESENCE = "Pmideast"; };
        case index_civtype_Pafrica: { CIV_PRESENCE = "Pafrica"; };
    };
    if (civ_mod == "cfp") then {
        case index_civtype_Ccoldeuro: { CIV_PRESENCE = "Ccoldeuro"; };
        case index_civtype_Cmideast: { CIV_PRESENCE = "Cmideast"; };
        case index_civtype_Cafghan: { CIV_PRESENCE = "Cafghan"; };
        case index_civtype_Cafrica: { CIV_PRESENCE = "Cafrica"; };
    };
    if (civ_mod == "unsung") then {
        case index_civtype_Unsung: { CIV_PRESENCE = "Unsung"; };
    };
    if (civ_mod == "ifa3") then {
        case index_civtype_IFA3: { CIV_PRESENCE = "IFA3"; };
    };
    case (missionNamespace getVariable ["index_civtype_ravage", -1]): { CIV_PRESENCE = "RAVAGE"; };
    case (missionNamespace getVariable ["index_civtype_wbk", -1]): { CIV_PRESENCE = "WBK"; };
    case (missionNamespace getVariable ["index_civtype_medw", -1]): { CIV_PRESENCE = "MAX_WOMENm"; };
    case (missionNamespace getVariable ["index_civtype_tanoaw", -1]): { CIV_PRESENCE = "MAX_WOMENt"; };
    case (missionNamespace getVariable ["index_civtype_asiaw", -1]): { CIV_PRESENCE = "MAX_WOMENa"; };
    case (missionNamespace getVariable ["index_civtype_sumeurow", -1]): { CIV_PRESENCE = "MAX_WOMENs"; };
};

// ENABLE HARDCORE MODE
_index = lbCurSel 2110;
switch (_index) do
{
    case index_hardcore_false: { hardcore_mode_enable = false; publicVariable "hardcore_mode_enable"; };
    case index_hardcore_true: { hardcore_mode_enable = true; publicVariable "hardcore_mode_enable"; hardcore_visibleZone_found = false; publicVariable "hardcore_visibleZone_found"; };
};

// 始终启用限制军火库
restricted_arsenal = true;

publicVariable "weather_type";
publicVariable "time_of_day";
publicVariable "enable_fast_travel";
publicVariable "ZeusStatus";
publicVariable "time_Multiplier";
publicVariable "simple_zones_enable";
publicVariable "CIV_PRESENCE";
publicVariable "restricted_arsenal";

// 叛军模式
_index = lbCurSel 2111;
switch (_index) do
{
    case index_insurgent_off: { insurgent_mode_enable = false; };
    case index_insurgent_on: { insurgent_mode_enable = true; };
};
publicVariable "insurgent_mode_enable";

// OPEN THE NEXT MENU
[] spawn fnc_campaign_menu;