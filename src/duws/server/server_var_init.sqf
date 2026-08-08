// Locality: server -- see callers.
// The config menu overwrites many of these from player input; treat the values here as defaults.

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

// The faction dropdown's own answer -- a faction-file token, or "CUSTOM"/"AUTODETECT". Kept apart
// from *_Faction_X because faction init overwrites that one with the faction class the random
// vehicle patrols read, and resolution now runs again every time the setup screens are stepped
// back through. These default to the rows the two combos open on.
BLUFOR_FactionFile_X = "BLU_F_ARID";publicVariable "BLUFOR_FactionFile_X";
OPFOR_FactionFile_X = "OPF_F_ARID";publicVariable "OPFOR_FactionFile_X";

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

// The faction confirmation screen's handshake. Request and ready are counters, not flags: stepping
// back from the environment screen re-enters faction selection and the screen asks again, and a
// flag cleared by the server can race a fresh request raised by the client. The screen waits for
// ready to reach the number it asked with, so it can never read the previous pick's rows.
//
// duws_faction_locked is the whole table the player confirmed -- [[side, [[key, value], ...]], ...]
// -- carried whole rather than as a diff, so the server has one code path to apply rather than a
// reconciliation to work out.
duws_faction_preview_request = 0;publicVariable "duws_faction_preview_request";
duws_faction_preview_ready = 0;publicVariable "duws_faction_preview_ready";
duws_faction_locked = [];publicVariable "duws_faction_locked";

// Player squad callsign, set on the callsign setup screen and substituted into
// English radio dialogue by fnc_cs. Default matches the "Alpha 1-1" literal baked
// into the stringtable, so an unchanged callsign leaves every line untouched.
duws_callsign = "Alpha 1-1";publicVariable "duws_callsign";


// cp_reward_multiplier
cp_reward_multiplier = 1;publicVariable "cp_reward_multiplier";

// Kill income. On each campaign economy tick a player's kill tally converts at
// kill_cp_award CP per kill_cp_kills kills; the paid-for kills are debited and the
// remainder carries to the next sweep. The period is the economy tick's own and is not
// tunable here -- a second interval would mean a second clock. Server-only: the tally,
// the sweep and the payout all live on the server, so no client ever reads these.
kill_cp_kills = 10;
kill_cp_award = 1;

// Soldiers on the perimeter patrol, at the HQ and at every FOB alike. One figure for both because a
// FOB is a small base rather than a different kind of thing: it used to send a single soldier round
// a circuit that a two-man probe could walk through. Server-only, both spawns run there.
base_patrol_squad = 8;

// When a FOB or HQ garrison stops being simulated. Nothing culled it before, so every base's
// soldiers ran their pathing and targeting for the rest of the campaign whether or not anyone was
// within a kilometre. Server-only.
//
// Short on the way down and nothing at all on the way up: a base is frozen rather than rebuilt, so
// the only cost of freezing early is a garrison a returning player watches start moving, and that
// costs a frame. The zone streamer's two minutes buy a zone something this does not -- there, the
// clock stops a garrison being torn down and rebuilt around somebody crossing the radius.
base_garrison_sleep_range = 500;

// Streaming presence per site profile: [buffer, grace, latch, aiAware, minAI].
//   buffer   metres added to the site radius to make the ring presence is tested over
//   grace    seconds the empty ring waits before the site streams out (for a base, re-freezes)
//   latch    start latched, so a site registered under a player does not raise its garrison around them
//   aiAware  gate on the AI-aware BLUFOR test (zones, town garrisons) rather than a plain player list
//   minAI    how many BLUFOR hold the ring to keep an aiAware site up
// A crowd is noticed 200 m out and cleared after 60 s where the garrison in the same town is 400 and
// 120: two answers about one town a single pair of fields would force into one. A base is 0 and a short
// grace because it is frozen where it stands, not streamed off the map. Read by the registration
// wrapper fnc_site_occupant_register_profile and, for the town's own gate and tick, by fnc_civ_garrison.
DUWS_streamProfiles = createHashMapFromArray [
    ["zone",       [400, 120, true,  true,  2]],
    ["town_crowd", [200,  60, false, false, 2]],
    ["town_gar",   [400, 120, true,  true,  2]],
    ["base",       [  0,  10, false, false, 2]]
];

