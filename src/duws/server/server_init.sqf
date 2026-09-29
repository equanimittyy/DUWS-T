// Locality: server -- see callers.
// Logging first: the registry self-check and every milestone below need fnc_log, and a
// failure in server_var_init/server_fnc_init is exactly what has to be visible.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_log_init.sqf";
["INFO", "BOOT", format ["Server_init: %1", profileName]] call fnc_log;
["INFO", "BOOT", format ["server_init start, player %1", profileName]] call fnc_log;

[] call compile preprocessFileLineNumbers "duws\server\server_var_init.sqf";
["INFO", "BOOT", "server_var_init done"] call fnc_log;
[] call compile preprocessFileLineNumbers "duws\server\server_fnc_init.sqf";
["INFO", "BOOT", "server_fnc_init done"] call fnc_log;
setGroupIconsVisible [(["DUWS_GroupIcons", 0] call BIS_fnc_getParamValue) == 1, false];
// Built while the player sits in the setup screens; WARCOM, the first router, waits on it below.
[] spawn fnc_convoy_graph;

createCenter sideLogic;
createcenter sideLogic;
createCenter west;
createCenter east;
createCenter resistance;
createCenter civilian;

west setFriend [east, 0];
west setFriend [resistance, 0];
east setFriend [west, 0];
east setFriend [resistance, 0];
resistance setFriend [west, 0];
resistance setFriend [east, 0];
civilian setFriend [west, 1];
civilian setFriend [east, 1];

[] call fnc_factions_check;
[] call fnc_bandit_looks;

sleep 1;

serverinit_complete = true;
publicVariable "serverinit_complete";

// MP only: SP always fills game_master locally. If player1's slot sits empty here, the setup
// gates below never clear and the campaign hangs with nothing on screen to say why. Spawned,
// not inline: the main thread is about to block on those same gates.
if (isMultiplayer) then {
	[] spawn {
		sleep 5;
		private _gm = missionNamespace getVariable ["player1", objNull];
		if (isNull _gm || {!isPlayer _gm}) then {
			["ERROR", "BOOT", "Game Master slot (player1) empty -- setup cannot run, campaign will hang"] call fnc_log;
			["no_gamemaster", []] remoteExec ["BIS_fnc_showNotification", 0];
			// The card warns; this gives the way out, since the setup screens offer no menu to reach it.
			remoteExec ["fnc_no_gm_prompt", 0];
		};
	};
};

// A load pre-sets the flags the setup gates below wait on.
[fnc_moreUrban_locations] call DUWS_fnc_restoreGate;

