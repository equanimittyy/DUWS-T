// The config menu overwrites many of these from player input; treat the values here as defaults.

VERSION_X = "MODERN";publicVariable "VERSION_X";
setGroupIconsVisible [(["DUWS_GroupIcons", 0] call BIS_fnc_getParamValue) == 1, false];
OPFOR_Faction_X = "OPF_F";
BLUFOR_Faction_X = "BLU_F";
switch (VERSION_X) do {
	
	case "MODERN": {
		BLUFOR_Faction_X = "BLU_F";publicVariable "BLUFOR_Faction_X";
		OPFOR_Faction_X = "OPF_F";publicVariable "OPFOR_Faction_X";
	};
	
};

// The faction dropdown's answer -- a faction-file token, or "CUSTOM"/"AUTODETECT". Kept apart from
// *_Faction_X, which faction init overwrites with the class random vehicle patrols read; resolution
// reruns every time setup steps back through. Defaults match the rows the two combos open on.
BLUFOR_FactionFile_X = "BLU_F_ARID";publicVariable "BLUFOR_FactionFile_X";
OPFOR_FactionFile_X = "OPF_F_ARID";publicVariable "OPFOR_FactionFile_X";

BLUfactionDataTemp = "";publicVariable "BLUfactionDataTemp";
OPFfactionDataTemp = "";publicVariable "OPFfactionDataTemp";
BLUfactionData = [];
OPFfactionData = [];

Factions_Available_OPFOR_X = [];publicVariable "Factions_Available_OPFOR_X";
Factions_Available_BLUFOR_X = [];publicVariable "Factions_Available_BLUFOR_X";

amount_zones_created = 0;publicVariable "amount_zones_created";

// Zones whose build-out finished, as opposed to amount_zones_created, which fnc_createZone
// bumps on entry. Civilian generation needs "built", not "started": it counts buildings,
// and prefab zones hide everything within 35 m of their centre partway through build-out.
zones_buildout_done = 0;publicVariable "zones_buildout_done";

amount_zones_captured = 0;publicVariable "amount_zones_captured";

AO_direction = [];

// The three arrays are index-parallel: entry i of each describes one FOB. Every writer must
// append to all three and every remover must delete the same index from all three, or a FOB's
// name and position separate from its building.
Array_of_FOBS = [];publicVariable "Array_of_FOBS";
Array_of_FOBname = [];publicVariable "Array_of_FOBname";
Array_of_FOBpos = [];publicVariable "Array_of_FOBpos";

// Opfor gets Air
AttackHeli = 1;publicVariable "AttackHeli";

blufor_ai_skill = [0.85,1.0];publicVariable "blufor_ai_skill";

chosen_hq_placement = false;publicVariable "chosen_hq_placement";

chosen_settings = false;publicVariable "chosen_settings";

// Captured-materiel pool: foreign (non-friendly) gear the player has banked, as an array of
// [classname, count] pairs. Server-authoritative -- only the fnc_captured_pool_* writers assign it,
// and each re-broadcasts after a change; clients read it as a view to stock the arsenal shelf.
DUWS_capturedPool = [];publicVariable "DUWS_capturedPool";

// The lobby params that are campaign rules, each resolved once into the global every reader takes, so a loaded
// campaign's own rules can replace the lobby's (server/persistence/fnc_campaign_restore.sqf).
DUWS_paramFatigue = ["DUWS_Fatigue", 1] call BIS_fnc_getParamValue;publicVariable "DUWS_paramFatigue";
DUWS_paramFirstPerson = ["DUWS_RestrictFirstPerson", 0] call BIS_fnc_getParamValue;publicVariable "DUWS_paramFirstPerson";
DUWS_paramArsenal = ["DUWS_ArsenalMode", 0] call BIS_fnc_getParamValue;publicVariable "DUWS_paramArsenal";
DUWS_paramTrackAmmo = ["DUWS_TrackAmmo", 0] call BIS_fnc_getParamValue;publicVariable "DUWS_paramTrackAmmo";
DUWS_paramRestWeather = ["DUWS_RestWeather", 1] call BIS_fnc_getParamValue;publicVariable "DUWS_paramRestWeather";
DUWS_paramLoseConditions = ["DUWS_LoseConditions", 0] call BIS_fnc_getParamValue;publicVariable "DUWS_paramLoseConditions";

// Arsenal mode and ammo tracking, so the server-side pool writers and the client shelf logic read one
// authoritative answer. Limited count-tracks the player's own faction too (no unlimited floor); trackAmmo
// folds magazines into whatever the mode tracks.
DUWS_arsenalLimited = DUWS_paramArsenal == 2;publicVariable "DUWS_arsenalLimited";
DUWS_trackAmmo = DUWS_paramTrackAmmo == 1;publicVariable "DUWS_trackAmmo";

// Limited's starting armoury: every standard-issue class is seeded into the pool at this count at
// boot, since Limited removes the unlimited friendly floor. Tunable; a playtest value.
DUWS_limitedSeed = 100;
// The classes a loaded campaign already seeded, so a count it spent to nothing is not stocked again.
DUWS_limitedSeeded = [];

// The faction confirmation screen's handshake. Request and ready are counters, not flags: a flag
// cleared by the server can race a fresh request, so the screen waits for ready to reach the number
// it asked with, never reading the previous pick's rows.
// duws_faction_locked carries the whole confirmed table -- [[side, [[key, value, record], ...]], ...] -- rather
// than a diff, so the server has one code path to apply, not a reconciliation to work out.
duws_faction_preview_request = 0;publicVariable "duws_faction_preview_request";
duws_faction_preview_ready = 0;publicVariable "duws_faction_preview_ready";
duws_faction_locked = [];publicVariable "duws_faction_locked";

// Player squad callsign, set on the callsign setup screen and substituted into
// English radio dialogue by fnc_cs. Default matches the "Alpha 1-1" literal baked
// into the stringtable, so an unchanged callsign leaves every line untouched.
duws_callsign = "Alpha 1-1";publicVariable "duws_callsign";


cp_reward_multiplier = 1;publicVariable "cp_reward_multiplier";

// Kill income: each economy tick, a player's tally converts at kill_cp_award CP per kill_cp_kills
// kills, debiting the paid-for kills and carrying the remainder forward. No period here -- it rides
// the economy tick's own clock. Server-only: tally, sweep and payout all live on the server.
kill_cp_kills = 10;
kill_cp_award = 1;

// Distance at which a FOB or HQ garrison stops being simulated -- nothing culled it before, so every
// base ran pathing and targeting for the whole campaign regardless of distance. Server-only.
// A base is frozen rather than torn down and rebuilt, so freezing early only costs a returning player
// a frame of garrison catching up -- unlike the zone streamer, which pays two minutes to avoid rebuild churn.
base_garrison_sleep_range = 500;

// Streaming presence per site profile: [buffer, grace, latch, aiAware, minAI].
//   buffer   metres added to the site radius to make the ring presence is tested over
//   grace    seconds the empty ring waits before the site streams out (for a base, re-freezes)
//   latch    start latched, so a site registered under a player does not raise its garrison around them
//   aiAware  gate on the AI-aware BLUFOR test (zones, town garrisons) rather than a plain player list
//   minAI    how many BLUFOR hold the ring to keep an aiAware site up
// town_crowd and town_gar split one town into two answers (noticed at 200 m/60 s vs held at 400 m/120 s).
// A base is 0/short because it freezes in place rather than streaming off the map. Read by
// fnc_site_occupant_register_profile and, for the town's own tick, by fnc_civ_garrison.
DUWS_streamProfiles = createHashMapFromArray [
    ["zone",       [400, 120, true,  true,  2]],
    ["town_crowd", [200,  60, false, false, 2]],
    ["town_gar",   [400, 120, true,  true,  2]],
    ["base",       [  0,  10, false, false, 2]]
];