// The consumable-support slate. support_max_slots is how many a player may hold at once, the
// campaign-long budget that makes choosing between them mean anything; support_death_refund is
// the share of what they paid that comes back when they die holding it. That share is deliberately
// small: a generous one would make dying a cheaper way to liquidate a slate than walking back to a
// base and refunding it, which is the opposite of what the death penalty is for. Both are read on
// clients, so both are broadcast.
support_max_slots = 8;      publicVariable "support_max_slots";
support_death_refund = 0.1; publicVariable "support_death_refund";

// How long a destroyed Mobile HQ locks designation out for. Losing it has to cost something, or
// leaving it parked at the objective and letting it burn is cheaper than driving it home -- the
// respawn point comes back within a minute either way. Read on clients, so it is broadcast.
MHQ_lockout_seconds = 1800; publicVariable "MHQ_lockout_seconds";

// Which permanent supports the team has bought, in purchase order. Their broadcast flags stay
// every client's fast path; this holds the same set as data a campaign save can walk, instead of
// as a scatter of named globals a restore would have to know one at a time.
DUWS_support_permanent = []; publicVariable "DUWS_support_permanent";

// Zone payouts, all shares rather than absolutes so they scale with a zone's size. Two
// separate figures ride the capture triggers: the zone's *worth*, fixed at generation from
// its radius and never reassigned, and its *bounty*, the CP the next capture pays.
//
// AP is measured against the worth, so taking or losing a zone always swings the same
// momentum however many times it has changed hands -- a contested zone is still worth
// holding. The bounty shrinks on every capture instead: ground fought over repeatedly has
// been looted already, and a zone that keeps flipping should stop being a payday. That decay
// is deliberate, which is why it is a constant here rather than an artefact of the
// arithmetic. Server-only: the capture handlers all run server-side.
zone_cp_capture = 0.5;      // first capture pays this share of the zone's worth
zone_cp_recapture = 1/3;    // each recapture pays this share of the previous bounty
zone_ap_swing = 0.5;        // AP the taking side gains, as a share of worth; the loser sheds the same
zone_ap_consolation = 0.5;  // OPFOR's share of that swing when BLUFOR is the one taking

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

// composition key -> the records needed to rebuild it, written through fnc_duws_stow. Holds a key
// exactly while that composition's streamable members are off the map, so presence here answers
// "is this stowed" without touching an object. Not exclusive with DUWS_compositions: pinned
// members stay behind when the rest of their composition leaves, so a hardpoint whose gun never
// stows appears in both.
// Records are built when a composition is stowed rather than when it is built, so damage, looted
// crates and moved props are captured as they actually are. Transient by design -- nothing here
// outlives the session, and a campaign restore replays the builders instead.
DUWS_stowed = createHashMap;

// Keys retired through fnc_duws_release. A gate driving stow and deploy reads this to know its
// composition is finished and stop looping. Explicit rather than inferred from the key's absence
// everywhere else, which is equally true before build-out has run. Cleared by fnc_duws_keep so a
// key reused by a later composition at the same rounded coordinates is not born retired.
DUWS_retired = [];

// One-shot request for the map cleanup to sweep now, treating every lifetime as already elapsed.
// Set through fnc_duws_forceCleanup and cleared by the pass it wakes. A testing tool: it skips
// the wait for a 30 min deadline, but not KEEP_RADIUS and not the persistent flag.
DUWS_cleanup_force = false;

// The configured litter lifetime, published by the sweep once it reads the parameter. A global
// because the BuildingChanged handler needs it too, and an event handler cannot see the locals
// of the script that registered it.
DUWS_cleanup_lifetime = 1800;

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
enemyunitMultiplier = 1;publicVariable "enemyunitMultiplier";

// failsafe for Random zones
failsafe_zones_not_found1 = false;//publicVariable "failsafe_zones_not_found1";
failsafe_zones_not_found2 = false;//publicVariable "failsafe_zones_not_found2";

// FOB_removed keeps fnc_fob_destroyed from running
FOB_removed = false;//publicVariable "FOB_removed";

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

