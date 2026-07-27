// Locality: server -- see callers.

//////////////////////////////////////////////////////
// INIT A BUNCH OF VARIABLES
//
// SOME OF THESE VALUES ARE BEING OVERWRITTEN 
//  BY PLAYER INPUT IN THE CONFIG MENU
//////////////////////////////////////////////////////

// SET THE VERSION
VERSION_X = "MODERN";publicVariable "VERSION_X";
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// FACTION DEFAULTS
OPFOR_Faction_X = "OPF_F";
BLUFOR_Faction_X = "BLU_F";
switch (VERSION_X) do {
	
	case "MODERN": {
		BLUFOR_Faction_X = "BLU_F";publicVariable "BLUFOR_Faction_X";
		OPFOR_Faction_X = "OPF_F";publicVariable "OPFOR_Faction_X";
	};
	
};

BLUFOR_FactionFile_X = "";publicVariable "BLUFOR_FactionFile_X";
OPFOR_FactionFile_X = "";publicVariable "OPFOR_FactionFile_X";

BLUfactionDataTemp = "";publicVariable "BLUfactionDataTemp";
OPFfactionDataTemp = "";publicVariable "OPFfactionDataTemp";
BLUfactionData = [];publicVariable "BLUfactionData";
OPFfactionData = [];publicVariable "OPFfactionData";

Factions_Available_OPFOR_X = [];publicVariable "Factions_Available_OPFOR_X";
Factions_Available_BLUFOR_X = [];publicVariable "Factions_Available_BLUFOR_X";

// amount_zones_created
amount_zones_created = 0;publicVariable "amount_zones_created";

// Zones whose build-out finished, as opposed to amount_zones_created, which fnc_createZone
// bumps on entry. Civilian generation needs "built", not "started": it counts buildings,
// and prefab zones hide everything within 35 m of their centre partway through build-out.
zones_buildout_done = 0;publicVariable "zones_buildout_done";

// amount_zones_captured
amount_zones_captured = 0;publicVariable "amount_zones_captured";

// AO direction for Random Zones
AO_direction = [];

// Array_of_FOBS
// The three arrays are index-parallel: entry i of each describes one FOB. Every writer must
// append to all three and every remover must delete the same index from all three, or a FOB's
// name and position separate from its building.
Array_of_FOBS = [];publicVariable "Array_of_FOBS";
Array_of_FOBname = [];publicVariable "Array_of_FOBname";
Array_of_FOBpos = [];publicVariable "Array_of_FOBpos";

// Opfor gets Air
AttackHeli = 1;publicVariable "AttackHeli";

// set the default skill range
blufor_ai_skill = [0.85,1.0];publicVariable "blufor_ai_skill";

// change primary target
BLUFOR_primary_chg = false;publicVariable "BLUFOR_primary_chg";

// chosen_hq_placement
chosen_hq_placement = false;publicVariable "chosen_hq_placement";

// chosen_settings
chosen_settings = false;publicVariable "chosen_settings";

// Player squad callsign, set on the callsign setup screen and substituted into
// English radio dialogue by fnc_cs. Default matches the "Alpha 1-1" literal baked
// into the stringtable, so an unchanged callsign leaves every line untouched.
duws_callsign = "Alpha 1-1";publicVariable "duws_callsign";

// CIV_deaths
CIV_deaths = 0;publicVariable "CIV_deaths";

// cp_reward_multiplier
cp_reward_multiplier = 1;publicVariable "cp_reward_multiplier";

// Kill income. Every kill_cp_interval seconds each player's kill tally converts at
// kill_cp_award CP per kill_cp_kills kills; the paid-for kills are debited and the
// remainder carries to the next sweep. Server-only: the tally, the sweep and the payout
// all live on the server, so no client ever reads these.
kill_cp_interval = 1800;
kill_cp_kills = 10;
kill_cp_award = 1;

// Damaged Buildings for the Warcrimes Script
damagedBuildings = [];

// [object, seconds] pairs awaiting pickup by the map cleanup, written through
// fnc_duws_disposeAfter and drained every pass. Server-only: the sweep runs here and clients
// reach it by remoteExec.
DUWS_disposables = [];

