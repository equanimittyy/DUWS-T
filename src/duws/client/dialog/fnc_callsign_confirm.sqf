// Locality: client -- invoked from a dialog action.
// Callsign screen (startup_dialog3) START-R / START-M -> lock in the squad callsign
// and commit the campaign with the chosen zone-placement mode (_manual: false = random
// zones, true = hand-placed). This is the single final-commit point for the whole
// setup flow: everything gated on chosen_settings / createzone_server starts here.
params [["_manual", false]];
manually_chosen = _manual;publicVariable "manually_chosen";

// Read the callsign before closeDialog while the edit control still exists; a blank
// entry falls back to the default so fnc_cs never substitutes an empty string.
private _typed = ctrlText 1400;
duws_callsign = if (_typed != "") then {_typed} else {"Alpha 1-1"};
publicVariable "duws_callsign";
closeDialog 0;

// Manual zone placement: prompt the player to place zones as the campaign starts.
if (manually_chosen) then {
    [{hint localize "STR_DUWS_T_2amacebc"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
};

// Apocalypse fires here, at final commit, rather than between the setup screens --
// otherwise stepping Back and re-confirming would re-run its whole-map rescan.
if (apocalypse_mode) then {
    if (isServer) then {
        [] spawn fnc_apocalypse_buildings;
    } else {
        [] remoteExec ["fnc_apocalypse_buildings", 2];
    };
};
// Only the civilians-off case is handled here. With civilians on, generation is kicked off
// from fnc_init_OPFOR_WARCOM once zone build-out finishes, because the towns are selected
// from the zones and cannot be chosen before they exist.
if (isNil "CIV_PRESENCE" || {CIV_PRESENCE == "NONE"}) then {
    // Civilians off: no ambient population, but PMC/partisan hiring still needs civ_array as a body pool.
    [] remoteExec ["fnc_civ_setup_array", 2];
};

// TELL WARCOM THE ZONE VARIABLES ARE SET
createzone_server = true;
publicVariable "createzone_server";

// Give the go! WARCOM can continue execution
chosen_settings = true;publicVariable "chosen_settings";

// Full setup snapshot, one key=value per line so two runs can be diffed directly. A single
// packed line cannot carry the settings that drive generation cost -- max distance, urban
// filter, AO arc, zone spacing -- which is exactly what you need when comparing a fast run
// against a slow one.
{
    ["INFO", "SETUP", format ["%1 = %2", _x,
        (if (isNil _x) then {"<nil>"} else {missionNamespace getVariable _x})]] call fnc_log;
} forEach [
    "VERSION_X", "duws_callsign", "manually_chosen",
    "zones_number", "zones_max_radius", "zones_min_radius", "zones_spacing",
    "zones_max_dist_from_hq", "moreUrban", "AO_direction", "PosOfBLUHQ",
    "BLUFOR_Faction_X", "OPFOR_Faction_X",
    "commandpointsblu1", "WARCOM_blufor_ap", "WARCOM_opfor_ap", "cp_reward_multiplier",
    "DUWSMP_CP_death_cost", "blufor_ai_skill", "opfor_ai_skill", "enemyunitMultiplier",
    "HeavyArmor", "AttackHeli",
    "weather_type", "dynamic_weather_enable", "restricted_arsenal", "scorched_earth_enabled",
    "hardcore_mode_enable", "insurgent_mode_enable", "enable_fast_travel",
    "CIV_PRESENCE", "ZeusStatus", "time_of_day", "time_Multiplier", "player_fatigue"
];