// A load resolves once against the saved picks: classnames are re-resolved against the mods loaded now.
private _fnc_resolveFactions = {
	["INFO", "BOOT", "Server waiting for BLU faction Data Temp"] call fnc_log;
	if (BLUFOR_FactionFile_X == "CUSTOM") then { while {!(["FACTION", "BLUfactionDataTemp pasted", {BLUfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };
	if (OPFOR_FactionFile_X == "CUSTOM") then { while {!(["FACTION", "OPFfactionDataTemp pasted", {OPFfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };

	["INFO", "BOOT", format ["BLUFOR Faction init on server: %1", BLUFOR_FactionFile_X]] call fnc_log;

	if (BLUFOR_FactionFile_X == "CUSTOM") then {
		["blufor"] call fnc_custom_faction_init;
		while {!(["FACTION", "BLUfactionData populated", {count BLUfactionData > 0}, 300] call fnc_waitLogged)} do {};
	} else {
		[] call fnc_BLUFOR_faction_init;
	};
	["INFO", "BOOT", format ["Blufor Faction init on server complete.  Rifleman: %1", blufor_SOLDIER_X]] call fnc_log;
	["INFO", "BOOT", format ["Blufor Faction init on server complete.  blufor RQST VEHICLE 01: %1", (["VEHICLE"] call fnc_faction_rqst_list) param [0, "none"]]] call fnc_log;

	// Unguarded: an "opfor already resolved" check would pin the first resolution, which breaks
	// once stepping back can re-pick the faction.
	["INFO", "BOOT", format ["OPFOR Faction init on server: %1", OPFOR_FactionFile_X]] call fnc_log;

	if (OPFOR_FactionFile_X == "CUSTOM") then {
		["opfor"] call fnc_custom_faction_init;
		while {!(["FACTION", "OPFfactionData populated", {count OPFfactionData > 0}, 300] call fnc_waitLogged)} do {};
	} else {
		[] call fnc_OPFOR_faction_init;
	};
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Rifleman: %1", opfor_SOLDIER_X]] call fnc_log;
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Spec Ops: %1", opfor_SPECOPS_X]] call fnc_log;

	// Both sides are resolved and nothing has been shown yet -- the only point a borrowed class can
	// still reach the confirmation screen. Filling after the screen painted would leave the player
	// looking at a blank row the mission then quietly fills behind them.
	{ [_x] call fnc_faction_backfill; } forEach ["blufor", "opfor"];

	// Drops the schema's vanilla stand-in into any key a hand-written or pasted faction left empty
	// (or pointing at a class this install lacks); AutoDetect resolves its own. Keeps an omitted
	// role from reaching a spawner as MISSING.
	{ [_x] call fnc_faction_vanilla_fill; } forEach ["blufor", "opfor"];

	// Expands each role's representative into its faction's pool here, not only at the commit, so
	// the confirmation screen can show the pool a spawn will draw from -- a static file assigns
	// one class per role and only this pass widens it.
	[] call fnc_faction_augment;

	// No faction file runs on a client, and a static one assigns server-side only -- without this the
	// screen would paint whatever that machine happened to hold, not what the server just resolved.
	{
		private _side = _x;
		{ missionNamespace setVariable [_x select 0, missionNamespace getVariable [_x select 0, ""], true]; }
			forEach ([_side] call fnc_faction_schema);
	} forEach ["blufor", "opfor"];

	// The menus reading this are client-side and the schema does not carry the catalogue. Numbered
	// slots too: a pasted faction may spell it fnc_faction_rqst_list's older way.
	{ publicVariable _x; } forEach (["blufor_RQST_UNITS", "blufor_RQST_VEHICLES"] select { !isNil _x });
	{
		private _kind = _x;
		for "_i" from 1 to 99 do {
			private _var = format ["blufor_RQST_%1_%2_X", _kind, if (_i < 10) then { "0" + str _i } else { str _i }];
			if (isNil _var) exitWith {};
			publicVariable _var;
		};
	} forEach ["UNIT", "VEHICLE"];

	// One broadcast of every key's resolution tier, read once here after backfill so a borrow's
	// yellow is already in. The confirmation screen colours each row from it: 0 white, 1 yellow, 2 red.
	DUWS_factionTiers = [];
	{
		private _side = _x;
		{ DUWS_factionTiers pushBack [_x select 0, missionNamespace getVariable [format ["DUWS_factionTier_%1", _x select 0], 0]]; }
			forEach ([_side] call fnc_faction_schema);
	} forEach ["blufor", "opfor"];
	publicVariable "DUWS_factionTiers";

	// The pools themselves, for the confirmation screen: the per-role globals above carry only the
	// representative, so without this the screen shows one class where a faction fields several. A
	// structure of its own, not the globals -- those must stay single-valued, since the spawn paths
	// and direct readers like opfor_SOLDIER_X expect a classname, not a pool.
	DUWS_factionPreviewPools = [];
	{
		private _side = _x;
		{
			private _k = _x select 0;
			private _p = missionNamespace getVariable [format ["DUWS_factionPool_%1", _k], []];
			DUWS_factionPreviewPools pushBack [_k, if (_p isEqualTo []) then { missionNamespace getVariable [_k, ""] } else { _p }];
		} forEach ([_side] call fnc_faction_schema);
	} forEach ["blufor", "opfor"];
	publicVariable "DUWS_factionPreviewPools";
};

// Answers the confirmation screen and can't wait for the commit, since it's the last point the
// player can change a pick. Loop, not once: stepping back re-enters faction selection and asks
// again -- faction inits and all three AutoDetect wrappers tolerate being re-called.
// Condition reads globals only: fnc_waitLogged runs the block in its own scope, so a private
// captured here would be undefined by the time it runs.
while {!createzone_server} do {
	while {!(["BOOT", "duws_faction_preview_request (confirmation screen opened)",
		{duws_faction_preview_request > duws_faction_preview_ready || createzone_server}, 600] call fnc_waitLogged)} do {};
	if (createzone_server) exitWith {};
	private _serving = duws_faction_preview_request;
	call _fnc_resolveFactions;

	// Answers the request by number, so the screen can tell this round's rows from the last one's.
	duws_faction_preview_ready = _serving;
	publicVariable "duws_faction_preview_ready";
};
// After the loop, not before: a load chosen from the reopened load screen ends it partway through setup.
if (DUWS_campaignLoaded) then { call _fnc_resolveFactions };

// HQ build stays behind the commit so Back navigation still finds nothing built to unwind.
// Everything below consumes only PosOfBLUHQ (set at placement) until this gate.
while {!(["BOOT", "createzone_server (setup screens committed)", {createzone_server}, 300] call fnc_waitLogged)} do {};

// HQ placement runs after the confirmation screen now, so this cannot gate the resolution loop
// above: the screen would be waiting on a placement the player has not been offered yet. Kept as
// a guard here, where PosOfBLUHQ is about to be read for real.
while {!(["BOOT", "chosen_hq_placement (player is placing HQ)", {chosen_hq_placement}, 300] call fnc_waitLogged)} do {};

[] call fnc_faction_apply_locked;

// A locked table already holds every row's whole pool (the screen builds from the preview pools), and
// re-expanding from the representative would undo the player's list edits: drops come back, adds go.
// Only a commit with no table, the debug quickstart, still needs the pass.
if (duws_faction_locked isEqualTo []) then { [] call fnc_faction_augment; };
// A load has no locked table: its edits are the saved intent, laid over what this install detected.
if (DUWS_campaignLoaded) then { [(DUWS_restore get "factions") getOrDefault ["edits", []]] call fnc_faction_edits_apply };

// A side with no static MG leaves each composition's vanilla placeholder standing instead -- the
// one case where a zone garrisons itself with the wrong side's gun. Checked here, not at each
// placement: this is the first point the keys are final, and it is one line per campaign.
{
	if (([format ["%1_TURRET_HMG", _x]] call fnc_faction_pick) isEqualTo "") then {
		["WARN", "FACTION", format ["%1 fields no static MG -- statics with no role of their own stand as the composition's own class", _x]] call fnc_log;
	};
} forEach ["blufor", "opfor"];

// Squads compose from the role globals, so they're built after the edits land, not beside
// the resolution that produced them.
[] call fnc_BLUFOR_squad_init;
["INFO", "BOOT", format ["blufor RECON_TEAM: %1", str blufor_RECON_TEAM_X]] call fnc_log;

[] spawn fnc_create_ammo_lists;

["INFO", "BOOT", format ["bluHQ Position: %1", str PosOfBLUHQ]] call fnc_log;
[] spawn fnc_bluHQinit;

["Initialize"] call BIS_fnc_dynamicGroups; 

while {!(["BOOT", "HQ_pos_found_generated", {HQ_pos_found_generated}, 300] call fnc_waitLogged)} do {};

// Weapons list, not items: some factions bork on items.
while {!(["BOOT", "opfor_ammobox_weapons built", {(count opfor_ammobox_weapons) > 0}, 180] call fnc_waitLogged)} do {};

while {!(["BOOT", "road graph built", {!isNil "DUWS_convoy_roadNbr"}, 300] call fnc_waitLogged)} do {};

["INFO", "BOOT", "WARCOM INIT"] call fnc_log;
[] spawn fnc_init_OPFOR_WARCOM;


[] spawn fnc_capture_zones_task;


[] spawn fnc_zone_spawn_sizes;


if (dynamic_weather_enable) then {
	[] spawn fnc_weather;
};

// The default lifetime for everything the sweep collects that names none of its own; the sweep is
// always on (a 0 from an old save is floored, not off). The default lives in the parameter, not here, so the two cannot drift apart.
[["DUWS_CleanupLifetime", 300] call BIS_fnc_getParamValue] spawn fnc_repetitive_cleanup;

for[{_x = 2},{_x <= 36},{_x = _x + 1}] do {
    _thePlayer = missionNamespace getVariable format["player%1", _x];
    if(!isNil("_thePlayer")) then {
        if(!isPlayer _thePlayer) then {
            deleteVehicle _thePlayer;
        };
    };
};

waituntil {sleep 1;WARCOM_init_done;};
[] spawn fnc_missionLocator;

[] spawn fnc_AI_Master_Control;

if (ZeusStatus != 0) then {
	[] spawn fnc_zeus_objects_init;
};

// Keeps interaction-critical objects (HQ fixtures, zone flags, FOB, MHQ) locked out of Zeus so a game
// master cannot delete them; re-asserts the lock periodically in case a mod re-adds them to Zeus.
[] spawn fnc_guard_watch;

// Contention shows only as other stages' wall time running long; this names what is running. The level
// is read each pass because a debug session can raise it mid-game.
[] spawn {
    while {true} do {
        sleep 60;
        if (duws_log_level >= 4) then {
            // diag_fpsMin spans only 16 frames, so it misses a lone long frame between samples.
            if (isNil "DUWS_perf_frameEH") then {
                DUWS_perf_last = diag_tickTime;
                DUWS_perf_worst = 0;
                DUWS_perf_hitches = 0;
                DUWS_perf_frameEH = addMissionEventHandler ["EachFrame", {
                    private _ms = (diag_tickTime - DUWS_perf_last) * 1000;
                    DUWS_perf_last = diag_tickTime;
                    DUWS_perf_worst = DUWS_perf_worst max _ms;
                    // Logged as it happens, so the RPT lines beside it name what held the frame. 150 ms: above a
                    // 10 fps frame, below the stalls worth chasing.
                    if (_ms >= 150) then {
                        DUWS_perf_hitches = DUWS_perf_hitches + 1;
                        ["DEBUG", "PERF", format ["hitch: one frame took %1 ms", round _ms]] call fnc_log;
                    };
                }];
            };
            private _scripts = diag_activeSQFScripts;
            private _byFile = createHashMap;
            {
                private _parts = (_x select 1) splitString "\/";
                private _f = _parts param [count _parts - 1, "?"];
                _byFile set [_f, (_byFile getOrDefault [_f, 0]) + 1];
            } forEach _scripts;
            private _top = [];
            { _top pushBack [_y, _x] } forEach _byFile;
            _top sort false;
            ["DEBUG", "PERF", format ["fps %1 (min %2), worst frame %3 ms, %4 hitches, %5 scheduled scripts, %6 units, %7 groups, %8 vehicles, %9 dead, top %10",
                round diag_fps, round diag_fpsMin, round DUWS_perf_worst, DUWS_perf_hitches, count _scripts, count allUnits,
                count allGroups, count vehicles, count allDead,
                ((_top select [0, 5]) apply { format ["%1 x%2", _x select 1, _x select 0] }) joinString ", "]] call fnc_log;
            DUWS_perf_worst = 0;
            DUWS_perf_hitches = 0;
        };
    };
};

// Set the date/time AFTER setting the current weather
if (DUWS_campaignLoaded) then { setDate DUWS_restoreDate } else { setDate [2035, 8, 3, time_of_day, 0] };

if (CIV_PRESENCE == "RAVAGE") then {
    [] spawn fnc_night_horde_event;
};
VCM_ADVANCEDMOVEMENT = false;
publicVariable "VCM_ADVANCEDMOVEMENT";
if (isServer) then {
    if (isNil "playerKillCount") then { playerKillCount = createHashMap; };
    departedKillCP = 0;
    addMissionEventHandler ["EntityKilled", {
        params ["_killed", "_killer", "_instigator"];

        // Killhouse bodies never pay: the drill already awards a fixed sum per completed run, so
        // counting kills here would turn an unlimited training course into an unlimited CP source.
        // Plain (non-public) setVariable is enough: the tag is written and read on the server.
        if (_killed getVariable ["killhouse_enemy", false]) exitWith {};

        private _shooter = objNull;
        if (isPlayer _instigator) then {
            _shooter = _instigator;
        };
        if (isNull _shooter && {isPlayer _killer}) then {
            _shooter = _killer;
        };
        if (isNull _shooter) then {
            {
                if (_killer in (units group _x)) exitWith {
                    _shooter = _x;
                };
            } forEach allPlayers;
        };
        if (isNull _shooter) exitWith {};

        // Only hostiles pay: EntityKilled also fires for civilians, friendlies and empty vehicles,
        // and paying for civilian kills would reward exactly what the town reputation charge
        // penalises. 0.6 is the engine's hostile/friendly cutoff; every playable side pair is set
        // to 0, so INDEPENDENT zombies still count.
        if ((side _shooter) getFriend (side _killed) >= 0.6) exitWith {};

        // The tally converts to CP on the periodic sweep below, not here.
        private _uid = getPlayerUID _shooter;
        playerKillCount set [_uid, (playerKillCount getOrDefault [_uid, 0]) + 1];
    }];

    // A rejoining player starts from zero: the tally is keyed by UID and outlives the
    // session that earned it, so without this a returning player resumes an old count.
    addMissionEventHandler ["PlayerConnected", {
        params ["", "_uid"];
        playerKillCount set [_uid, 0];
    }];

    // A leaver's whole batches are banked here and paid on the next sweep; the remainder
    // dies with the entry rather than waiting for a session that may never return.
    addMissionEventHandler ["PlayerDisconnected", {
        params ["", "_uid"];
        private _kills = playerKillCount getOrDefault [_uid, 0];
        departedKillCP = departedKillCP + (floor (_kills / kill_cp_kills)) * kill_cp_award;
        playerKillCount deleteAt _uid;
    }];

    addMissionEventHandler ["PlayerDisconnected", {
        params ["", "_uid"];
        if (_uid isEqualTo "") exitWith {};
        {
            if ((_x getVariable ["DUWS_hcCommander", ""]) isEqualTo _uid) then { [_x] call fnc_taskforce_create };
        } forEach allGroups;
    }];

    addMissionEventHandler ["Ended", { ["mission end"] call DUWS_fnc_campaignSave }];
    addMissionEventHandler ["MPEnded", { ["mission end"] call DUWS_fnc_campaignSave }];

    // Paid in one periodic sweep rather than per kill: a tally the player watches build reads as
    // campaign economy, where a payout per body reads as a score feed. Defined here beside the
    // handlers that fill the tally, but driven by the campaign economy tick in
    // server/warcom/fnc_zonesundercontrol.sqf -- a second timer of the same nominal period would
    // accrue its own scheduler slop and walk out of phase.
    fnc_kill_income_sweep = {
        {
            private _uid = getPlayerUID _x;
            private _kills = playerKillCount getOrDefault [_uid, 0];
            private _batches = floor (_kills / kill_cp_kills);
            if (_batches > 0) then {
                private _award = _batches * kill_cp_award;
                // Server-side caller: call runs inline, where remoteExec [...,2] would land a frame later.
                [_award, "kill_income"] call fnc_cp_adjust;
                playerKillCount set [_uid, _kills - _batches * kill_cp_kills];
                // A card, not a hint -- deliberately the exception to the one-player-to-hint rule in
                // docs/info/gameplay/player_text_style_guide.md: CP arriving speaks the card vocabulary
                // its siblings cpaddedmission and apaddedmission already own, so moving it would make
                // kill income the only income that reads as a refusal.
                ["CPaddedattrition", [_award]] remoteExec ["BIS_fnc_showNotification", _x, false];
            };
        } forEach allPlayers;

        if (departedKillCP > 0) then {
            [departedKillCP, "kill_income_departed"] call fnc_cp_adjust;
            departedKillCP = 0;
        };
    };
};
{ 
    [_x] remoteExec ["addRating", _x];
} forEach allPlayers;

[] spawn {
    waitUntil { sleep 1; !isNil "PosOfBLUHQ" && {count allPlayers > 0} };
    private _hqPos = PosOfBLUHQ;
    private _executed = false;

    while {!_executed} do {
        private _anyPlayerNear = false;
        {
            if (isPlayer _x && {alive _x} && {_x distance _hqPos < 50}) exitWith {
                _anyPlayerNear = true;
            };
        } forEach (call BIS_fnc_listPlayers);

        if (_anyPlayerNear) then {
            ["INFO", "GEAR", "Player detected within 50m of HQ. Building quick kits..."] call fnc_log;
            [] call fnc_buildQuickKits;
            _executed = true;
        } else {
            sleep 5;
        };
    };
};
"apocalypse_mode" addPublicVariableEventHandler {
    params ["_var", "_value"];
    if (_value) then {
        ["INFO", "SUPPORT", "Public variable detected, launching destruction."] call fnc_log;
        [] spawn fnc_apocalypse_buildings;
    };
};
[] spawn {
    waitUntil { sleep 1; WARCOM_init_done }; // WARCOM must have spawned the units first
    sleep 5; // brief settle before reading their gear
    [] execVM "duws\server\arsenal\fnc_collectEquipmentFromUnits.sqf";
};
[] spawn {
    scriptName "Add to InitServer.sqf -> Prevent AI Abandoning Vehicles";
    while{true} do {
        
        {
            _x setUnloadInCombat [true, false];        // vehicle setUnloadInCombat [allowCargo, allowTurrets]
            _x allowCrewInImmobile [true, true];            // vehicle allowCrewInImmobile allow / vehicle allowCrewInImmobile [brokenWheels, upsideDown]
            _x setVariable ["vehAiLockInit",true];
        }forEach  ( vehicles select { !(_x getVariable ["vehAiLockInit",false]) } );
        
        sleep 300.00;
    };
};
waitUntil { sleep 1.0; chosen_settings };
waitUntil { sleep 1.0; HQ_pos_found_generated };
// Zones and civilians both finish well after HQ placement, so the intro must not fly players
// in while the campaign is still being built around them.
while {!(["BOOT", "mission_init_complete (zones built, civilians registered)",
    {mission_init_complete}, 300] call fnc_waitLogged)} do {};
[] spawn DUWS_fnc_autosaveLoop;
// Paced, not idle: generation signs off by typing across every screen and hinting the settings
// summary (warcom/fnc_init_OPFOR_WARCOM.sqf) the instant mission_init_complete goes up, and the
// intro's first act is to black the screen over them. Flying as soon as clients were ready cut the
// six-second typing off a second in; 12s still clipped it.
sleep 15;

// Does not replace the pause above: the intro remoteExecs a seat onto each client, so every player
// must be holding client_init's fnc_remoteBoard before it flies. Bounded, not retried -- one client
// stuck short of that line must not hold the flight for everybody else. The count test is
// load-bearing: findIf over an empty allPlayers returns -1, so an empty list would pass on sight.
["BOOT", "duws_intro_ready on every player",
    {count allPlayers > 0
        && {(allPlayers findIf {!(_x getVariable ["duws_intro_ready", false])}) isEqualTo -1}}, 60] call fnc_waitLogged;
["INFO", "BOOT", "Starting helicopter intro sequence..."] call fnc_log;
[] spawn fnc_intro_heli;
if (CIV_PRESENCE != "RAVAGE" && CIV_PRESENCE != "WBK" && CIV_PRESENCE != "NONE") then {
    [] spawn fnc_scanCivilianGear;
    [] spawn fnc_scanEnemyGear;
};
// These cooldowns stamp diag_tickTime, which counts from Arma process start, not mission start.
// Resuming an autosave in a fresh Arma session restarts that clock, so every stamp sits in the
// future and wedges its action for as long as the old session ran. A stamp ahead of the clock has
// no other cause, so drop it; stamps in the past are just unused actions, not faults.
if (isNil "DUWS_cooldownMonitor_running") then {
    DUWS_cooldownMonitor_running = true;
    publicVariable "DUWS_cooldownMonitor_running";

    [] spawn {
        private _cooldownVars = [
            "DUWS_disguise_blownAt",
            "DUWS_enemyDisguise_blownAt",
            "DUWS_hirePartisans_lastUse",
            "DUWS_hirePMC_lastUse"
        ];

        while {true} do {
            {
                private _player = _x;
                if (!isNull _player) then {
                    {
                        if ((_player getVariable [_x, 0]) > diag_tickTime) then {
                            _player setVariable [_x, nil, true];
                            if (duws_log_level >= 4) then { ["DEBUG", "SUPPORT", format ["Cleared future %1 stamp on %2", _x, name _player]] call fnc_log; };
                        };
                    } forEach _cooldownVars;
                };
            } forEach (call BIS_fnc_listPlayers);

            sleep 60;
        };
    };
};
[] spawn fnc_createKillhouse;
if (!isServer) exitWith {};