// Seconds a capture's conditions must hold unbroken before the ground changes hands. One number for
// DUWS_fnc_siteTaken and OPCOM's virtual retake, so the rule a player learns is the same everywhere.
DUWS_captureHold = 20;

// support_max_slots caps one-use items carried at once; support_death_refund is the share (both
// currencies) refunded on death holding unused ones -- half, so walking an item back still beats
// dying with it. Both read on clients, so both broadcast.
support_max_slots = 8;      publicVariable "support_max_slots";
support_death_refund = 0.5; publicVariable "support_death_refund";

// How long a destroyed Mobile HQ locks designation out for. Losing it has to cost something, or
// leaving it parked at the objective and letting it burn is cheaper than driving it home -- the
// respawn point comes back within a minute either way. Read on clients, so it is broadcast.
MHQ_lockout_seconds = 1800; publicVariable "MHQ_lockout_seconds";

// How long a High Command aircraft (attack heli, CAS jet) holds station before it flies home and
// despawns. Without a leash a one-time air support that is never shot down loiters for the rest of the
// mission, making a consumable permanent. One figure for both airframes; read on the buyer's client.
HC_air_station_seconds = 300; publicVariable "HC_air_station_seconds";

// Which permanent supports the team has bought, in purchase order. Their broadcast flags stay
// every client's fast path; this holds the same set as data a campaign save can walk, instead of
// as a scatter of named globals a restore would have to know one at a time.
DUWS_support_permanent = []; publicVariable "DUWS_support_permanent";

// DUWS_garage_stored is an array of serializable specs -- no object handle ever enters it, so engine
// saveGame carries it with no extra machinery. The four expansion levels are permanent supports
// (support_garage1..4_available), left unset here like every other support flag and set true by purchase;
// the highest owned expansion, or the base default, sets the caps.
DUWS_garage_stored = []; publicVariable "DUWS_garage_stored";

// Zone payouts. Capture is an event reward; holding is an AP trickle on the economy tick
// (zone_ap_trickle, below).
// First BLUFOR capture pays a flat liberation bonus once ever per zone (DUWS_zone_first_captured),
// so a lost-and-retaken zone is not a farm; recapture pays BLUFOR nothing further. No CP bounty or
// decay -- both retired with the town->CP reroute, where passive CP now lives.
// AP swings are shares of the zone's worth, so a contested zone swings the same momentum however
// often it flips. OPFOR is paid a consolation on every BLUFOR capture (anti-steamroll) and the full
// swing on retaking one; BLUFOR sheds it on losing one. Server-only.
zone_first_capture_cp = 25;
zone_first_capture_ap = 50;  // the main lever balancing OPFOR's hour-zero zones
zone_ap_swing = 0.15;
zone_ap_consolation = 0.15;

// The strategic dividend: AP per held zone, per economy tick, each side, scaled by
// DUWS_econ_throttle. Passive per tick yet earned per zone -- it pays only for ground taken
// and held and stops when a zone is lost, so standing still earns nothing new.
zone_ap_trickle = 5;

// First-captured zone keys, one entry per zone BLUFOR has ever taken. The liberation bonus
// reads this so it never pays twice -- a reload or a retaken zone finds its key already here.
// Save state: it lives in the mission namespace so a campaign save carries it.
DUWS_zone_first_captured = [];

// [object, seconds] entries awaiting pickup by the map cleanup, written through
// fnc_duws_disposeAfter and drained every pass; nil seconds means the default lifetime. Server-only:
// the sweep runs here and clients reach it by remoteExec.
DUWS_disposables = [];

// composition key -> the objects it owns, written through fnc_duws_keep. Every member is tagged
// persistent so no sweep touches it, and the key lets fnc_duws_release bin it all at once -- needed
// because a wrecked hardpoint's sandbags and camo net are undamaged props no object-state test would ever collect.
DUWS_compositions = createHashMap;

// composition key -> the records needed to rebuild it, written through fnc_duws_stow. Holds a key
// exactly while that composition's streamable members are off the map, so presence here answers
// "is this stowed" without touching an object. Not exclusive with DUWS_compositions -- pinned members
// (e.g. a hardpoint's gun) stay behind, so a key can appear in both. Records are built when stowed, not
// when built, so damage and moved props are captured as they actually are. Transient: a campaign restore replays the builders instead.
DUWS_stowed = createHashMap;

// Keys retired through fnc_duws_release, read by the stow/deploy gate to stop looping. Explicit
// rather than inferred from the key's absence elsewhere, which is equally true before build-out runs.
// Cleared by fnc_duws_keep so a key reused at the same rounded coordinates is not born retired.
DUWS_retired = [];

// One-shot request for the map cleanup to sweep now, treating every lifetime as already elapsed.
// Set through fnc_duws_forceCleanup and cleared by the pass it wakes. It skips the wait for the
// lifetime, but not KEEP_RADIUS and not the persistent flag.
DUWS_cleanup_force = false;

// UID -> the last vehicle that player rode, which the map cleanup spares as in use. Several players may
// hold one vehicle, so a mid-session drop by one leaves it spared for the rest. Written by
// fnc_duws_claimRide and pruned by the sweep's PlayerDisconnected handler (fnc_repetitive_cleanup.sqf).
DUWS_playerRides = createHashMap;

// Live civilian side missions, id -> entry; fnc_civ_mission_request adds, fnc_civ_mission_finish deletes.
// Server-only, and never saved: a restore drops live missions, and the entries hold unit handles.
DUWS_civMissions = createHashMap;
DUWS_civMissionSeq = 0;

DUWSMP_CP_death_cost = 2;publicVariable "DUWSMP_CP_death_cost";

dynamic_weather_enable = true;publicVariable "dynamic_weather_enable";	

commandpointsblu1 = 50;publicVariable "commandpointsblu1";

// Zones built out and civilians registered, successfully or not. Everything the player sees
// as "the campaign has started" -- the completion banner, the intro helicopter, the map
// closing -- waits on this, so generation never runs on under a player already in the field.
mission_init_complete = false;publicVariable "mission_init_complete";

createzone_server = false;publicVariable "createzone_server";

enable_fast_travel = true;publicVariable "enable_fast_travel";

enemyunitMultiplier = 1;publicVariable "enemyunitMultiplier";

failsafe_zones_not_found1 = false;//publicVariable "failsafe_zones_not_found1";
failsafe_zones_not_found2 = false;//publicVariable "failsafe_zones_not_found2";

// FOB_removed keeps fnc_fob_destroyed from running
FOB_removed = false;//publicVariable "FOB_removed";

hardcore_mode_enable = false;publicVariable "hardcore_mode_enable";

// Opfor gets tanks
HeavyArmor = 1;publicVariable "HeavyArmor";

hq_manually_placed = false;publicVariable "hq_manually_placed";

HQ_pos_found_generated = false;publicVariable "HQ_pos_found_generated";

MASTER_allLocations_filtered = [];//publicVariable "MASTER_allLocations_filtered";
MASTER_allLocationsPos = [];publicVariable "MASTER_allLocationsPos";

// [successChance, [[payoutKind, weight], ...], nothingKey] per search source.
// combat rolls at the search, not spawn (any corpse is searchable). Its gate is per-search, and
// DUWS_searchAllowance searches are allowed per DUWS_searchCooldown window: gate * allowance is the
// expected payouts per window (0.60 * 3 = 1.80), so raising the allowance without dropping the gate
// multiplies intel volume. objective/civ_frisk are flagged at spawn with chance 1 (never miss,
// single-use) and read this table only for kinds.
// Weights, not a cumulative ladder: adding a kind is one row instead of re-deriving every band below it.
// Kinds draw without replacement; an exhausted kind drops out and the remainder re-draw, so a dry pool
// never turns a search into silence.
DUWS_searchSources = createHashMapFromArray [
    ["combat",    [0.60, [["intel", 1], ["money", 7], ["document", 4]],            "STR_DUWS_T_INTEL_FOUND_n"]],
    ["objective", [1,    [["intel", 1]],                                             "STR_DUWS_T_INTEL_FOUND_n"]],
    ["civ_frisk", [1,    [["money", 3], ["document", 1], ["nothing", 4]],            "STR_DUWS_T_INTEL_FOUND_n"]]
];

