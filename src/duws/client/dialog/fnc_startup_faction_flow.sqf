// Locality: client -- inherited from client/dialog/fnc_startup_enviro_closed.sqf.
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

// Per-side faction prompts (custom paste window and/or AutoDetect picker), shown
// BLUFOR then OPFOR and only for the side that needs one. Runs during setup so the
// popups land before START; the heavy build stays deferred to the commit.
[] call fnc_startup_faction_resolve;

// Back from a paste window restarts the whole faction/HQ selection.
if (duws_custom_faction_back) exitWith { [] spawn fnc_startup_faction_flow; };

[] spawn fnc_enviro_menu;
