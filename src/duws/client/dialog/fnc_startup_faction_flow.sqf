// Locality: client -- inherited from client/dialog/fnc_startup_enviro_closed.sqf.
// Faction pick -> custom-faction paste (if any) -> faction confirmation -> HQ placement ->
// environment menu. Runs on first setup (from client_init) and whenever the environment screen's
// Back button routes back here to re-pick faction and HQ.
//
// Placement is last of the faction steps rather than first: a Back out of the confirmation screen
// re-picks factions, and a base already placed would have been sited against a roster the player
// then changed. The server's own gate moved to match (server/server_init.sqf) -- resolution has to
// be reachable before placement now, or the confirmation screen waits on a server that is itself
// waiting for the placement that comes after it.
//
// Reset the placement-state flags first: on a re-entry they are still set from
// the previous run, and fnc_hq_placement's waits (player_is_choosing_hqpos
// / chosen_hq_placement) would otherwise short-circuit and skip placement. Kept
// client-local (no publicVariable) so the server's already-satisfied
// chosen_hq_placement gate is not disturbed.
chosen_hq_placement = false;
player_is_choosing_hqpos = false;
random_placement = false;
duws_custom_faction_back = false;   // set by the paste screen's Back button

// Cleared network-wide, unlike the flags above: the AutoDetect wrappers wait on these, and on a
// re-entry the server would otherwise resolve against the previous round's pick before the picker
// republishes this round's.
missionNamespace setVariable ["selectedFaction_BLU", nil, true];
missionNamespace setVariable ["selectedFaction_OPF", nil, true];

[] call fnc_HQ_faction_dialog;

// Per-side faction prompts (custom paste window and/or AutoDetect picker), shown
// BLUFOR then OPFOR and only for the side that needs one. Runs during setup so the
// popups land before START; the heavy build stays deferred to the commit.
[] call fnc_startup_faction_resolve;

// Back from a paste window restarts the whole faction/HQ selection.
if (duws_custom_faction_back) exitWith { [] spawn fnc_startup_faction_flow; };

// Confirmation: the first point the resolved classnames exist and the last point they can be
// changed. Its own Back restarts the selection the same way the paste window's does.
[] call fnc_faction_confirm;
if (duws_faction_confirm_back) exitWith { [] spawn fnc_startup_faction_flow; };

// Only once the rosters are locked in is the player asked where to put the base.
[] call fnc_hq_placement;

[] spawn fnc_enviro_menu;