// The physical items a "document" find drops, and a patrol camp's table may hold. Only base-game Item_
// ground holders belong here (each has an Item_ ground variant, so a dropped copy survives rather than
// vanishing). FilesSecret is off the roll -- only the raid crate grants one, so a 100%-reveal document
// never falls out of a random search or patrol-camp draw. Labels are the mission's own since these holders
// carry generic/empty displayNames. Shared by the search payout and the camp draw so the lists cannot drift.
DUWS_intelDocuments = ["Item_MobilePhone", "Item_Wallet_ID", "Item_SmartPhone",
    "Item_FlashDisk", "Item_Files"];
DUWS_intelDocumentWeights = [32, 32, 22, 10, 4];
DUWS_intelDocumentLabels = ["STR_DUWS_T_INTEL_ITEM_phone", "STR_DUWS_T_INTEL_ITEM_wallet",
    "STR_DUWS_T_INTEL_ITEM_smartphone", "STR_DUWS_T_INTEL_ITEM_flashdrive",
    "STR_DUWS_T_INTEL_ITEM_files"];

// A rolling window: up to DUWS_searchAllowance combat-corpse searches per DUWS_searchCooldown seconds,
// session-wide -- one shared budget for the whole team, not per player. This budget, not troop density,
// is what bounds intel volume, since any corpse is searchable and the success roll is spent at the
// search. Deliberately tight. Objective/civ_frisk searches are single-use and bypass it. The tally
// (DUWS_searchTimes) lives in missionNamespace and is broadcast: the prompt's condition runs on the client.
DUWS_searchCooldown = 900;   publicVariable "DUWS_searchCooldown";
DUWS_searchAllowance = 3;    publicVariable "DUWS_searchAllowance";

manually_chosen = false;publicVariable "manually_chosen";

Mission_available = true;publicVariable "Mission_available";

// The side-mission gate: a new mission may start only once this many in-game hours have passed since
// the last one started (see fnc_mission_gate_left.sqf). The slot itself frees the moment one ends, so
// this alone paces missions; a rest at HQ skips three hours and so clears it in one go.
// Broadcast: the readout and the strategic map both read it on the client.
mission_gate_hours = 3;publicVariable "mission_gate_hours";

// The last mission's start, stamped as a campaign-date number (dateToNumber date). Zero until the
// first mission, which reads as long past and so opens the gate.
DUWS_lastMissionStartDate = 0;publicVariable "DUWS_lastMissionStartDate";

// Seconds of in-game time a rest has skipped past engine `time`. The campaign clock (fnc_campaign_now)
// adds it so a rest expires live mission deadlines; bumped by skiptime in fnc_rest_heal.
DUWS_timeSkew = 0;publicVariable "DUWS_timeSkew";

// A loaded campaign's officer came back dead: his watcher must not announce it or judge the lose condition again.
DUWS_officerLost = false;

MissionLocations = [];publicVariable "MissionLocations";

moreUrban = 1;publicVariable "moreUrban";

// Share of a zone's mobile garrison fielded at once (1 = all). Below 1, the remainder seeds the
// reserve pool so even a x1 zone reinforces. Default here covers the pre-commit window and a campaign
// that predates the setting; the campaign screen overwrites it (fnc_process_campaign_menu).
garrison_density = 0.5;publicVariable "garrison_density";

opfor_ai_skill = [0.55,0.75];publicVariable "opfor_ai_skill";

opfor_SOLDIER_X = "";

player_is_choosing_hqpos = false;publicVariable "player_is_choosing_hqpos";

PosOfBLUHQ = [];publicVariable "PosOfBLUHQ";

serv_zones_array = [];publicVariable "serv_zones_array";

simple_zones_enable = false;publicVariable "simple_zones_enable";

apocalypse_mode = false; publicVariable "apocalypse_mode";

WARCOM_blufor_ap = 0;publicVariable "WARCOM_blufor_ap";
WARCOM_opfor_ap = 0;publicVariable "WARCOM_opfor_ap";
// Ladder input and its tier, per side. The earned counter only ever rises (credited by faucets, never
// spending), so the tier it derives is a one-way ratchet a spent-down wallet cannot lower. These are
// pre-preset defaults -- fnc_WARCOM_init reseeds them. Not yet carried by the campaign save: a reload
// re-derives the tier from a wallet since spent down (docs/plans/campaign_persistence_plan.md).
WARCOM_blufor_ap_earned = 0;publicVariable "WARCOM_blufor_ap_earned";
WARCOM_opfor_ap_earned = 0;publicVariable "WARCOM_opfor_ap_earned";
WARCOM_blufor_tier = 0;publicVariable "WARCOM_blufor_tier";
WARCOM_opfor_tier = 0;publicVariable "WARCOM_opfor_tier";
WARCOM_init_done = false;publicVariable "WARCOM_init_done";

// Declared here, not in fnc_WARCOM_init: the area-of-influence read (DUWS_fnc_aoi_covers /
// _bandPos) resolves zone control off this list, and hardpoint generation samples the band a full
// phase before fnc_WARCOM_init runs. Undefined there, every band draw threw and the flank/AA/roadblock
// passes placed nothing. Empty = every zone OPFOR, which is the truth at hour zero; a loaded campaign's
// restore fills it before the site poller starts (server/persistence/fnc_campaign_restore.sqf).
WARCOM_zones_controled_by_BLUFOR = [];

// choose between "none" - "tropical" - "arid" - "temperate" - "temperate_cold" - "mediterranean"
weather_type = "none";publicVariable "weather_type";

ZeusStatus = 2;publicVariable "ZeusStatus";

// Civilian faction. Defaulted here like every other environment setting: six subsystems read it with no
// isNil guard, so an unset value makes each fail separately with nothing in the log naming the cause.
// "med" is the only pool entirely base-game Altis classes, so it's the default that pulls in no mod dependency.
CIV_PRESENCE = "med";publicVariable "CIV_PRESENCE";

zone_namePOS_pairs = [];publicVariable "zone_namePOS_pairs";
// zone_meta_array: [zone number, position, radius, capture points, fortified, prefab] per zone.
// Keyed by the zone number it carries, not by array position -- the locator spawns fnc_createZone
// per zone, so build-out finishes out of order and registration order is not zone order.
zone_meta_array = [];publicVariable "zone_meta_array";
zones_created = false;publicVariable "zones_created";
zones_manually_placed = false;publicVariable "zones_manually_placed";
zones_max_dist_from_hq = 0;publicVariable "zones_max_dist_from_hq";
// Number of capturables zones to create (when zones are created randomly)
zones_number = 6; 
zones_spacing = 500; 
zones_max_radius = 1000;publicVariable "zones_max_radius"; 
// Must not go under 200.
zones_min_radius = 200;publicVariable "zones_min_radius";

// Hardpoint streaming, per type: [spawnRadius, grace, neverStream, airRing].
//   spawnRadius  distance BLUFOR wake the emplacement at. 800 for direct-fire nests that must open up
//                before the player closes; 600 for the rest (an OP screens past this ring anyway, and
//                a mast/battery is destroyed up close, so neither needs gun-range wake-up)
//   grace        seconds empty before it stows
//   neverStream  built once, kept resident, never stowed -- mortar/artillery so OPCOM can task them with
//                no player near, a minefield because a mine must be made with createMine and the
//                composition's own deploy rebuilds members with createVehicle, which would hand back
//                inert props. A minefield streams per square on its own path instead
//                (fnc_hardpoint_minefield_cycle). Only the composition is pinned; the loose garrison
//                still streams, but the gun crew stays live (a frozen crew cannot fire)
//   airRing      a second, larger radius answered only by aircraft; 0 = none. Lets AA catch a jet its
//                ground ring would never notice, without waking on every distant foot patrol.
// Server-only: every consumer (the site poller, fnc_hardpoint_register) runs on the server.
DUWS_hardpointStreaming = createHashMapFromArray [
    ["OP",        [ 600, 300, false, 0]],
    ["MG",        [ 800, 300, false, 0]],
    ["AT",        [ 800, 300, false, 0]],
    ["GMG",       [ 800, 300, false, 0]],
    ["ROADBLOCK", [ 800, 300, false, 0]],
    ["MINEFIELD", [ 600, 300, true,  0]],
    ["AA",        [ 800, 300, false, 5000]],
    ["MORTAR",    [ 600, 300, true,  0]],
    ["ARTY",      [ 600, 300, true,  0]],
    // A radio tower's coverage and amplifier read the registry whether it is up or stowed, so the ring
    // only governs when its mast and garrison stream in -- and the mast is destroyed up close, not at range.
    ["RADIO",     [ 600, 300, false, 0]]
];

