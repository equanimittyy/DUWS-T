// Locality: client -- runs on the game-master client, the only machine that reaches the faction
// screen (client_init gates the whole setup flow on game_master). The BUILD FACTIONS screen's
// debug button (shared/includes/faction_screen.hpp, shown only when the DUWS_Debug mission param
// is on) routes here instead of the normal setup chain.
//
// One-click campaign start for testing. It stands in for the confirmation, HQ-placement,
// environment, campaign and callsign screens, applying each screen's own (Default) values and
// committing. Every value below MIRRORS the default branch of fnc_process_enviro_menu.sqf and
// fnc_process_campaign_menu.sqf: the dialogs stay the source of truth, so a default changed in one
// of those screens must be changed here too.

// The default game mode, whatever the faction combo was left on: the defaults below (med
// civilians, a vanilla OPFOR faction) describe the DUWS mode, not apocalypse or guerilla.
duws_gamemode = "duws";
publicVariable "duws_gamemode";

// fnc_intro_heli reads this and early-outs with no helicopter; client_init's
// intro_completed==false fallback then drops the player at base on its own.
DUWS_debug_skip_intro = true;
publicVariable "DUWS_debug_skip_intro";

// Row 0 of each side's list is its "(Default)" faction (NATO/CSAT arid, or whatever a faction mod
// seeds first) -- a concrete preset, so neither the paste window nor the AutoDetect picker is
// reached and no popup interrupts the one click.
BLUFOR_FactionFile_X = (Factions_Available_BLUFOR_X select 0) select 2;
OPFOR_FactionFile_X = (Factions_Available_OPFOR_X select 0) select 2;
publicVariable "BLUFOR_FactionFile_X";
publicVariable "OPFOR_FactionFile_X";

// The server resolves factions only when the confirmation screen bumps this counter
// (server_init.sqf): skip the bump and the commit's createzone_server breaks the resolve loop
// before the per-side faction inits run, leaving the campaign with no unit classes. Bump it as the
// screen would and wait for the server's answer. No rows are edited, so the locked table stays
// empty and the commit keeps the server's own resolution.
duws_faction_locked = [];
publicVariable "duws_faction_locked";
duws_faction_preview_request = duws_faction_preview_request + 1;
private _req = duws_faction_preview_request;
publicVariable "duws_faction_preview_request";
waitUntil { sleep 0.1; duws_faction_preview_ready >= _req };

// Random HQ: the safe-position search from fnc_HQ_random_place.sqf, without its map animation and
// AO-direction click. AO_direction is left at its [] default -- the same state the random-HQ path
// reaches when the player skips the direction click (ESC). Both readers guard count>0, so an empty
// one spreads zones evenly around the HQ rather than biasing them along an arc.
waitUntil { sleep 0.1; count MASTER_allLocationsPos > 100 };
private _location_count = count MASTER_allLocationsPos;
private _found = false;
private _foundSafePos = [];
while {!_found} do {
    private _location = MASTER_allLocationsPos select (floor (random _location_count));
    _foundSafePos = [_location, 200, 500, 10, 0, 0.15, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
    private _count = 1;
    while {true} do {
        if (_count > 100) exitWith {};
        private _Building = nearestBuilding _foundSafePos;
        _foundSafePos = [_Building, 50, 100, 15, 0, 0.08, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
        private _nearRoad = [_foundSafePos, 20] call BIS_fnc_nearestRoad;
        if (_foundSafePos select 0 != 0 && _foundSafePos select 1 != 0 && isNull _nearRoad) exitWith { _found = true };
        _count = _count + 1;
    };
};
PosOfBLUHQ = _foundSafePos;
publicVariable "PosOfBLUHQ";
chosen_hq_placement = true;
publicVariable "chosen_hq_placement";

// Environment-screen defaults (fnc_process_enviro_menu.sqf). Weather off leaves weather_type at
// server_var_init's "none".
dynamic_weather_enable = false;
time_of_day = 6;
civ_density = 10;
enable_fast_travel = true;
ZeusStatus = 1;
escalation_enabled = true;
simple_zones_enable = false;
moreUrban = 1;
CIV_PRESENCE = "med";
hardcore_mode_enable = false;
{ publicVariable _x; } forEach [
    "dynamic_weather_enable", "time_of_day", "civ_density", "enable_fast_travel", "ZeusStatus",
    "escalation_enabled", "simple_zones_enable", "moreUrban", "CIV_PRESENCE",
    "hardcore_mode_enable"
];

// Campaign-screen defaults (fnc_process_campaign_menu.sqf), including the values that screen derives
// rather than reads: zones_spacing and the per-run skill rolls.
zones_max_radius = 500;
zones_min_radius = 350;
zones_number = 1;
zones_max_dist_from_hq = 15000;
zones_spacing = zones_max_radius * 0.5;
commandpointsblu1 = 50;
cp_reward_multiplier = 1;
DUWSMP_CP_death_cost = 2;
WARCOM_blufor_ap = 0;
WARCOM_opfor_ap = 60;
blufor_ai_skill = [0.55, 0.75];
opfor_ai_skill = [0.35, 0.55];
blufor_ai_skill_random = (random ((blufor_ai_skill select 1) - (blufor_ai_skill select 0))) + (blufor_ai_skill select 0);
opfor_ai_skill_random = (random ((opfor_ai_skill select 1) - (opfor_ai_skill select 0))) + (opfor_ai_skill select 0);
AttackHeli = 1;
HeavyArmor = 1;
enemyunitMultiplier = 1;
garrison_density = 0.5;
{ publicVariable _x; } forEach [
    "zones_max_radius", "zones_min_radius", "zones_number", "zones_max_dist_from_hq", "zones_spacing",
    "commandpointsblu1", "cp_reward_multiplier", "DUWSMP_CP_death_cost", "WARCOM_blufor_ap",
    "WARCOM_opfor_ap", "blufor_ai_skill", "opfor_ai_skill", "blufor_ai_skill_random",
    "opfor_ai_skill_random", "AttackHeli", "HeavyArmor", "enemyunitMultiplier", "garrison_density"
];

// The callsign screen's Confirm is the single commit point (createzone_server + chosen_settings,
// plus the setup log). Called with no dialog open: it reads the callsign edit box, which returns ""
// and falls back to "Alpha 1-1", and commits random zone placement (_manual = false).
[false] call fnc_callsign_confirm;
