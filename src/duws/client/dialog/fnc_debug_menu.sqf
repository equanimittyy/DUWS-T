// Locality: client -- an addAction function value, so it runs on whoever opened the menu.
/*
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

    ["Spawn intel items (drop-test)", {
        [player] remoteExec ["fnc_debug_spawn_intel", 2];
    }, [], [1,0.667,0,1]],

    // cursorObject is read here rather than in the submenu, because it is read before
    // fnc_open_action_menu creates its dialog. A row's code runs with the dialog already down and
    // the pointer gone, so reading it there is a guess at what the player was looking at.
    ["Flag cursor object as searchable", fnc_debug_search_menu, [cursorObject], [1,0.667,0,1]],

    ["Adjust CP / AP / Town / Escalation", fnc_debug_econ_menu, [], [1,0.667,0,1]],

    ["Force side mission", fnc_debug_mission_menu, [], [1,0.667,0,1]],

    ["Spawn OPFOR hardpoint", fnc_debug_hardpoint_menu, "opfor", [1,0.667,0,1]],
    ["Spawn BLUFOR hardpoint", fnc_debug_hardpoint_menu, "blufor", [1,0.667,0,1]],

    // Click-to-inspect on the open map, same idiom as the hardpoint placer: read one site's garrison
    // ledger -- max, available and dead tokens with the strength maths -- from the server, which owns it.
    ["Garrison ledger: click a site", {
        [] spawn {
            DUWS_dbgGarrClicked = false;
            openMap [true, false];
            waitUntil { !isNull (findDisplay 12) };
            // Banner, not hint: the engine draws the hint box beneath the open map, so it is invisible
            // while the map is up. The answer arrives as a hint once the map is closed, below.
            [format ["<t size='2' color='#00ffff'>Click a zone or town to read its garrison ledger. </t><br/>Dev tool: max, available and dead tokens with the strength maths. Close the map to cancel."]] call fnc_map_prompt;
            onMapSingleClick "DUWS_dbgGarrPos = _pos; DUWS_dbgGarrClicked = true; onMapSingleClick ''; true";
            waitUntil { DUWS_dbgGarrClicked || !visibleMap };
            onMapSingleClick "";
            [""] call fnc_map_prompt;
            if (!DUWS_dbgGarrClicked) exitWith {};
            openMap [false, false];
            [[DUWS_dbgGarrPos select 0, DUWS_dbgGarrPos select 1, 0], player] remoteExec ["fnc_debug_garrison_query", 2];
        };
    }, [], [1,0.667,0,1]],

    // First of the OPCOM debug tooling: opens the map and rings every AoI emitter's reach hatched in
    // its side's colour, so the influence field the commander reads is visible rather than inferred from
    // town colours. Still to come on this theme: commander AP with its income and spend, the wave
    // thresholds it holds at, and a marker per enemy asset -- including the zone garrisons and task
    // forces still virtual behind the site poller.
    ["OPCOM view: toggle AoI overlay", fnc_debug_opcom_view, [], [1,0.667,0,1]]
]] call fnc_open_action_menu;
