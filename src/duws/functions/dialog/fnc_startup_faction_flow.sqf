// Faction + HQ placement -> custom-faction paste (if any) -> environment menu.
// Runs on first setup (from client_init) and whenever the environment screen's
// Back button routes back here to re-pick faction and HQ.
//
// Reset the placement-state flags first: on a re-entry they are still set from
// the previous run, and fnc_HQ_faction_dialog's waits (player_is_choosing_hqpos
// / chosen_hq_placement) would otherwise short-circuit and skip placement. Kept
// client-local (no publicVariable) so the server's already-satisfied
// chosen_hq_placement gate is not disturbed.
chosen_hq_placement = false;
player_is_choosing_hqpos = false;
random_placement = false;
duws_custom_faction_back = false;   // set by the paste screen's Back button

[] call fnc_HQ_faction_dialog;
waitUntil {sleep 0.1; chosen_hq_placement};

// Custom factions: clear the pasted-data holders so the flow waits for a fresh
// paste. On a re-entry they'd still hold the previous run's text and the wait
// would fall through instantly, skipping the paste dialog.
if (BLUFOR_Faction_X == "CUSTOM" || OPFOR_Faction_X == "CUSTOM") then {
    BLUfactionDataTemp = ""; publicVariable "BLUfactionDataTemp";
    OPFfactionDataTemp = ""; publicVariable "OPFfactionDataTemp";
    createDialog "startup_faction";
    waitUntil {dialog};

    // Wait until every CUSTOM side has non-empty data (the submit handler rejects
    // blanks, so this can't fall through on empty input) or the player hits Back.
    waitUntil {
        sleep 0.1;
        duws_custom_faction_back
        || { (BLUFOR_Faction_X != "CUSTOM" || {BLUfactionDataTemp != ""})
             && {OPFOR_Faction_X != "CUSTOM" || {OPFfactionDataTemp != ""}} }
    };
};

// Back from the paste screen restarts the whole faction/HQ selection.
if (duws_custom_faction_back) exitWith { [] spawn fnc_startup_faction_flow; };

// AutoDetect factions: run the interactive picker here so it lands during setup,
// not after START. Captures the choice only; the data-gen stays deferred.
[] call fnc_startup_autodetect_faction;

[] spawn fnc_enviro_menu;
