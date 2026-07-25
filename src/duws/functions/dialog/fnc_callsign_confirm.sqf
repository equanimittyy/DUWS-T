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

// Apocalypse and civilian init fire here, at final commit, rather than between the
// setup screens -- otherwise stepping Back and re-confirming would re-run them:
// apocalypse re-scans the whole map, and civ init would lock in a stale faction.
if (apocalypse_mode) then {
    if (isServer) then {
        [] spawn fnc_apocalypse_buildings;
    } else {
        [] remoteExec ["fnc_apocalypse_buildings", 2];
    };
};
if (!isNil "CIV_PRESENCE" && {CIV_PRESENCE != "NONE"}) then {
    [] remoteExec ["fnc_civ_init_Tomata", 2];
} else {
    // Civilians off: no ambient population, but PMC/partisan hiring still needs civ_array as a body pool.
    [] remoteExec ["fnc_civ_setup_array", 2];
};

// TELL WARCOM THE ZONE VARIABLES ARE SET
createzone_server = true;
publicVariable "createzone_server";

// Give the go! WARCOM can continue execution
chosen_settings = true;publicVariable "chosen_settings";

diag_log format["----- DUWS_T CHOSEN SETTINGS --------- Callsign: %10-------Manual zones: %11-------Max radius: %1-------Min radius: %2-------Zones number: %3-------Command points: %4-------BLU AP: %5-------OPF AP: %6-------Weather type: %7-------BLU AI skill: %8-------OPF AI skill: %9",zones_max_radius,zones_min_radius,zones_number,commandpointsblu1,WARCOM_opfor_ap,WARCOM_blufor_ap,weather_type,blufor_ai_skill,opfor_ai_skill,duws_callsign,manually_chosen];