// Zone air streaming: a player-crewed aircraft or UAV committing to a zone wakes its garrison, since the
// ground ring discounts anything airborne (fnc_duws_bluforNear). Committing, not transiting, and
// player-crewed, not AI: only a player-flown heli or a UAV under DUWS_zoneAirCommitSpeed counts, so a
// cruising jet or an AI aircraft raises nothing. This is the zone's own reach -- AA keeps its own ungated
// air ring above. Ring 0 falls back to ground only. Server-only: all consumers run on the server.
DUWS_zoneAirRing = 1500;
DUWS_zoneAirCommitSpeed = 250;   // km/h

// A held zone's flag factory allowance in R3F credits, by garrison tier 0-IV (fnc_zone_build.sqf).
DUWS_zoneBuildPoints = [0, 250, 500, 1000, 2000];
// The HQ's and each FOB's, by Fortification level 0-IV (DUWS_fortLevel).
DUWS_baseBuildPoints = [0, 250, 500, 1000, 2000];

// The radio tower's mast: the one composition member left simulated and damageable, and the object
// fnc_hardpoint_stream watches to clear the tower -- destroying it takes the hardpoint, not beating its
// garrison. The rest of the base stays frozen invulnerable cover.
DUWS_radioMastClass = "Land_TTowerBig_2_F";

// How common each hardpoint type is before terrain -- the siting loop's base weight, multiplied by
// terrain score; a map's keys ARE its roll set, so an absent type is never rolled. Two mixes: the zone
// ring is the ground-assault set (MG backbone, GMG rare); the standalone AoI net also fields AA (weighted
// under MG so it doesn't out-place guns on AA-favoured flat ground) and leans harder on roadblocks.
// Minefields and fire-support types are in neither -- OPCOM's to place. OPs are rolled by a separate
// dedicated band pass instead. fnc_hardpoint_lay picks the map by whether the row files under a zone or stands alone ("").
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
// The OPFOR tier each type unlocks at for OPCOM's builds only; campaign generation still rolls every type.
DUWS_hardpointTier = createHashMapFromArray [
    ["RADIO", 1], ["OP", 1], ["MG", 1], ["ROADBLOCK", 1], ["AT", 2], ["MINEFIELD", 2], ["GMG", 3], ["AA", 3],
    ["MORTAR", 3], ["ARTY", 4]
];

// Readable name per hardpoint type, for the reveal line and the destroyed-hardpoint notification.
// English labels; the localisation carries the sentence around them, not these.
DUWS_hardpointName = createHashMapFromArray [
    ["MG", "MG"], ["AT", "AT"], ["AA", "AA"], ["MORTAR", "Mortar"],
    ["ARTY", "Artillery"], ["OP", "Obs Post"], ["ROADBLOCK", "Roadblock"], ["GMG", "GMG"],
    ["RADIO", "Radio Tower"], ["MINEFIELD", "Minefield"]
];

// Bounty for destroying a hardpoint, [CP, AP], read by fnc_hardpoint_stream when cleared.
// Unlisted types pay the base 5 CP, no AP -- only the strategic ones pay above the floor: the batteries
// OPCOM fires from (ARTY, MORTAR) and the radio tower, whose 5 km reach makes it the biggest single loss.
// AP paid here is earned (raises the BLUFOR tier), not a spend.
DUWS_hardpointBounty = createHashMapFromArray [
    ["RADIO", [10, 10]], ["ARTY", [10, 5]], ["MORTAR", [10, 0]]
];

// The loose garrison each hardpoint type fields: a DUWS_teamRosters token, or an array of them,
// resolved per side when crewed. "" is no loose garrison (a minefield's men would stand on its own mines).
// AT/AA field the weapons team matching the emplaced gun's role rather than a generic rifle section.
// RADIO/ARTY/MORTAR scale their garrison to strategic value; one element always screens wide (widepatrol)
// while the rest hold close. Gun crews for ARTY/MORTAR/RADIO are separate and stay resident.
DUWS_hardpointGarrison = createHashMapFromArray [
    ["MG", "closepatrol:team"], ["AT", "closepatrol:wp_team"], ["GMG", "closepatrol:team"], ["ROADBLOCK", "closepatrol:team"],
    ["OP", ["closepatrol:team", "widepatrol:recon"]], ["AA", "closepatrol:wp_team"], ["MORTAR", ["closepatrol:wp_team", "widepatrol:patrol"]], ["ARTY", ["closepatrol:wp_team", "closepatrol:wp_team", "widepatrol:team"]],
    ["RADIO", ["closepatrol:wp_team", "widepatrol:wp_team", "widepatrol:team"]], ["MINEFIELD", ""]
];

// Per-posture spawn band and circuit radius, each a fraction of the spawn radius the caller passes.
// [minFrac, maxFrac, patrolFrac]: a group spawns between minFrac/maxFrac of that radius from centre and
// circuits at patrolFrac. Read by fnc_spawn_team/fnc_spawn_vehicle for placement and fnc_apply_posture
// for waypoint reach -- one table so the two cannot disagree. A posture absent here (hqpatrol, none)
// keeps the old uniform band; garrison claims structures within its own fixed reach, so patrolFrac
// applies only on its fallback patrol.
DUWS_postureBands = createHashMapFromArray [
    ["closepatrol", [0.1, 0.5, 0.4]],
    ["widepatrol",  [0.5, 1.0, 0.9]],
    ["garrison",    [0.1, 0.5, 0.4]]
];

// The margin beyond a zone's own radius that its streaming reaches: a zone raises and holds its
// garrison for BLUFOR this much further out than the capture trigger tests, so the men are on the
// objective before the players who tripped it arrive. Read by fnc_createZone and fnc_zone_stream_init.
DUWS_streamArrivalMargin = 400;

// Zone reserve / reinforcement tuning. The enemy multiplier is reserve depth: a zone fields at most its
// x1 tier composition on the ground, and the surplus (mult-1) waits as a pool refilling the garrison to
// that x1 count as casualties are taken. Server-side only, not broadcast. Read by fnc_zone_reserve and
// fnc_zone_spawn_sizes; model in docs/info/gameplay/garrison_and_reserves.md.
// The global OPFOR-side group throttle: past this live east group count, zone garrison spawns and
// refills pause and their tokens stay pooled. Set below the engine's 144-groups-per-side hard cap
// (past which createGroup returns grpNull silently), with slack as a co-op backstop the per-zone ceilings alone would not catch.
DUWS_zoneGroupCeiling = 130;

// The event trigger fraction. A zone whose live groups fall below this fraction of its x1 ceiling
// pulls an immediate refill wave rather than waiting for the poll, so reinforcement reads as waves
// rather than one-in-one-out.
DUWS_zoneReinforceFrac = 0.5;

// The floor distance a reinforcement spawns from the nearest player, in metres. Flat, not
// zone-relative, so it reads the same at a 50 m base and a 1300 m island -- a radius-relative distance
// would drop reserves a kilometre out of the island and on top of the player in the base.
DUWS_zoneReserveSpawnDist = 400;