// [successChance, [[payoutKind, weight], ...]] per search source.
//
// The success roll is spent when the entity is created, not when it is searched. What the player
// can find is then a function of how much OPFOR the campaign put on the ground rather than of how
// often a key was pressed, which is what lets the per-player search clock go: the price of a
// search is the fight that produced the thing being searched.
//
// Weights, not a cumulative if-ladder. Every band in a ladder depends on the one above it, so
// adding a kind means re-deriving each constant below it; adding a row here is adding a row.
//
// Kinds are drawn without replacement. A kind whose payout reports nothing left to give drops out
// and the remainder are re-drawn, so an exhausted intel pool cannot turn a search into silence --
// the failure the mission already paid for once, when a dry pool returned quietly.
//
// civ_frisk is flagged on every civilian and carries its own `nothing` weight, which keeps the
// shipped 37.5 / 12.5 / 50 split exactly: the arrest is the price, and it is paid before this.
// What it no longer carries is a line of its own. The empty-handed result was written per source,
// on the reasoning that a body holding nothing and a detainee carrying nothing are different
// sentences -- but every one of these is the same act reported by the same searcher, and the one
// odd wording read as a different system rather than as a different subject.
//
// [successChance, [[payoutKind, weight], ...], nothingKey]
DUWS_searchSources = createHashMapFromArray [
    ["garrison",  [0.5,  [["intel", 2], ["pool", 3], ["coins", 2], ["document", 1]], "STR_DUWS_T_INTEL_FOUND_n"]],
    ["mission",   [0.15, [["intel", 3], ["pool", 2]],                                "STR_DUWS_T_INTEL_FOUND_n"]],
    ["objective", [1,    [["intel", 1]],                                             "STR_DUWS_T_INTEL_FOUND_n"]],
    ["civ_frisk", [1,    [["coins", 3], ["document", 1], ["nothing", 4]],            "STR_DUWS_T_INTEL_FOUND_n"]]
];

// manually_chosen
manually_chosen = false;publicVariable "manually_chosen";

// Side Mission wait
Mission_available = true;publicVariable "Mission_available";

// How long a side-mission type sits on cooldown, in mission seconds -- see
// shared/functions/fnc_mission_cooldown_left.sqf for which clock that is and why. Half an hour,
// which is the whole wait between side missions: the slot itself frees the moment a mission ends,
// so this is the only thing pacing them.
// Broadcast because the readout and the strategic map both read it on the client.
mission_cooldown_seconds = 1800;publicVariable "mission_cooldown_seconds";

// Locations for mission placement
MissionLocations = [];publicVariable "MissionLocations";

// moreUrban zones and missions
moreUrban = 1;publicVariable "moreUrban";

// set the default skill range
opfor_ai_skill = [0.55,0.75];publicVariable "opfor_ai_skill";

// declare opfor rifleman variable
opfor_SOLDIER_X = "";

// player_is_choosing_hqpos
player_is_choosing_hqpos = false;publicVariable "player_is_choosing_hqpos";

// PosOfBLUHQ
PosOfBLUHQ = [];publicVariable "PosOfBLUHQ";

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

// Declared here, not just in fnc_WARCOM_init: the area-of-influence read (DUWS_fnc_aoi_covers /
// _bandPos) resolves zone control off this list, and hardpoint generation samples the band a full
// phase before fnc_WARCOM_init runs. Undefined there, every band draw threw and the flank/AA/roadblock
// passes placed nothing. Empty = every zone OPFOR, which is the truth at hour zero; WARCOM_init resets it.
WARCOM_zones_controled_by_BLUFOR = [];

// PATROL TYPES
WARCOM_blu_attack_wave_type = [];

// DEFAULT WEATHER
// choose between "none" - "tropical" - "arid" - "temperate" - "temperate_cold" - "mediterranean"
weather_type = "none";publicVariable "weather_type";

// Zeus visibility
ZeusStatus = 2;publicVariable "ZeusStatus";

// Civilian faction. Defaulted here like every other environment setting: six subsystems
// read it with no isNil guard, so leaving it unset makes each of them error separately and
// civilians never generate, with nothing in the log naming the cause.
// "med" is the only pool that is entirely base-game Altis classes, so it is the one default
// that cannot pull in a mod dependency on the map this mission ships for.
CIV_PRESENCE = "med";publicVariable "CIV_PRESENCE";

// zone_namePOS_pairs
zone_namePOS_pairs = [];publicVariable "zone_namePOS_pairs";
// zone_meta_array: [zone number, position, radius, capture points, fortified, prefab] per zone.
// Keyed by the zone number it carries, not by array position -- the locator spawns fnc_createZone
// per zone, so build-out finishes out of order and registration order is not zone order.
zone_meta_array = [];publicVariable "zone_meta_array";
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