// composition key -> the objects it owns, written through fnc_duws_keep. Every member is
// tagged persistent so no sweep touches a standing composition, and the key exists so
// fnc_duws_release can bin all of it at once. Tracking is what makes that possible: the
// sandbags and camo net of a wrecked hardpoint are undamaged props, so no test of the objects
// themselves -- dead, immobile, littered -- would ever collect them.
DUWS_compositions = createHashMap;

// One-shot request for the map cleanup to sweep now, ignoring both remaining lifetimes and the
// keep-radius. Set through fnc_duws_forceCleanup; the sweep waits on this as well as on its
// interval, and clears it, so a request cannot spill into the pass after the one that served it.
DUWS_cleanup_force = false;

// Death Penalty
DUWSMP_CP_death_cost = 0;publicVariable "DUWSMP_CP_death_cost";

// dynamic_weather_enable
dynamic_weather_enable = true;publicVariable "dynamic_weather_enable";	

// commandpointsblu1
commandpointsblu1 = 20;publicVariable "commandpointsblu1";

// Zones built out and civilians registered, successfully or not. Everything the player sees
// as "the campaign has started" -- the completion banner, the intro helicopter, the map
// closing -- waits on this, so generation never runs on under a player already in the field.
mission_init_complete = false;publicVariable "mission_init_complete";

// zone settings complete
createzone_server = false;publicVariable "createzone_server";

// FOB fast travel
enable_fast_travel = true;publicVariable "enable_fast_travel";

// Opfor zone/mission patrol size
enemyunitMultiplier = 2;publicVariable "enemyunitMultiplier";

// failsafe for Random zones
failsafe_zones_not_found1 = false;//publicVariable "failsafe_zones_not_found1";
failsafe_zones_not_found2 = false;//publicVariable "failsafe_zones_not_found2";

// FOB_removed keeps fnc_fob_destroyed from running
FOB_removed = false;//publicVariable "FOB_removed";

// FogArray
FogArray = [];publicVariable "FogArray";

// allow TFs to begin assault, hardcore mode will set false
hardcore_visibleZone_found = true;publicVariable "hardcore_visibleZone_found";

// Hardcore Mode
hardcore_mode_enable = false;publicVariable "hardcore_mode_enable";

// Opfor gets tanks
HeavyArmor = 1;publicVariable "HeavyArmor";

// hq_manually_placed
hq_manually_placed = false;publicVariable "hq_manually_placed";

// HQ spawns complete
HQ_pos_found_generated = false;publicVariable "HQ_pos_found_generated";

// All usable locations
MASTER_allLocations_filtered = [];//publicVariable "MASTER_allLocations_filtered";
MASTER_allLocationsPos = [];publicVariable "MASTER_allLocationsPos";

// chance of Intel found and useful
master_Intel_chance = 5;
// boost is for more "found"
master_Intel_boost = 2.5;

// manually_chosen
manually_chosen = false;publicVariable "manually_chosen";

// Side Mission wait
Mission_available = true;publicVariable "Mission_available";

// Locations for mission placement
MissionLocations = [];publicVariable "MissionLocations";

// moreUrban zones and missions
moreUrban = 1;publicVariable "moreUrban";

// set the default skill range
opfor_ai_skill = [0.55,0.75];publicVariable "opfor_ai_skill";

// declare opfor rifleman variable
opfor_SOLDIER_X = "";

// OvercastVar
OvercastVar = 0;publicVariable "OvercastVar";

// HQ chat
PAPABEAR=[West,"HQ"];publicVariable "PAPABEAR";

// Player_Reputation
Player_Reputation = 1;publicVariable "Player_Reputation";

// player_is_choosing_hqpos
player_is_choosing_hqpos = false;publicVariable "player_is_choosing_hqpos";

// PosOfBLUHQ
PosOfBLUHQ = [];publicVariable "PosOfBLUHQ";

// preprocess the qrf file for the EH
fnc_QRF_test = compile preprocessFile "duws\server\warcom\fnc_WARCOM_opf_qrf.sqf";

//serv_zones_array
serv_zones_array = [];publicVariable "serv_zones_array";