// How far to look for a road around a chosen far-side spawn point, in metres -- a reserve wave rides
// trucks, so it must stand up on drivable ground. Wide enough to find a road off most approaches, tight
// enough to stay near the anti-flank bearing. No road in range leaves the off-road point.
DUWS_zoneReserveRoadSearch = 150;

// Spacing between vehicles in a reserve wave, in metres. The wave stages as a convoy line rather than
// all standing up on one point -- two vehicles sharing a point brew up on spawn. Also the minimum gap a
// road-snapped slot must clear from an already-placed one before it steps further out. Comfortably wider
// than the longest vehicle so a truck and a tank nose-to-tail never clip.
DUWS_reserveConvoyGap = 35;

// The heartbeat period of the refill loop, in seconds. Tops zones back up during a steady grind; the
// event path above covers deep dips between beats.
DUWS_zoneReservePollPeriod = 300;

// Debounce for the event path, in seconds: a mass-casualty moment triggers one wave, not fifty.
DUWS_zoneReserveEventDebounce = 20;

// Where the empty truck runs to once its load is down: this far beyond the zone radius on the far side,
// so the driver drives it off the debus point instead of idling in the fight while it waits to be reaped.
// Read by fnc_garrison_reserve's dispatch monitor.
DUWS_reserveEscapeDist = 900;

// Where a truck-borne wave debusses: this far beyond the zone radius, on the far side toward the
// objective, so it dismounts short of the fight and closes on foot rather than driving a soft truck
// onto the guns. Read by fnc_garrison_reserve.
DUWS_reserveDebusOffset = 200;

// How near the debus point the truck must reach, in metres, to count as arrived and unload.
DUWS_reserveDebusRadius = 40;

// The truck damage above which the wave bails early. Paired with setUnloadInCombat [false,false], which
// suppresses the engine's own combat dismount so the squad holds under fire to the debus point -- but a
// transport this far gone is about to brew up with everyone still inside, so this overrides the hold.
DUWS_reserveDebusDamageBail = 0.6;

// The hard ride ceiling, in seconds. A mobility kill is caught by canMove, but a truck that still moves
// yet is wedged or circling an unreachable debus point would carry the squad forever; this dumps them
// out to finish on foot. Generous, so a normal few-hundred-metre ride never trips it.
DUWS_reserveMaxRide = 150;

// The live hardpoint registry, one row per standing emplacement: [key, pos, type, side, zoneKey].
// fnc_hardpoint_register appends and republishes; clearance deletes the row, so a cleared hardpoint
// leaves the array rather than lingering flagged -- its presence here is its liveness, the way a
// destroyed one is gone from the map. Broadcast so the map readout and, later, OPCOM read it without a
// server round-trip -- the hardpoint analogue of zone_meta_array.
DUWS_hardpoints = [];publicVariable "DUWS_hardpoints";

// Area-of-influence reaches, in metres, each measured from the source's OUTER edge rather than its
// centre, so a large zone claims proportionally more ground than a small one. Server-only (fnc_aoi_init's
// coverage tests), not broadcast. Large against Altis by intent: OPFOR blankets most of the map at start
// and the player opens with 2 km around the HQ. See docs/info/gameplay/opfor_area_of_influence.md.
AOI_TOWER_REACH = 5000;   // OPFOR's radio tower
AOI_ZONE_REACH  = 2000;   // added to a zone's own radius
AOI_HQ_REACH    = 2000;
AOI_FOB_REACH   = 2000;
AOI_TOWN_REACH  = 2000;   // added to a banded town's civ_radius

// A civilian is caught on sight inside an OPFOR zone's radius or this near an OPFOR hardpoint. The band
// this wide beyond either ring warns once on the way in and fills the meter faster.
// Server-only, like every DISGUISE_* value, so none is broadcast.
DISGUISE_CIV_HP_RING = 50;
DISGUISE_CIV_SITE_WARN = 100;
// An OPFOR unit spots a disguised player within this range and cone (degrees off its eye direction),
// at this checkVisibility or more.
DISGUISE_SPOT_RANGE = 200;
DISGUISE_SPOT_CONE = 60;
DISGUISE_SPOT_VIS = 0.5;
// Seconds after a shot in which a unit that spots the shooter still breaks cover, so the victims'
// squad turning round catches a shot fired unseen.
DISGUISE_FIRE_WINDOW = 5;
DISGUISE_CIV_RATE_BAND = 6;
DISGUISE_CIV_RATE_OPEN = 1;
DISGUISE_ENEMY_RATE = 0.5;
DISGUISE_BODY_MULT = 4;
DISGUISE_CROUCH_MULT = 1.1;
DISGUISE_PRONE_MULT = 1.3;
// Unseen suspicion falls at this share of its rate while a living OPFOR unit is this near, so ducking
// out of sight beside a patrol does not clear it as fast as walking away.
DISGUISE_DECAY_NEAR_RANGE = 50;
DISGUISE_DECAY_NEAR_SCALE = 1/3;

// The radio-tower amplifiers, global scalars rather than per-town. DUWS_opforRadioLevel is the count of
// uncleared enemy "RADIO" hardpoints, capped at AOI_OPFOR_TOWER_CAP, recomputed by fnc_hardpoint_stream
// on build/clear. DUWS_bluforRadioLevel is the tier bought (0..3), raised by fnc_support_perm_grant, and
// with no base push it IS the player's whole drift. Server-only reader (the drift), not broadcast.
AOI_OPFOR_TOWER_CAP = 5;
DUWS_opforRadioLevel = 0;
DUWS_bluforRadioLevel = 0;

// OPCOM perception. Plain globals not #define -- the opcom files that read them load by compile-path and
// run later, out of reach of a macro scoped to this file. Influence-grid geometry in metres:
OPCOM_GRID_CELL   = 500;
OPCOM_GRID_SPREAD = 1000;

// An OP's reach in Chebyshev grid cells (k=2 ~ 1000 m on axis), kept wider than the garrison stream so a player
// cannot sit just outside it unseen.
OP_OBSERVE_K = 2;

OPCOM_HQ_REVEAL_K = 2;

// The grid is built, rebuilt, routed and drawn only inside a box around the play area (every zone, town and
// the HQ grown by its radius plus this buffer) -- OPCOM never calculates the empty rest of the map. Counted
// in cells, not metres, so it holds if the cell size changes. Must exceed the largest deposit reach in cells
// (max zone radius + OPCOM_GRID_SPREAD, ~4 cells) so a source's falloff never reaches the box edge, which
// lets the rebuild clamp its deposits to the box safely.
OPCOM_GRID_BOX_BUFFER_CELLS = 10;

// The single loop cadence in seconds: one tick senses, ages belief, rebuilds the grid, scores and commits
// one action, and steps tasking movement. Kept fast on purpose -- a finer tick reads as more reactive,
// and movement/economy scale with it rather than breaking.
// Canonical time unit for OPCOM: every duration below is in ticks; this is the sole value in seconds. A
// real sleep multiplies its tick count by this, so changing it rescales every span.
OPCOM_TICK_PERIOD = 5;

// Belief horizon in ticks. Ages are stored as tick stamps, not diag_tickTime, so a savegame gap does not
// silently age belief (diag_tickTime is not restored -- docs/info/architecture/arma_engine_gotchas.md).
OPCOM_BELIEF_FRESH  = 60;    // 300s @ 5s tick
OPCOM_BELIEF_EXPIRE = 240;   // 1200s @ 5s tick

// Coverage trust horizon in ticks: how long a guaranteed sweep keeps a cell "recently looked at" before its
// staleness climbs back to max. Separate from belief's horizons -- a clear sweep, not a sighting -- so its
// own knob. Cells init a full span in the past (fnc_opcom_grid_init), so never-seen reads max, no sentinel. Tune.
OPCOM_COVER_SPAN = 120;      // 600s @ 5s tick