// Hardpoint streaming, per type: [spawnRadius, grace, neverStream, airRing].
//   spawnRadius  distance BLUFOR wake the emplacement at (a fight holds it past this; see the tick)
//   grace        seconds empty before it stows
//   neverStream  built once and kept resident, never stowed. Mortar and artillery hold so OPCOM can
//                task them with no player near; a minefield holds so its mines are never stowed off
//                the map, leaving its own hazard list as the real count of what is armed
//   airRing      a second, larger radius answered only by aircraft; 0 = none. AA reaches out to
//                catch a jet overhead its ground ring would never notice, without waking on
//                every distant foot patrol.
// Server-only: every consumer (the site poller, fnc_hardpoint_register) runs on the server.
DUWS_hardpointStreaming = createHashMapFromArray [
    ["OP",        [1000, 300, false, 0]],
    ["MG",        [ 800, 300, false, 0]],
    ["AT",        [ 800, 300, false, 0]],
    ["ROADBLOCK", [ 800, 300, false, 0]],
    ["MINEFIELD", [ 600, 300, true,  0]],
    ["AA",        [ 800, 300, false, 5000]],
    ["MORTAR",    [ 600, 300, true,  0]],
    ["ARTY",      [ 600, 300, true,  0]],
    // A radio tower streams like a combat hardpoint: its coverage and its amplifier read the registry
    // whether it is up or stowed, but its mast must be deployed for the player to reach and destroy it.
    ["RADIO",     [ 800, 300, false, 0]]
];

// The radio tower's mast: the one composition member left simulated and damageable, and the object
// fnc_hardpoint_stream watches to clear the tower -- destroying it takes the hardpoint, not beating its
// garrison. The rest of the base stays frozen invulnerable cover. Server-only, like every hardpoint
// consumer.
DUWS_radioMastClass = "Land_TTowerBig_2_F";

// How common each hardpoint type is before terrain -- the base weight the siting loop multiplies the
// terrain score by for its weighted roll, and each map's keys ARE its roll set: a type absent from a
// map is never rolled for that pass. Two mixes. A zone's fortification ring is the ground-assault set
// (MG the backbone, GMG the rare supporting weapon). The standalone AoI net that denies the countryside
// also fields AA -- weighted under MG so it does not out-place the guns on the flat ground it favours --
// and leans harder on roadblocks. OPs, minefields and the fire-support types are in neither: they are
// OPCOM's to place, never rolled at init. fnc_hardpoint_lay picks the map by whether the row files under
// a zone (a zoneKey) or stands alone ("").
DUWS_hardpointWeightZone = createHashMapFromArray [
    ["MG", 3], ["AT", 2], ["ROADBLOCK", 2], ["GMG", 1]
];
DUWS_hardpointWeightSolo = createHashMapFromArray [
    ["MG", 3], ["AA", 2], ["ROADBLOCK", 3], ["AT", 1], ["GMG", 1]
];
// The gun-nest set the flank passes draw from -- backline and frontline both field only direct-fire nests,
// so AA and roadblocks (their own passes) stay out of the mix. Same MG-backbone weighting as the zone ring.
DUWS_hardpointWeightNest = createHashMapFromArray [
    ["MG", 3], ["AT", 2], ["GMG", 1]
];

// Readable name per hardpoint type, for the destroyed-hardpoint notification. English labels; the
// localisation carries the sentence around them, not these.
DUWS_hardpointName = createHashMapFromArray [
    ["MG", "MG"], ["AT", "AT"], ["AA", "AA"], ["MORTAR", "Mortar"],
    ["ARTY", "Artillery"], ["OP", "Obs Post"], ["ROADBLOCK", "Roadblock"], ["GMG", "GMG"],
    ["RADIO", "Radio Tower"]
];

// The loose garrison each hardpoint type fields: one DUWS_teamRosters token, or an array of them for a
// type that fields several groups, each resolved per side when crewed -- read by fnc_hardpoint_register
// and the raise worker so every placer fields it the same, the way DUWS_hardpointStreaming drives
// streaming. "" is no loose garrison: a minefield alone gets none, its men would stand on its own mines.
// A radio tower is a strategic objective with 5 km of reach, so it fields a heavier patrol than a lone
// gun -- a rifle team plus two weapons teams (the only AA+AT roster) to contest the air and armour a
// player brings against it. The gun crew is separate and always placed.
DUWS_hardpointGarrison = createHashMapFromArray [
    ["MG", "team"], ["AT", "team"], ["GMG", "team"], ["ROADBLOCK", "team"],
    ["OP", "team"], ["AA", "team"], ["MORTAR", "team"], ["ARTY", "team"],
    ["RADIO", ["team", "wp_team", "wp_team"]], ["MINEFIELD", ""]
];