// simple_zones_enable
simple_zones_enable = false;publicVariable "simple_zones_enable";

apocalypse_mode = false; publicVariable "apocalypse_mode";

// time_Multiplier
time_Multiplier = 1;publicVariable "time_Multiplier";

// STARTING ARMY POWER
WARCOM_blufor_ap = 0;publicVariable "WARCOM_blufor_ap";
WARCOM_opfor_ap = 0;publicVariable "WARCOM_opfor_ap";
WARCOM_init_done = false;publicVariable "WARCOM_init_done";

// PATROL TYPES
WARCOM_opf_patrol_type = [];
WARCOM_opf_attack_wave_type = [];
WARCOM_blu_attack_wave_type = [];
WARCOM_opf_air = false;

// DEFAULT WEATHER
// choose between "none" - "tropical" - "arid" - "temperate" - "temperate_cold" - "mediterranean"
weather_type = "none";publicVariable "weather_type";

// Zeus visibility
ZeusStatus = 2;publicVariable "ZeusStatus";

// Civilian faction. Defaulted here like every other environment setting: six subsystems
// read it with no isNil guard, so leaving it unset makes each of them error separately and
// civilians never generate, with nothing in the log naming the cause.
CIV_PRESENCE = "NONE";publicVariable "CIV_PRESENCE";

// zone_namePOS_pairs
zone_namePOS_pairs = [];publicVariable "zone_namePOS_pairs";
// zone_meta_array: [zone number, position, radius, capture points, fortified, prefab] per zone.
// Keyed by the zone number it carries, not by array position -- the locator spawns fnc_createZone
// per zone, so build-out finishes out of order and registration order is not zone order.
zone_meta_array = [];publicVariable "zone_meta_array";
// zone_spawn_array
zone_spawn_array = [];
// zones_created
zones_created = false;publicVariable "zones_created";
// zones_manually_placed
zones_manually_placed = false;publicVariable "zones_manually_placed";
//zones_max_dist_from_hq
zones_max_dist_from_hq = 0;publicVariable "zones_max_dist_from_hq";
// Number of capturables zones to create (when zones are created randomly)
zones_number = 6; 
// minimum space between 2 zones (in meters) // SOON OBSOLETE
zones_spacing = 1200; 
// Determine the maximum radius a generated zone can have
zones_max_radius = 1000;publicVariable "zones_max_radius"; 
// Determine the minium radius a generated zone can have. SHOULD NOT BE UNDER 200.     
zones_min_radius = 200;publicVariable "zones_min_radius"; 

// zoneundercontrolblu
zoneundercontrolblu = 0;publicVariable "zoneundercontrolblu";

insurgent_mode_enable = false; publicVariable "insurgent_mode_enable";

// enable ZBE units caching
//ZbeCacheStatus = ["ZBEcache", 1] call BIS_fnc_getParamValue;
//if (ZbeCacheStatus == 1) then {
//	if (isServer) then {[1000,-1,false,1500,1500,1500]execvm "modules\zbe_cache\main.sqf"};
//};

// Two permission lists of playable slot names, both checked as
// (vehiclevarname player) in <list>. game_master owns campaign-level controls -- the setup
// flow, side-mission requests, the global heal. Squad_Leaders owns anything that spends the
// shared CP pool -- the request menus, radio supports, MHQ, FOB upkeep -- plus High Command.
//
// Squad_Leaders lists every playable slot today, so it restricts nothing as shipped. It exists
// to be trimmed: on a dedicated server, cutting it to the actual squad-lead slots restricts all
// of the above in one edit. Nothing outside a permission check may read it -- personal kit such
// as the medic/engineer/UAV traits is granted unconditionally in client_init.sqf, precisely so
// that trimming this cannot take basic capability away from the rest of the team.
game_master = ["player1"];publicVariable "game_master";

Squad_Leaders = [
	"player1",
	"player2",
	"player3",
	"player4",
	"player5",
	"player6",
	"player7",
	"player8",
	"player9",
	"player10",
	"player11",
	"player12",
	"player13",
	"player14",
	"player15",
	"player16",
	"player17",
	"player18",
	"player19",
	"player20"
]; publicVariable "Squad_Leaders";