// Ticks a live tasking must stay clear of every player and live BLUFOR group before it re-virtualises -- a run,
// not one far sample, so a fast flyover cannot spawn then stow a group in a single pass.
OPCOM_REVIRT_GRACE = 6;      // 30s @ 5s tick

// Unbroken ticks with BLUFOR within K before a virtual tasking spawns, so a jet crossing the ring on one tick spawns nothing.
OPCOM_DEVIRT_BUFFER = 2;

// How far a de-virtualising hull may shift onto ground it fits on, clear of other hulls (fnc_opcom_stream); tight, so it stands near the leg it reached.
OPCOM_DEVIRT_CLEAR_R = 100;

// Seconds one round may take before it is written off and its AP refunded (fnc_opcom_fires).
OPCOM_ARTY_ROUND_SECS = 10;

// A fire mission's tightest spread: a saturate radius, a creep's width and its length never close below it.
OPCOM_ARTY_MIN_SPREAD = 50;

// Seconds between one gun of a battery opening fire and the next, so a battery ripples rather than volleys.
OPCOM_ARTY_STAGGER = 1;

// Metres of a creep's length, and of each gun's lane across its width, that one round covers (fnc_opcom_fires).
OPCOM_ARTY_CREEP_STEP = 50;
// An arty_creeping mission's box (m), walked forward through its offensive's objective, and the share of the force
// that offensive stakes it is worth: a creep buys the wave's survival, not kills. Tune.
OPCOM_ARTY_CREEP_WIDTH = 150;
OPCOM_ARTY_CREEP_LENGTH = 200;
OPCOM_ARTY_CREEP_SHARE = 0.5;

// Metres a fire mission's pattern may wander per creep row or saturate round, a random walk, so no barrage runs true.
OPCOM_ARTY_WANDER = 10;

// Most seconds a gun waits at random before each round, so the impacts keep no rhythm to count.
OPCOM_ARTY_JITTER = 2;

// A rocket launcher's OPCOM_ARTY_JITTER: none, so its salvo goes as fast as the gun reloads, where a tube walks its rounds in.
OPCOM_ARTY_ROCKET_JITTER = 0;

// Metres a rocket may land from its aim point, on top of the pattern: rockets fall wider than shells (fnc_opcom_fires).
OPCOM_ARTY_ROCKET_SCATTER = 75;

// What the Arty action decides with. Spread is the size of the pattern it asks for: a base by type, wider the
// further the gun shoots.
OPCOM_ARTY_SPREAD = createHashMapFromArray [["MORTAR", 50], ["ARTY", 100]];
OPCOM_ARTY_SPREAD_PER_KM = 25;
// Rounds a saturate lays per gun. A creep's rounds follow from its size instead.
OPCOM_ARTY_ROUNDS = createHashMapFromArray [["MORTAR", [4, 8]], ["ARTY", [6, 10]]];
// The radius a round kills inside: what the pattern's saturation, and so the mission's Value in kills, is measured on.
OPCOM_ARTY_LETHAL = createHashMapFromArray [["MORTAR", 20], ["ARTY", 30]];
// No mission is aimed inside this of the player HQ (rounds may still stray there from a barrage aimed elsewhere).
OPCOM_ARTY_HQ_CLEAR = 100;
// Seconds before the first round lands that the telegraph goes out.
OPCOM_ARTY_WARN = 20;
// Ticks a gun rests after it fires, so a full wallet cannot keep a battery shelling without pause.
OPCOM_ARTY_COOLDOWN = 360;   // 1800s @ 5s tick

// An interceptor's reveal in Chebyshev grid cells, taken once it stands in the cell it was sent to: a guaranteed
// look like a recon's (fnc_opcom_patrol_sense), but paid for by arriving rather than carried the whole way. It is
// the interceptor's alone (fnc_opcom_intercept) -- a hunt needs to find a group that has moved off the fix it was
// sent to, where a patrol without the recon flag stamps that it passed and nothing more.
OPCOM_INTERCEPT_K = 1;

// Leader within this of a move target counts as arrived, so a live tasking settles to guard/garrison the same
// tick instead of holding a stale MOVE on the OPCOM map until a later stow re-virtualises it.
OPCOM_MOVE_ARRIVE = 50;      // m

// A town errand targets the town centre, often deep in streets a truck never threads.
OPCOM_DELIVER_ARRIVE = 100;  // m

// Height a de-virtualised air tasking enters at, flying, above its world point -- a fixed height rather
// than the stored z, so a helicopter neither creeps up nor sinks across stow/spawn cycles.
OPCOM_AIR_SPAWN_ALT = 150;

// Additive firepower premium per human in a sighted BLUFOR group: the group's hardware is priced in full
// (fnc_opcom_sense), then each human aboard adds this on top -- a player is more dangerous than the same
// vehicle or rifle in AI hands, so a crewed or carried player weighs heavier on the grid. Tune.
OPCOM_PLAYER_WORTH = 3;

// How far an OPFOR observer's knowledge query reaches in the sighting sweep. A bound on nearTargets, not a
// detection-range model: the engine returns only targets the observer actually knows about, so this just
// caps the scan cost. Generous, so a genuinely-spotted distant vehicle is not clipped.
OPCOM_SENSE_RANGE = 5000;

// Live OPFOR observers sensed per tick. Above this many, the sighting sweep spreads them across ticks
// (fnc_opcom_sense) so a mass battle does not sense all at once; the defer stays inside OPCOM_BELIEF_FRESH.
OPCOM_SENSE_BATCH = 8;

// A recon-flagged tasking's guaranteed detection reach in Chebyshev grid cells by platform
// (fnc_opcom_patrol_sense), the same cell measure as DUWS_opcom_streamK. Unlike OPCOM_SENSE_RANGE above this
// is a true sensor bubble, not a scan cap: every BLUFOR group within reach is stamped for certain, virtual
// or live. Foot and car both sweep the 3x3 around them; a heli buys real reach. Tune.
OPCOM_RECON_K = createHashMapFromArray [
    ["inf", 1], ["wheeled", 1], ["rotary", 3]
];

// The floor BLUFOR-held ground -- a zone, or a town inside their band -- deposits to the enemy layer: ground
// with no garrison on it is still worth taking. A garrison above it reads at its true force. A standing OPFOR
// hardpoint has no such floor -- its force composes from its static and garrison (DUWS_fnc_hpForce).
OPCOM_GRID_ZONE_ENEMY_FORCE = 8;

// OPCOM tasking (Phase 3). Scalar tunables only; the per-type speed/reach tables and the recruit menu are
// data, kept with the store in fnc_opcom_tasking_init so they resolve at runtime alongside the force model.
// Server-only, read by the tasking phase of the perception loop.

// What OPCOM pays, keyed by the thing it buys: a DUWS_opcom_recruitMenu row id here, a hardpoint type below. Never
// off the composition or its force -- that tied two rows sharing a composition to one price, and made the same order
// cost different amounts at different sites. Set against an OPFOR zone and town income near 40-80 AP per 30 min, before
// OPCOM's drip (OPCOM_AP_DRIP_TICKS).
OPCOM_AP_UNIT = createHashMapFromArray [
    ["rifles", 10], ["weapons_team", 5], ["recon_foot", 5],
    ["truck", 3], ["recon_car", 10], ["boat", 3],
    ["car", 5], ["apc", 15], ["ifv", 25], ["mbt", 40],
    ["recon_heli", 20], ["trans_heli", 10], ["attack_heli", 50], ["jet", 80]
];

OPCOM_AP_HARDPOINT = createHashMapFromArray [
    ["ROADBLOCK", 8], ["MG", 12], ["GMG", 16], ["AT", 16], ["AA", 20]
];

// Flat wherever the step lands and whatever it buys back: pricing it on the tokens owed made the cost a lottery on
// what died there. A town adds only its truck, the delivery rather than the step. Fortify is dearer because a tier
// raise is permanent where a refill is consumed.
OPCOM_AP_REINFORCE = 15;
OPCOM_AP_FORTIFY = 25;