// The margin beyond a zone's own radius that its streaming reaches: a zone raises and holds its
// garrison for BLUFOR this much further out than the capture trigger tests, so the men are on the
// objective before the players who tripped it arrive. Read by fnc_createZone and fnc_zone_stream_init.
DUWS_streamArrivalMargin = 400;

// The live hardpoint registry, one row per standing emplacement: [key, pos, type, side, zoneKey].
// fnc_hardpoint_register appends and republishes; clearance deletes the row, so a cleared hardpoint
// leaves the array rather than lingering flagged -- its presence here is its liveness, the way a
// destroyed one is gone from the map. Broadcast so the map readout and, later, OPCOM read it without a
// server round-trip -- the hardpoint analogue of zone_meta_array.
DUWS_hardpoints = [];publicVariable "DUWS_hardpoints";

// Area-of-influence reaches, in metres, each measured from the source's OUTER edge rather than its
// centre -- so a naturally large zone claims proportionally more ground than a small one, and every
// source owns a band outside its own footprint. Read only by fnc_aoi_init's coverage tests, all
// server-side, so not broadcast (the pattern DUWS_streamArrivalMargin already sets). The values are
// large against Altis by intent: OPFOR influence blankets most of the map at start and the player
// opens with 2 km around the HQ. Tuning lives here; see docs/info/opfor_area_of_influence.md.
AOI_TOWER_REACH = 5000;   // OPFOR radio tower, the longest reach on the map
AOI_ZONE_REACH  = 2000;   // added to a zone's own radius
AOI_HQ_REACH    = 2000;   // player HQ
AOI_FOB_REACH   = 2000;   // each FOB
AOI_TOWN_REACH  = 2000;   // added to a banded town's civ_radius

// The radio-tower amplifiers, both global scalars rather than per-town. DUWS_opforRadioLevel is the
// count of the enemy's uncleared "RADIO" hardpoints, capped at AOI_OPFOR_TOWER_CAP, recomputed by
// fnc_hardpoint_stream when one is built or cleared; the enemy's drift bottoms out at -(1 + cap) a
// tick in ground it fully holds. DUWS_bluforRadioLevel is the tier the player has bought (0..3),
// raised by fnc_support_perm_grant; with no base push it IS the player's whole drift. Server-only
// readers (the drift), so not broadcast.
AOI_OPFOR_TOWER_CAP = 5;
DUWS_opforRadioLevel = 0;
DUWS_bluforRadioLevel = 0;

// OPCOM's hardpoint director: how often it decides (seconds) and the Army Power each build costs. It
// makes at most one build a pass, in the priority the costs sit in below -- a tower is the dearest and
// the strongest rep lever, a zone top-up the cheapest. Priced so the enemy spends AP it earns from the
// towns it holds rather than fortifying for free, which is the escalation loop: rep won earns AP, AP
// buys fortification, fortification wins more rep. Server-only (OPCOM runs on the server); tuning.
OPCOM_HP_TICK  = 600;
OPCOM_AP_TOWER = 30;
OPCOM_AP_BAND  = 12;
OPCOM_AP_TOPUP = 8;

// zoneundercontrolblu
zoneundercontrolblu = 0;publicVariable "zoneundercontrolblu";

// How close to a base an intact vehicle must be parked to survive the cleanup sweep. Read by both
// the sweep (fnc_repetitive_cleanup.sqf) and the ring drawn around every base
// (fnc_baseRangeMarker.sqf), because a ring that disagreed with the sweep would promise a player
// their vehicle was safe on ground where it is collected. Not broadcast: the markers are made with
// global-effect commands and the sweep is server-only.
DUWS_base_keep_radius = 250;

// Sequence number of the 30-minute campaign economy tick (fnc_zonesundercontrol.sqf).
// Not broadcast: only server-side payout caps read it.
econ_tick = 0;

insurgent_mode_enable = false; publicVariable "insurgent_mode_enable";

// Campaign game mode: "duws", "guerilla" or "zombies". Republished by the faction screen once the
// host picks; declared here so a machine that never ran setup still reads a mode rather than nil.
duws_gamemode = "duws"; publicVariable "duws_gamemode";

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
