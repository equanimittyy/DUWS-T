// Locality: client -- see callers.
// Logging first, so anything that fails below is visible. The server compiles this too;
// on a dedicated server the client half needs its own copy before the registry arrives.
#include "..\shared\includes\action_style.hpp"

[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_log_init.sqf";
// Shared loadout tally; the arsenal overlay's live-count loop (initPlayerLocal) calls it per edit.
fnc_captured_loadout_counts = compile preprocessFileLineNumbers "duws\shared\functions\fnc_captured_loadout_counts.sqf";
["INFO", "BOOT", format ["Client_init: %1", profileName]] call fnc_log;
["INFO", "BOOT", format ["client_init start, player %1", profileName]] call fnc_log;
fnc_hirePartisans_clientMap = compile preprocessFileLineNumbers "duws\client\misc\fnc_hirePartisans_clientMap.sqf";
publicVariable "fnc_hirePartisans_clientMap";
// Defines DUWS_fnc_arsenal_countFor / _paintCounts (arsenal item-count overlay); the enforcer loop
// in initPlayerLocal.sqf calls the painter each tick while the arsenal is open.
[] call compile preprocessFileLineNumbers "duws\client\arsenal\fnc_arsenal_counts.sqf";
// Per-client beacon builder for the patrol-camp mission; the server remoteExecs it to stand a wood-smoke
// column on each camp's fire (a #particlesource must be built locally on every machine, see the file).
DUWS_fnc_campSmoke = compile preprocessFileLineNumbers "duws\client\misc\fnc_camp_smoke.sqf";
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
titleCut ["", "BLACK FADED", 999];
waitUntil {sleep 0.1;!isNull player};
	while {!(["BOOT", "serverinit_complete from the server", {serverinit_complete}, 300] call fnc_waitLogged)} do {};
// Exactly one drain loop per client, and only below the wait above -- the function arrives
// with the registry the server publishes, so starting it any earlier races that. A line
// posted before this point is not lost: fnc_duws_dialogue queues without needing the loop.
//
// Guarded against re-entry: a JIP client re-runs INIT.sqf and so client_init, and a second drain
// would race the first popping the same queue into the one subtitle slot, playing queued lines
// out of order. Guarded on the loop's own handle, not a bool: uiNamespace outlives a mission
// restart but the spawned loop does not, so a bool would strand the guard set with no loop
// running and silence every subtitle from the second mission of a session on. scriptDone reads
// true once the loop is gone (restart) and false while it runs (JIP re-init this mission).
private _drain = uiNamespace getVariable ["DUWS_dialogueDrainHandle", scriptNull];
if (isNull _drain || {scriptDone _drain}) then {
	// A restart leaves last mission's queued lines in uiNamespace -- it outlives the mission and the
	// dead drain never played them. Drop both queues so the fresh drain starts clean instead of
	// flushing a backlog of stale dialogue at mission start. Safe: nothing queues a line before this
	// point (it sits below the serverinit_complete wait), so no live line is lost.
	uiNamespace setVariable ["DUWS_dialogueQueueVoice", []];
	uiNamespace setVariable ["DUWS_dialogueQueueNet", []];
	uiNamespace setVariable ["DUWS_dialogueDrainHandle", [] spawn fnc_duws_dialogue_drain];

	// SUB-NET radio log: drop last mission's lines and pacing cursor, then raise the overlay on
	// its own layer so nothing else's cutRsc replaces it (or it, theirs). Held up all mission by
	// its huge duration; fnc_duws_subnet_render redraws it, ageing and fading each line.
	uiNamespace setVariable ["DUWS_subnetLines", []];
	uiNamespace setVariable ["DUWS_subnetNextAt", 0];
	("DUWS_SubnetLog" call BIS_fnc_rscLayer) cutRsc ["DUWS_SubnetLog", "PLAIN", 0, false];
	private _render = uiNamespace getVariable ["DUWS_subnetRenderHandle", scriptNull];
	if (!isNull _render) then { terminate _render };
	uiNamespace setVariable ["DUWS_subnetRenderHandle", [] spawn fnc_duws_subnet_render];
};
player addRating 10000000;
// KEEP DIPSHITS FROM DROWNING
[] spawn {
	while {!WARCOM_init_done} do {
		player setOxygenRemaining 1;
		sleep 10;
	};
};
fnc_remoteBoard = compile preprocessFileLineNumbers "duws\client\misc\fnc_remoteBoard.sqf";
publicVariable "fnc_remoteBoard";
if (!isMultiplayer) then {
	game_master = vehiclevarname player;
};

#include "includes\supports_init.hpp"
#include "includes\squad_number_init.hpp"

// One track over the setup screens, which is all the day-cycle loop deleted from here ever
// contributed before it started: the loop running underneath the whole campaign is what made
// music read as a menu, not this. Replaced at the insertion flight.
playMusic ["LeadTrack02_F", 0];

// JIP SCREEN, open map
if (isMultiplayer) then {
	
	if (((vehiclevarname player) != "player1" && !WARCOM_init_done) || WARCOM_init_done) then {
		titleCut ["", "BLACK IN", 10];
		forceMap true;
		mapAnimAdd [3, 1, [5000,5000]];
		mapAnimCommit;
		sleep 3;
		openMap [true, true];
	};

};

if (((vehiclevarname player) in game_master) && !HQ_pos_found_generated) then {

	// Faction + HQ placement + custom-faction paste + environment menu are owned
	// by fnc_startup_faction_flow (called at the enviro spawn point below) so the
	// environment screen's Back button can re-enter them to re-pick faction/HQ.

	//  ZONE SETTINGS DIALOG
	if (!zones_created) then {

		// SHOW THE STARTUP ENVIRO MENU
		if (!zones_created) then {
			sleep 0.1;
			[] call fnc_startup_faction_flow;
			while {!(["BOOT", "chosen_settings (player still in setup screens)", {chosen_settings}, 600] call fnc_waitLogged)} do {};
		};
	};
};

// Open Map for Gamemaster (Random Zones)
if ((vehiclevarname player) in game_master && !manually_chosen) then {
	titleCut ["", "BLACK IN", 10];
	forceMap true;
	mapAnimAdd [3, 1, PosOfBLUHQ];
	mapAnimCommit;
	sleep 3;
	openMap [true, true];
};

waitUntil {isPlayer Player};

if (((vehiclevarname player) in game_master)) then {
	while {!(["ZONES", "serv_zones_array broadcast by the server", {count serv_zones_array > 0}, 300] call fnc_waitLogged)} do {};
} else {
	if (!WARCOM_init_done) then {
		hintsilent "Waiting for serverinit_complete";
		while {!(["BOOT", "serverinit_complete (JIP)", {serverinit_complete}, 300] call fnc_waitLogged)} do {};
		waitUntil {
			hintsilent localize "STR_DUWS_T_waithostsetup";
			sleep 5;
			HQ_pos_found_generated && chosen_settings
		};
	};
};

waituntil {sleep 1;WARCOM_init_done;};

// Each registers a Draw3D handler and returns, so call rather than spawn.
[] call fnc_killhouse_markers;
[] call fnc_draw_world_icons;
[] call fnc_sabotage_laptop_markers;
[] call fnc_protect_civ_markers;


if (isMultiplayer) then {

	// change the shown CP for request dialog
	"commandpointsblu1" addPublicVariableEventHandler {ctrlSetText [1000, format["%1",commandpointsblu1]]; };
	// same for the AP wallet, so a spend shows on the request dialog's AP box at once, like CP
	"WARCOM_blufor_ap" addPublicVariableEventHandler {ctrlSetText [1002, format["%1",WARCOM_blufor_ap]]; };
	
	["INFO", "BOOT", format ["BLUFOR Faction init for JIP: %1", BLUFOR_FactionFile_X]] call fnc_log;
	if (BLUFOR_FactionFile_X == "CUSTOM") then {
		while {!(["FACTION", "BLUfactionData (JIP custom faction)", {count BLUfactionData > 0}, 300] call fnc_waitLogged)} do {};
		{
			call compile _x;
		} forEach BLUfactionData;
	} else {
		[] call fnc_BLUFOR_FactionFile_X;
	};
	sleep 1;
	// The run above is for the request-menu catalogue, which the confirmation screen's schema does
	// not cover -- but it also puts the faction file's own classnames back over the role globals.
	// Re-apply the locked table so this machine fields what the player confirmed.
	[] call fnc_faction_apply_locked;
	["INFO", "BOOT", format ["Blufor Faction init for JIP complete.  Rifleman: %1", blufor_SOLDIER_X]] call fnc_log;

};

// CP death-penalty EventHandler (no penalty inside the killhouse).
player addEventHandler ["killed", {
    private _inKillhouse = false;
    private _khX = missionNamespace getVariable ["killhouse_centerX", nil];
    private _khY = missionNamespace getVariable ["killhouse_centerY", nil];
    private _khZ = missionNamespace getVariable ["killhouse_centerZ", nil];
    if (!isNil "_khX" && !isNil "_khY" && !isNil "_khZ") then {
        private _deathPos = getPosWorld (_this select 0);
        if (_deathPos distance [_khX, _khY, _khZ] < 300) then {
            _inKillhouse = true;
        };
    };
    if (!_inKillhouse) then {
        [-DUWSMP_CP_death_cost, "death_penalty"] remoteExec ["fnc_cp_adjust", 2];
        // Told to the player who paid it: the deduction itself only ever reached the RPT and
        // control 1000 (the request dialog's counter, invisible unless that dialog is open),
        // leaving CP gone from the pool with nothing on screen. Skipped at zero, which the
        // campaign menu can still select. Spawned because an event-handler body is unscheduled
        // and the notification queue is not.
        if (DUWSMP_CP_death_cost > 0) then {
            [DUWSMP_CP_death_cost] spawn {
                params ["_cost"];
                ["CPlost", [_cost]] call bis_fnc_showNotification;
            };
        };
        // The consumable slate dies with the body. Inside the killhouse it does not, for the same
        // reason the CP penalty is waived there: a training death is not a battlefield one.
        [] call fnc_support_wipe;
    };
    // Reported unfiltered: a challenge run fails on a death inside the course, and the server
    // owns that test against its own area radius rather than the wider one used just above.
    [_this select 0, getPosWorld (_this select 0)] remoteExec ["killhouse_srv_player_died", 2];
}];

// Stamina/fatigue from the lobby param (default off). Drives the player here and the AI units
// they field: recruits/requests/paradrops read player_fatigue at spawn.
player_fatigue = ["DUWS_Fatigue", 0] call BIS_fnc_getParamValue;
player enableStamina (player_fatigue != 0);

// First-person restriction from the lobby param (default off). Camera view is local, so the
// watch runs here on each client. The inner wait for mode 2 is load-bearing: without it, sitting
// in permitted vehicle third person would spin the loop every frame (outer waitUntil keeps
// returning while cameraView stays EXTERNAL). isNull objectParent player == on foot.
private _restrict1P = ["DUWS_RestrictFirstPerson", 0] call BIS_fnc_getParamValue;
if (_restrict1P > 0) then {
	[_restrict1P] spawn {
		params ["_mode"];
		while {true} do {
			waitUntil { alive player && {cameraView == "EXTERNAL"} };
			if (_mode == 2 && {!isNull objectParent player}) then {
				waitUntil { cameraView != "EXTERNAL" || {isNull objectParent player} || {!alive player} };
			} else {
				player switchCamera "INTERNAL";
			};
		};
	};
};
// Traits go to everyone, deliberately not gated: any player should be able to use a medkit or
// toolkit on a squadmate, and a UAV terminal is a personal tool rather than a command
// privilege. Keeping these out of Squad_Leaders is what lets that array be trimmed to a few
// slots without silently taking revives away from the rest of the team.
player setUnitTrait ["Medic",true];
player setUnitTrait ["Engineer",true];
player setUnitTrait ["uavHacker",true];

// Squad-lead extras: High Command, and the FOB support row that arrives once BLUFOR holds a zone.
if ((vehiclevarname player) in Squad_Leaders) then {
	// wait until blu captures at least one zone
	[] spawn fnc_fob_unlock_notice;
	["INFO", "BOOT", "HC init"] call fnc_log;
	[] spawn fnc_hc_init;
};

[] spawn fnc_operator_init;


// INIT Markers if difficulty < veteran
_difficulty_setting = difficulty;
[] call fnc_kndr_unit_markers;
if (_difficulty_setting < 2 || (difficultyOption "mapContentFriendly") == 1) then { 
	if (isMultiplayer) then {
		["players"] spawn fnc_player_markers;
	};
};

// INIT Earplugs -- available on foot as well as mounted; fadeSound is a client-wide setting,
// so nothing about the toggle was ever vehicle-specific. The action dies with the body, so
// onPlayerRespawn.sqf re-adds it.
player addaction [ACT_UTIL("STR_DUWS_T_2rc0nvug"),fnc_earplugs, [], 20, true, true, "", "_this == player && {profileNamespace getVariable ['DUWS_T_showEarplugs', true]}"];

// Body search. Same re-add reason as the earplugs above: it dies with the body.
[] call fnc_intel_search_action;

// Developer tools. Two gates, because the parameter is mission config and so reads the same on
// every machine: on its own it would give the whole server a button that makes the server work.
// game_master is the existing campaign-control list. Attached to the player rather than an object
// so it is reachable anywhere on the map, and it dies with the body, so onPlayerRespawn re-adds.
if ((["DUWS_Debug", 0] call BIS_fnc_getParamValue) == 1 && {(vehiclevarname player) in game_master}) then {
	player addAction [ACT_UTIL("STR_DUWS_T_DEBUG_ACTION"), fnc_debug_menu, [], 20, true, true, "", "_this == player"];
};

// Create Diary/Help entry on the Map
[] spawn fnc_duws_help;

// Campaign config readout -- its own Notes subject, spawned after the manual so it lists second.
[] spawn fnc_duws_config;

// Add HQ actions for REQUEST Players
[bluHQ_object] spawn fnc_HQaddactions;

hint localize "STR_DUWS_T_zu4bxt24";

// Loadout swap: copy a random base-guard combat unit's gear (whitelisted).
[] spawn {
    waitUntil { sleep 0.5; !isNil "PosOfBLUHQ" && {count PosOfBLUHQ > 0} };
    sleep 8;  // wait for base guards and patrols to finish spawning

    // base-guard unit pool, set and broadcast by fnc_BluHQinit
    private _guardTypes = missionNamespace getVariable ["HQ_redeploy_guardTypes", [
        blufor_SOLDIER_X, blufor_LAT_SOLDIER_X, blufor_GL_SOLDIER_X,
        blufor_TL_SOLDIER_X, blufor_SL_SOLDIER_X, blufor_AR_SOLDIER_X,
        blufor_MARK_SOLDIER_X
    ]];

    private _nearbyUnits = nearestObjects [PosOfBLUHQ, ["CAManBase"], 150] select {
        side _x == WEST && alive _x && !isPlayer _x
    };

    private _combatUnits = _nearbyUnits select { typeOf _x in _guardTypes };

    if (count _combatUnits > 0) then {
        private _template = selectRandom _combatUnits;
        player setUnitLoadout (getUnitLoadout _template);
    } else {
        systemChat localize "STR_DUWS_T_loadout_copy_none";
    };

    // Final snapshot: both the restricted arsenal (startup-kit classes stay unlimited, else the copied
    // gear reads [0]) and respawn (Saved_Loadout restores the deploy kit) must see the loadout AFTER
    // this copy. The inline captures below may run before this spawn, so re-take both here where the
    // loadout is settled.
    player setVariable ["Saved_Loadout", getUnitLoadout player];
    private _kit = [];
    [getUnitLoadout player, _kit] call DUWS_fnc_extractLoadoutItems;
    player setVariable ["DUWS_startupKit", _kit];
};

// Hold the map open until zones and towns are both registered. The generation progress
// banner renders on the map display, so closing here would hide the tail of the run.
while {!(["BOOT", "mission_init_complete (zones built, civilians registered)",
    {mission_init_complete}, 300] call fnc_waitLogged)} do {};

// Only now is this machine ready to be flown in: everything above it -- the JIP faction re-run, the
// squad-lead extras, the action set -- still had to happen, and the intro remoteExecs a seat onto
// this client. Announced here rather than beside fnc_remoteBoard at the top of this file, which
// says only that the function exists and let the server spawn the helicopter while the client was
// still initialising, boarding nobody.
player setVariable ["duws_intro_ready", true, true];

// Then held until the insertion flight is up, or until the intro reports it is not coming. The
// server spawns the helicopter, seats the player in it and only then fades in
// (server/misc/fnc_intro_heli.sqf), so waiting for it is what puts the cut in the right order: a
// fixed sleep would run on past that fade and black out a screen the server had just cleared,
// leaving the player in the cabin still looking at the map.
//
// intro_heli_done is in the condition because a failed spawn publishes an objNull helicopter, which
// this can never see turn up; without it the map stayed pinned for the whole timeout while the
// intro played its dialogue underneath.
["BOOT", "intro_heli_object (insertion flight spawned)",
    {!isNull (missionNamespace getVariable ["intro_heli_object", objNull])
        || {!isNil "intro_heli_done"}}, 120] call fnc_waitLogged;

// Black first, map second: the server's fade-in is what clears this, and the black is what hides the
// switch from the map display to the cabin. The pause is for the black to paint, not for pacing.
titleCut ["", "BLACK FADED", 999];
uiSleep 0.3;
forceMap false;
openMap [false, false];
// Survival modes (RAVAGE/WBK) force client-side fog, identically.
if (CIV_PRESENCE in ["RAVAGE", "WBK"]) then {
    waitUntil {!isNull player};
    // fog: intensity 0.5, decay 0.1, base height 10
    0 setFog [0.5, 0.1, 10];
    0 setOvercast 0.8;
    forceWeatherChange;
    ["INFO", "BOOT", format ["%1 mode: Client-side fog forced.", CIV_PRESENCE]] call fnc_log;
};
// Bounded: an unbounded wait here stalls the client ahead of every later boot milestone, and the
// flag is broadcast rather than derived, so a joiner that misses it would never proceed. The
// local default keeps the read below from tripping over nil; the publicVariable handler further
// down applies a value that lands late.
["BOOT", "apocalypse_mode broadcast", {!isNil "apocalypse_mode"}, 300] call fnc_waitLogged;
if (isNil "apocalypse_mode") then { apocalypse_mode = false };

// filter-apply function, kept callable so respawn can reapply it
DUWS_fnc_applyApocalypseFilter = compile preprocessFileLineNumbers "duws\client\misc\fnc_applyApocalypseFilter.sqf";

if (apocalypse_mode) then {
    call DUWS_fnc_applyApocalypseFilter;
};

// watch the public variable so it applies on JIP or a mid-game toggle
"apocalypse_mode" addPublicVariableEventHandler {
    if (_this select 1) then {
        call DUWS_fnc_applyApocalypseFilter;
    } else {
        ppEffectDestroy 15001;
        ppEffectDestroy 15002;
        ppEffectDestroy 15003;
    };
};

if (CIV_PRESENCE == "RAVAGE") then {
    ["biohazard", [localize "STR_DUWS_T_ravage", localize "STR_DUWS_T_ZOMBIE_NOREP"]] remoteExec ["BIS_fnc_showNotification", 0];
};
if (CIV_PRESENCE == "WBK") then {
    ["biohazard", [localize "STR_DUWS_T_wbk", localize "STR_DUWS_T_WBK_NOREP"]] remoteExec ["BIS_fnc_showNotification", 0];
};
// Bounded and logged, and deliberately not wrapped in the while-retry the other boot waits use:
// misc/fnc_intro_heli.sqf exits without publishing this flag when PosOfBLUHQ is undefined, and
// an unbounded wait there leaves the player invulnerable and unteleported with nothing in the
// log. Proceeding on timeout at least reaches allowDamage true below.
["BOOT", "intro_heli_done (intro drop finished)", {!isNil "intro_heli_done"}, 420] call fnc_waitLogged;

// The position guard is what makes the timeout above survivable: server_var_init.sqf broadcasts
// PosOfBLUHQ as [], so on the early-exit path the client holds an empty array rather than nil,
// and BIS_fnc_findSafePos would fall back to [0,0,0] and leave `[] getPos [...]` to kill this
// thread before allowDamage true below.
if (!(player getVariable ["intro_completed", false]) && {!isNil "PosOfBLUHQ" && {count PosOfBLUHQ > 0}}) then {
    private _safePos = [PosOfBLUHQ, 0, 30, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then {
        _safePos = PosOfBLUHQ getPos [random 10, random 360];
    };
    player setPos _safePos;
	[["", "BLACK IN", 2]] remoteExec ["titleCut", player];
    player setVariable ["intro_completed", true];
    ["INFO", "BOOT", format ["Teleported %1 to base.", name player]] call fnc_log;
};

playMusic ["EventTrack01a_F_EPA", 0];
hintsilent format[localize "STR_DUWS_T_ix8g2neb",worldName,profileName];

// force a weather update so it renders correctly
forceWeatherChange;

// Saved_Loadout and DUWS_startupKit are provisional here: the base-guard loadout copy runs in the spawn
// above and may land after this line, so the copy spawn re-takes both once the loadout is final -- else
// respawn restores the editor default and the copied gear reads [0] in the restricted arsenal.
player setVariable["Saved_Loadout", getUnitLoadout player];
private _startupKit = [];
[getUnitLoadout player, _startupKit] call DUWS_fnc_extractLoadoutItems;
player setVariable ["DUWS_startupKit", _startupKit];
player setdamage 0;
player allowDamage true;
// Zeus disconnect fix and Add SITREP to Gamemaster	
if ((vehiclevarname player) in game_master || !isMultiplayer) then {
	// Zeus disconnect fix
	[Curator] remoteExec ["unassignCurator",2];
	sleep 2;
	[player, Curator] remoteExec ["assignCurator",2];
	[] spawn {
		sleep 10;
		[player,"sitrep"] call BIS_fnc_addCommMenuItem;
		// The campaign task waits on this so orders never arrive before the radio that
		// reports on them. Only this machine adds the item, so only it can say when.
		sitrep_granted = true; publicVariable "sitrep_granted";
	};
};

sleep 20;
// Scroll-menu action opens the disguise panel (fnc_disguise_menu). A hold-action was rejected:
// its "Hold Space" prompt sits centre-screen the whole time the show-condition holds (alive,
// on foot -> effectively always) and blocks the view. showWindow=false keeps this off-centre
// -- it appears only in the scroll menu. The CIV_PRESENCE gate lives inside the panel.
if (isNil {player getVariable "DUWS_disguiseMenu_actionAdded"}) then {
    player addAction [
        ACT_EQUIP("STR_DUWS_T_DISGUISE_MENU_ACTION"),
        { [] spawn fnc_disguise_menu; },
        nil,
        1,
        false,
        true,
        "",
        "alive _target && vehicle _target == _target && {profileNamespace getVariable ['DUWS_T_showDisguise', true]}"
    ];
    player setVariable ["DUWS_disguiseMenu_actionAdded", true];
};
// disguise feature: set captive state locally
fnc_disguise_setCaptiveLocal = compile preprocessFileLineNumbers "duws\client\civilian\fnc_disguise_setCaptiveLocal.sqf";
publicVariable "fnc_disguise_setCaptiveLocal";