// Scored per km on every source and charged on none: it is what lets a near hire beat a far free unit.
OPCOM_AP_PER_KM = 0.5;
OPCOM_AP_RAPPORT = 10;
// The reputation a delivered Rapport takes off its town, of the 10 that flip it.
OPCOM_RAPPORT_STEP = 3;
// Asset hardpoints are flat-priced: what they are worth is reach, eyes or fire missions, not the force they field.
OPCOM_AP_TOWER = 30;
OPCOM_AP_OP = 15;
OPCOM_AP_MORTAR = 25;
OPCOM_AP_ARTY = 50;
// Per 50 m square, so a longer belt costs by its footprint. Low because a belt is tens of squares: at the
// longest belt it is the dearest thing OPCOM buys, and any dearer a square puts even a short one over the
// bank horizon, where the pick can never reach it.
OPCOM_AP_MINEFIELD = 1;
// A belt OPCOM lays, in metres: fixed depth, length rolled per field. Metres rather than squares because
// DUWS_mineSquare is defined in server_fnc_init, which loads after this file. Depth is what a crossing
// vehicle actually meets, so it carries the belt's lethality and the per-cell density stays low.
OPCOM_MINE_DEPTH = 150;
OPCOM_MINE_LEN_MIN = 500;
OPCOM_MINE_LEN_MAX = 1500;
// AP is the ammunition: the guns rest empty and are loaded per mission, so only the wallet and OPCOM_ARTY_COOLDOWN limit them.
OPCOM_AP_PER_ROUND = createHashMapFromArray [["MORTAR", 2], ["ARTY", 3]];
// Mortar pits and batteries are the only permanent-crew hardpoints, so their count bounds the resident AI.
OPCOM_CAP_MORTAR = 2;
OPCOM_CAP_ARTY = 1;
// These types, and all types together, cap per campaign zone with the seeded hardpoints counted: the seed
// grows with the zone count, so a flat cap would sit under a large campaign's seed and far over a small one's.
OPCOM_CAP_HP_PER_ZONE = 12;
OPCOM_CAP_HP_TYPE_PER_ZONE = createHashMapFromArray [
    ["AT", 2], ["AA", 2], ["GMG", 1], ["OP", 2], ["MINEFIELD_AT", 1], ["MINEFIELD_AP", 1]
];
// Supply trucks sit outside the unit cap: OPCOM_CAP_SUPPLY bounds them, and counting them would let a full
// roster stall every supply buy.
OPCOM_CAP_UNITS_PER_ZONE = 8;
OPCOM_CAP_GARRISON = 10;
OPCOM_CAP_SUPPLY = 10;
// Fixed per type: a gun's true range is the faction gun's, known only at fire time.
OPCOM_MORTAR_REACH = 4000;
OPCOM_ARTY_REACH = 15000;
// No gun sites this close to another of its type, so two pits never share one hill.
OPCOM_GUN_STANDOFF_K = 1;
// Band cells each build type weighs per pick, the best by its own Value taken.
OPCOM_SITE_SAMPLES = 8;
// Need cells a Patrol weighs per pick. Each sweeps a line per candidate unit, the pick's costliest row.
OPCOM_PATROL_SAMPLES = 3;

// OPCOM appraisal (Phase 4C). Every figure below is a stand-in to be tuned in play, not a balance decision.

// The floor keeps a deep-rear holding worth defending at all.
OPCOM_EXPOSE_NEAR = 5000;
OPCOM_EXPOSE_FAR = 10000;
OPCOM_EXPOSE_FLOOR = 0.2;

// A mast's defend ramp: the far edge matches AOI_ZONE_REACH, the widest a band candidate sits from its zone, so the
// ramp spans every site a mast can draw.
OPCOM_DEFEND_NEAR = 500;
OPCOM_DEFEND_FAR = 2000;
OPCOM_DEFEND_FLOOR = 0.2;

// A town's worth is its income level (1-5) times this, so the richest town still scores under the poorest zone.
OPCOM_TOWN_WORTH = 5;

// Banking's flat score, under the break-even 1 of an action that returns exactly what it costs, so OPCOM saves only
// when nothing on the shortlist pays for itself.
OPCOM_BANK_SCORE = 0.5;

// Value that lands later counts for less, halving over this many ticks of travel.
OPCOM_VALUE_HALFLIFE = 360;

// A ground hull's lift drive is priced at this multiple of the straight line, since it keeps to the roads a helicopter
// flies over.
OPCOM_ROAD_DETOUR = 1.3;

// The taxi saving prices the drive alone, so a hop inside this 5x5 block would score a lift the board and drop eat.
OPCOM_TAXI_MIN_K = 2;

// Ticks OPCOM will bank toward an unaffordable top pick: one economy period, since income lands in lumps and a
// shorter horizon would rarely hold a payout.
OPCOM_SAVE_HORIZON = 360;

// A cell BLUFOR cross once fades within the hour while a route they use every trip stays lit.
OPCOM_TRAFFIC_HALFLIFE = 360;
OPCOM_TRAFFIC_SHARE = 0.5;
// Infantry's rate, the cheapest force OPCOM buys.
OPCOM_AP_PER_FORCE = 1;
// A band cell's base need is a zone's average pull per cell divided by this: a holding pulls harder than a gap, but
// not so hard that hardpoints cluster around zones.
OPCOM_NEED_BASE_RATIO = 2.5;
// Chebyshev reach in cells of a hardpoint's cover and a standalone build's Value: a 5x5 block.
OPCOM_BLOCK_K = 2;
// Chebyshev reach in cells of a holding's need spread and an Intercept's need sum: a 7x7 block. Wider than the cover
// reach so a holding pulls defense from further out without spacing the standalone builds wider.
OPCOM_NEED_K = 3;

// A Patrol is worth this share of the need on the ground it sweeps: a patrol takes and protects nothing itself.
OPCOM_PATROL_SHARE = 0.2;
// The force a patrol's threat scale reads 1 at, a rifle squad's: unscaled, Cost pricing the force staked would leave
// every patrol to the cheapest infantry (fnc_opcom_patrol).
OPCOM_PATROL_FORCE_REF = 8;

// A Probe is worth this share of the stake about to be laid on its reading, a whole-stale block × the Attack's Cost
// there. It stops the moment its target's 3x3 block reads fresher than OPCOM_PROBE_FRESH, and a block already that
// fresh offers no Probe. Tune.
OPCOM_PROBE_SHARE = 0.25;
OPCOM_PROBE_FRESH = 0.1;

// Sharpness is how decisive the commander reads: 0 draws evenly, 1 in proportion to score, higher takes the top.
OPCOM_PICK_TOP = 10;
OPCOM_PICK_SHARPNESS = 2;

// An order that fights for its target drops below these odds at commit: one unit sent in on worse is thrown away.
OPCOM_PWIN_FLOOR = 0.3;

// An Attack musters until the force it binds reaches IDEAL times the believed BLUFOR force at the target. At EXPIRY
// ticks it launches on MIN or is abandoned, so a player who keeps reinforcing cannot hold it forever. The bars sit
// below an attacker's usual 3:1 because a sighted player already counts as 1 + OPCOM_PLAYER_WORTH. Tune.
OPCOM_MUSTER_IDEAL = 1.5;
OPCOM_MUSTER_MIN = 0.75;
OPCOM_MUSTER_EXPIRY = 240;       // ticks; 20 min @ 5s tick
// A QRF's muster window: its target moves, so it goes on what it has by then. Tune.
OPCOM_QRF_EXPIRY = 6;            // ticks; 30 s @ 5s tick
// Below this ratio of force to believed BLUFOR force an offensive holds rather than musters.
OPCOM_MUSTER_HOLD = 0.5;
// An attack under way fails below this ratio, on the muster bars' scale. Tune.
OPCOM_ATTACK_BREAK = 0.2;
// How long no assault or flank opens on a zone after one fails there in execution, rolled between the two. Tune.
OPCOM_ATTACK_COOLDOWN = [240, 720];   // ticks; 20-60 min @ 5s tick
// The cells across an assault's staging line, a bucket of units each.
OPCOM_ASSAULT_CELLS = 3;
// The most units one attack binds across all its buckets. Tune.
OPCOM_ATTACK_UNITS = 10;
// The least Chebyshev cells from its target's cell an attacker stages at: 4 (2 km) keeps the muster well clear of the
// 3x3 block the muster bars and P(win) read, and of the fight it is gathering for. Tune.
OPCOM_RALLY_K = 4;
// Chebyshev cells from its target's cell a flank's hook waits at before it closes: 2 is the nearest ground outside the
// 3x3 block the fix fights in. Tune.
OPCOM_HOOK_K = 2;
// From this ratio up an envelopment buys a setup leg and nothing else, so an Attack only assaults. Tune.
OPCOM_BAND_CRUSH = 2;

