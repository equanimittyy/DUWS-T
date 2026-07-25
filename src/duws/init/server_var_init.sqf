
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

// amount_zones_captured
amount_zones_captured = 0;publicVariable "amount_zones_captured";

// AO direction for Random Zones
AO_direction = [];

// Array_of_FOBS
Array_of_FOBS = [];publicVariable "Array_of_FOBS";
Array_of_FOBname = [];publicVariable "Array_of_FOBname";

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

// Damaged Buildings for the Warcrimes Script
damagedBuildings = [];

// SET DEFAULT DUWS MODE
DUWS_MODE = "CAMPAIGN";publicVariable "DUWS_MODE";

// Death Penalty
DUWSMP_CP_death_cost = 0;publicVariable "DUWSMP_CP_death_cost";

// dynamic_weather_enable
dynamic_weather_enable = true;publicVariable "dynamic_weather_enable";	

// commandpointsblu1
commandpointsblu1 = 20;publicVariable "commandpointsblu1";

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
fnc_QRF_test = compile preprocessFile "duws\functions\warcom\fnc_WARCOM_opf_qrf.sqf";

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

// zone_namePOS_pairs
zone_namePOS_pairs = [];publicVariable "zone_namePOS_pairs";
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

// CREATE THE ARRAYS FOR GAME MASTER and REQUEST PLAYERS
game_master = ["player1"];publicVariable "game_master";

Request_Players = [
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
]; publicVariable "Request_Players";
