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

    ["Furnish cursor building", fnc_debug_furnish_menu, [cursorObject], [1,0.667,0,1]],

    // Building-independent, so top-level rather than behind the cursor-building gate of the furnish submenu.
    ["Calibrate furniture fronts", { call fnc_debug_furnish_calibrate }, [], [1,0.667,0,1]],

    ["Adjust CP / AP / Town / Escalation", fnc_debug_econ_menu, [], [1,0.667,0,1]],

    ["Force side mission", fnc_debug_mission_menu, [], [1,0.667,0,1]],

    ["Spawn random event", fnc_debug_random_event_menu, [], [1,0.667,0,1]],

    // Clears fnc_stratmap's cached offer set and reopens the picker, rolling a fresh seven. The cache
    // is what keeps a normal back-out on the same offers; this is the intended way to roll new ones.
    // The type step forces one type into the draw, to test its siting without the draw RNG.
    ["Re-roll side missions", {
        private _defs = [
        #include "..\..\shared\includes\mission_types.hpp"
        ];
        // Clears the start gate the way the force tool does (stamp to 0): a dev re-roll that still
        // tripped the three-hour wait would open the picker but roll a set none could start;
        // fnc_mission_begin re-stamps on the next start. _this is the type to force, -1 to skip.
        private _reroll = {
            DUWS_dbgForceDrawType = _this;
            DUWS_lastMissionStartDate = 0;
            publicVariable "DUWS_lastMissionStartDate";
            DUWS_missionOffers = [];
            [] spawn fnc_stratmap;
        };
        private _rows = [["(none -- normal re-roll)", _reroll, -1, [1,0.667,0,1]]];
        {
            _rows pushBack [format ["Force %1  (type %2)", _x select 4, _forEachIndex], _reroll, _forEachIndex, [1,0.667,0,1]];
        } forEach _defs;
        ["Re-roll: force a type into the draw", _rows] call fnc_open_action_menu;
    }, [], [1,0.667,0,1]],

    ["Spawn OPFOR hardpoint", fnc_debug_hardpoint_menu, "opfor", [1,0.667,0,1]],
    ["Spawn BLUFOR hardpoint", fnc_debug_hardpoint_menu, "blufor", [1,0.667,0,1]],

    // Fire one observation-post recon burst at a clicked spot, at 100% -- the same 1km reveal an OP rolls
    // for, on demand, to test the compromise card and the OPFOR reveal without waiting on the post's odds.
    // Click-to-place idiom, same as the hardpoint placer; the pos is captured client-side, the burst run on
    // the server (DUWS_fnc_hardpointOPBurst), which owns the side-level reveal.
    ["Recon burst: click a spot", {
        [] spawn {
            DUWS_dbgReconClicked = false;
            openMap [true, false];
            waitUntil { !isNull (findDisplay 12) };
            // Banner, not hint: the engine draws the hint box beneath the open map, so it is invisible while
            // the map is up. The confirmation arrives as a hint once the map is closed, below.
            ["<t size='2' color='#00ffff'>Click the map to fire an OP recon burst there. </t><br/>Dev tool: reveals every BLUFOR within 1 km to OPFOR and cards each player, at 100%. Close the map to cancel."] call fnc_map_prompt;
            onMapSingleClick "DUWS_dbgReconPos = _pos; DUWS_dbgReconClicked = true; onMapSingleClick ''; true";
            waitUntil { DUWS_dbgReconClicked || !visibleMap };
            onMapSingleClick "";
            [""] call fnc_map_prompt;
            if (!DUWS_dbgReconClicked) exitWith {};
            openMap [false, false];
            [[DUWS_dbgReconPos select 0, DUWS_dbgReconPos select 1, 0]] remoteExec ["DUWS_fnc_hardpointOPBurst", 2];
            hint "OP recon burst fired at the marked spot.\n\nDev tool: every BLUFOR within 1 km is revealed to OPFOR\nand each player carded, at 100% (no per-wake roll).";
        };
    }, [], [1,0.667,0,1]],

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

    // Click-to-inspect, same idiom as the ledger row above: read one emitter's OPCOM force-grid deposit and
    // where the men count came from -- (live) roster, (ledger) surviving tokens, or a fixed (nominal).
    ["Force emission: click a site", {
        [] spawn {
            DUWS_dbgForceClicked = false;
            openMap [true, false];
            waitUntil { !isNull (findDisplay 12) };
            // Banner, not hint: the engine draws the hint box beneath the open map, so it is invisible
            // while the map is up. The answer arrives as a hint once the map is closed, below.
            ["<t size='2' color='#00ffff'>Click a zone or OPFOR hardpoint to read its force emission. </t><br/>Dev tool: the OPCOM force-grid deposit and its source -- (live), (ledger) or (nominal). Close the map to cancel."] call fnc_map_prompt;
            onMapSingleClick "DUWS_dbgForcePos = _pos; DUWS_dbgForceClicked = true; onMapSingleClick ''; true";
            waitUntil { DUWS_dbgForceClicked || !visibleMap };
            onMapSingleClick "";
            [""] call fnc_map_prompt;
            if (!DUWS_dbgForceClicked) exitWith {};
            openMap [false, false];
            [[DUWS_dbgForcePos select 0, DUWS_dbgForcePos select 1, 0], player] remoteExec ["fnc_debug_force_emission", 2];
        };
    }, [], [1,0.667,0,1]],

    // Two independent map overlays. AoI rings every emitter's reach in its side's colour; OPCOM grid
    // paints the whole-map influence lattice with a per-cell force dot and belief warnings.
    ["AoI view: toggle emitter reaches", fnc_debug_aoi_view, [], [1,0.667,0,1]],
    ["OPCOM grid: toggle influence lattice", fnc_debug_opcom_view, [], [1,0.667,0,1]]
]] call fnc_open_action_menu;