// Order-sticky hold in ticks: once OPCOM issues an order it may not re-issue for this many ticks -- an
// anti-flap lock against fast re-scoring, not a success deadline. Resting garrison/guard taskings are
// unheld. Six ticks at the 5 s cadence is 30 s.
OPCOM_COMMIT_HOLD = 6;

// Per-tick fraction of fullForce a garrison-tasking unit regenerates toward full, mirroring the zone
// reinforce path; guard does not heal, nor a garrison whose zone is contested. 0.05 restores a unit to full in
// ~20 ticks (~100 s). Tune.
OPCOM_GARRISON_HEAL_RATE = 0.05;

// Smallest navigable water body, in grid cells: a connected water component of at least this many cells is a
// boat's domain; anything smaller is "too small for water" and only air crosses it. ~10 keeps boats off
// ponds and narrow rivers. Tune.
OPCOM_WATER_MIN_CELLS = 10;

// Metres a lambda-1 route pays to cross a cell, per unit of believed BLUFOR force there, so it detours around a
// threat rather than through it. An errand, a return and an enveloping role run lambda 1; every other order runs 0,
// distance only (fnc_opcom_task). Tune.
OPCOM_ROUTE_LAMBDA = 200;

// Ferry lift penalty (metres): the cost a land move type pays to step into a navigable-water cell, set far
// above any land detour the play box can hold -- so a target across water is reachable, but water is taken
// only when no land route exists, and among water routes A* still picks the shortest (opcom_plan.md §Shipped).
OPCOM_ROUTE_LIFT_PENALTY = 1e6;

// Metres a route pays to enter a cell it must go round (a flank's hook round the fight), set far above any detour so
// the cell is crossed only when no way round exists.
OPCOM_ROUTE_AVOID_PENALTY = 1e6;

// Throttle for the stranded-rider WARN: with no lift free a rider retries every tick, so it logs only once
// per this many -- an island-gap deadlock surfaces in the RPT without flooding it (opcom_plan.md §Shipped).
OPCOM_FERRY_STRAND_TICKS = 24;   // ticks; 120s @ 5s tick

// Live ferry rendering tunables (docs/plans/opcom/opcom_plan.md §Shipped). The wait cap is the load-bearing one:
// a board or landing that never settles (a bad LZ, stuck AI) forces through at it rather than hang bound.
OPCOM_FERRY_BOARD_BOAT = 100;    // m; a boat reaches its park, and its riders their shore, within this
OPCOM_FERRY_BOARD_GROUND = 50;   // m; a ground taxi stops and holds this close to the men, and to the drop
OPCOM_FERRY_BOAT_PARK = 100;     // m; a live boat parks this far out from the shoreline, clear of the shallows
OPCOM_FERRY_SHORE_ARRIVE = 100;  // m; leader within this of the shore stage calls the ferry (own tunable, not the streaming margin)
OPCOM_FERRY_GROUND_ALT = 4;      // m ATL under which a landing rotary counts as grounded (mirrors fnc_helotaxi)
OPCOM_FERRY_STAGE = 50;          // m; a rotor's riders wait this far off the LZ while it descends, clear of the skids
OPCOM_FERRY_WAIT_MAX = 20;       // ticks a timed ferry phase (land/board/unload) may stall before the fallback forces it through
OPCOM_FERRY_LAND_K = 1;          // grid cells: a lift enters its landing phase this close to its pickup or drop (k, not metres)

zoneundercontrolblu = 0;publicVariable "zoneundercontrolblu";

// How close to a base an intact vehicle must park to survive the cleanup sweep. Read by both the sweep
// (fnc_repetitive_cleanup.sqf) and the base ring marker (fnc_baseRangeMarker.sqf) -- a ring that
// disagreed with the sweep would promise safety on ground where the vehicle is collected. Broadcast so
// the depot's retrieve carry blocks release outside the same ring, and reaches JIP clients too.
DUWS_base_keep_radius = 250;
publicVariable "DUWS_base_keep_radius";

// Sequence number of the 30-minute campaign economy tick (fnc_zonesundercontrol.sqf).
// Not broadcast: only server-side payout caps read it.
econ_tick = 0;
// Seconds between economy ticks; OPCOM's savings goal divides a payout by it to read an income rate.
DUWS_econ_period = 1800;
// OPFOR's last economy payout, 0 until the first. OPCOM's savings goal adds it to the drip to read an income rate.
WARCOM_opfor_lastIncome = 0;

// The Intelligence Center's odds by level owned, rolled once per OPCOM tick, and how long a plotted
// OPCOM contact stands before its markers are pulled. Server-only: both the roll and the markers are
// server work. Indexed by level, so index 0 is the unbought centre and never fires.
//
// Per OPCOM tick, so the figures are small and the mean wait is what to read them by: at
// OPCOM_TICK_PERIOD 5 the levels average a find every 60 / 30 / 16 / 10 minutes. A table rather than
// one rate times the level, because that curve paid 4x the rate for 8x the cumulative price and the
// top two levels were never worth buying; this one climbs with what they cost.
DUWS_intel_roll_by_level = [0, 0.0014, 0.0028, 0.0052, 0.0083];
DUWS_intel_contact_life = 600;

// Campaign-size throttle on every passive faucet (zone AP trickle, town income, both sides). Computed
// once from the actual zone count (fnc_WARCOM_init), so income grows as sqrt(zones) above the reference
// size rather than linearly. 1 until WARCOM init sets it, so the default six-zone campaign is unthrottled.
DUWS_econ_throttle = 1;

// OPCOM ticks per 1 AP of drip to OPFOR, on top of the 30-minute payout. The payout lands as one lump
// that the commander spends within a minute, so without a drip it can only bank or move free units for
// the rest of the period. Wallet only: it never credits the earned counter, so it never moves OPFOR's
// tier. Ticks per AP rather than AP per tick, because fnc_ap_adjust keeps the pool whole. Server; tuning.
OPCOM_AP_DRIP_TICKS = 4;

insurgent_mode_enable = false; publicVariable "insurgent_mode_enable";

// Campaign game mode: "duws", "guerilla" or "apocalypse". Republished by the faction screen once the
// host picks; declared here so a machine that never ran setup still reads a mode rather than nil.
duws_gamemode = "duws"; publicVariable "duws_gamemode";

// Two permission lists of playable slot names, checked as (vehiclevarname player) in <list>.
// game_master owns campaign-level controls (setup flow, side-mission requests, global heal);
// Squad_Leaders owns anything spending the shared CP pool (request menus, radio supports, MHQ,
// FOB upkeep) plus High Command.
// Squad_Leaders lists every playable slot today, restricting nothing as shipped -- it exists to be
// trimmed on a dedicated server. Personal kit (medic/engineer/UAV traits) is granted unconditionally
// in client_init.sqf instead, so trimming this cannot take basic capability from the rest of the team.
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
	"player20",
	"player21",
	"player22",
	"player23",
	"player24",
	"player25",
	"player26",
	"player27",
	"player28",
	"player29",
	"player30"
]; publicVariable "Squad_Leaders";
