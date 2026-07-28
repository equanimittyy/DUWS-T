// Locality: client -- an addAction function value, so it runs on whoever opened the menu.
/*
    fnc_debug_menu.sqf
    Developer tools, attached to the player in client_init.sqf behind the Debug mission
    parameter and game_master. Rows are deliberately not localised: this is a dev surface, so
    English strings here spare the stringtable a set of tags no player ever reads.
*/
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the addAction: this function is publicVariable'd, so every
// client holds a copy it can call. Rows here make the server do work on demand, and the point
// of the game_master gate is that one machine decides when that happens.
if (!((vehiclevarname player) in game_master)) exitWith {};

["Debug", [
    ["Force garbage clean", {
        [] remoteExec ["fnc_duws_forceCleanup", 2];
        hint "Map cleanup: sweeping now.\n\nLifetimes are treated as elapsed, so all litter goes\nexcept: within 300 m of a player, flagged persistent,\nor an intact vehicle parked within 250 m of the HQ,\na FOB or the MHQ. Counts land in the log.";
    }, [], [1,0.667,0,1]],

    ["Stow / deploy nearest zone", {
        [getPos player] remoteExec ["fnc_duws_toggleNearestZone", 2];
        hint "Composition streaming: toggling the nearest zone.\n\nStowed compositions are deleted and rebuilt from a record,\nso destroyed parts stay gone and crates keep what is left\nin them. Refused while a gun still has its gunner.";
    }, [], [1,0.667,0,1]],

    ["Simulate intel search", {
        [player] remoteExec ["fnc_debug_intel_search", 2];
    }, [], [1,0.667,0,1]],

    ["Adjust CP / AP", fnc_debug_econ_menu, [], [1,0.667,0,1]],

    // Stub. Planned: a local overlay onto OPFOR-side WARCOM -- commander AP with its
    // income and spend, the wave thresholds it is holding at, a map marker per enemy asset.
    // Deferred assets are the point: zone garrisons still virtual behind fnc_spawnWait, queued
    // assault and QRF task forces, hardpoints once they exist. Watch it decide, don't fly over.
    ["Toggle OPFOR WARCOM (not implemented)", {
        hint "Not implemented yet.\n\nPlanned: OPFOR commander AP and the wave thresholds\nit is waiting on, plus a map marker for every enemy\nasset -- including zone garrisons and task forces\nnot yet spawned in.";
    }, [], [0.6,0.6,0.6,1]]
]] call fnc_open_action_menu;
