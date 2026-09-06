// Locality: server -- see callers.
// The config menu overwrites many of these from player input; treat the values here as defaults.

VERSION_X = "MODERN";publicVariable "VERSION_X";
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
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
BLUfactionData = [];publicVariable "BLUfactionData";
OPFfactionData = [];publicVariable "OPFfactionData";

Factions_Available_OPFOR_X = [];publicVariable "Factions_Available_OPFOR_X";
Factions_Available_BLUFOR_X = [];publicVariable "Factions_Available_BLUFOR_X";

amount_zones_created = 0;publicVariable "amount_zones_created";

// Zones whose build-out finished, as opposed to amount_zones_created, which fnc_createZone
// bumps on entry. Civilian generation needs "built", not "started": it counts buildings,
// and prefab zones hide everything within 35 m of their centre partway through build-out.
zones_buildout_done = 0;publicVariable "zones_buildout_done";

amount_zones_captured = 0;publicVariable "amount_zones_captured";

// AO direction for Random Zones
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

// Arsenal mode and ammo tracking, resolved once from the lobby params so the server-side pool writers
// and the client shelf logic read one authoritative answer. Limited count-tracks the player's own
// faction too (no unlimited floor); trackAmmo folds magazines into whatever the mode tracks.
DUWS_arsenalLimited = (["DUWS_ArsenalMode", 0] call BIS_fnc_getParamValue) == 2;publicVariable "DUWS_arsenalLimited";
DUWS_trackAmmo = (["DUWS_TrackAmmo", 0] call BIS_fnc_getParamValue) == 1;publicVariable "DUWS_trackAmmo";

// Limited's starting armoury: every standard-issue class is seeded into the pool at this count at
// boot, since Limited removes the unlimited friendly floor. Tunable; a playtest value.
DUWS_limitedSeed = 100;

// The faction confirmation screen's handshake. Request and ready are counters, not flags: stepping back
// from the environment screen re-enters faction selection and asks again, and a flag cleared by the
// server can race a fresh request from the client. The screen waits for ready to reach the number it
// asked with, so it never reads the previous pick's rows.
//
// duws_faction_locked is the whole confirmed table -- [[side, [[key, value], ...]], ...] -- carried
// whole rather than as a diff, so the server has one code path to apply, not a reconciliation to work out.
duws_faction_preview_request = 0;publicVariable "duws_faction_preview_request";
duws_faction_preview_ready = 0;publicVariable "duws_faction_preview_ready";
duws_faction_locked = [];publicVariable "duws_faction_locked";

// Player squad callsign, set on the callsign setup screen and substituted into
// English radio dialogue by fnc_cs. Default matches the "Alpha 1-1" literal baked
// into the stringtable, so an unchanged callsign leaves every line untouched.
duws_callsign = "Alpha 1-1";publicVariable "duws_callsign";


cp_reward_multiplier = 1;publicVariable "cp_reward_multiplier";

// Kill income. On each campaign economy tick a player's kill tally converts at
// kill_cp_award CP per kill_cp_kills kills; the paid-for kills are debited and the
// remainder carries to the next sweep. The period is the economy tick's own and is not
// tunable here -- a second interval would mean a second clock. Server-only: the tally,
// the sweep and the payout all live on the server, so no client ever reads these.
kill_cp_kills = 10;
kill_cp_award = 1;

// When a FOB or HQ garrison stops being simulated. Nothing culled it before, so every base's soldiers
// ran pathing and targeting for the rest of the campaign regardless of distance. Server-only.
//
// Short on the way down, nothing on the way up: a base is frozen rather than rebuilt, so the only cost
// of freezing early is a returning player watching the garrison start moving -- a frame's cost. The
// zone streamer's two minutes buy a zone something this does not: there, the clock stops a garrison
// being torn down and rebuilt around someone crossing the radius.
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

// The consumable-support slate. support_max_slots caps one-use items a player may carry at once;
// support_death_refund is the share of what they paid (both currencies) refunded on death holding
// unused ones. Half: forgiving, but short of a full refund, so walking an item back beats dying with
// it. Both are read on clients, so both are broadcast.
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

// Vehicle garage state. DUWS_garage_stored is an array of serializable specs (no object handle ever
// enters it), and the four expansion flags are broadcast booleans; both are plain data, so engine
// saveGame carries them with no extra machinery. Base capacity is owned from the start, so no base
// flag exists -- the highest owned expansion, or the base default, sets the caps.
DUWS_garage_stored = []; publicVariable "DUWS_garage_stored";
garage_exp1_owned = false; publicVariable "garage_exp1_owned";
garage_exp2_owned = false; publicVariable "garage_exp2_owned";
garage_exp3_owned = false; publicVariable "garage_exp3_owned";
garage_exp4_owned = false; publicVariable "garage_exp4_owned";

// Zone payouts. Capture is an event reward; holding is an AP trickle on the economy tick
// (zone_ap_trickle, below).
//
// First BLUFOR capture pays a flat liberation bonus (CP and AP both, not a worth-share so a small
// zone is worth taking too) once ever per zone (DUWS_zone_first_captured), so a lost-and-retaken
// zone is not a farm. Recapture pays BLUFOR nothing -- the reward was earned at liberation. No CP
// bounty and no bounty decay: both retired with the town->CP reroute, where passive CP now lives.
//
// AP swings are shares of the zone's worth, so a contested zone swings the same momentum however
// often it flips. OPFOR is paid a consolation every BLUFOR capture (anti-steamroll: a fast advance
// funds the counter-attack) and the full swing on retaking one; BLUFOR sheds it on losing one.
// Server-only: the capture handlers run server-side.
zone_first_capture_cp = 25;  // flat CP the first time BLUFOR ever takes a zone
zone_first_capture_ap = 50;  // flat AP alongside it; credits the tier, the main lever balancing OPFOR's hour-zero zones
zone_ap_swing = 0.15;        // OPFOR's AP gain on retaking a zone, and BLUFOR's loss on losing one
zone_ap_consolation = 0.15;  // OPFOR's AP whenever BLUFOR takes a zone, as a share of worth

// The strategic dividend: AP per held zone, per economy tick, each side, scaled by
// DUWS_econ_throttle. Passive per tick yet earned per zone -- it pays only for ground taken
// and held and stops when a zone is lost, so standing still earns nothing new.
zone_ap_trickle = 5;

// First-captured zone keys, one entry per zone BLUFOR has ever taken. The liberation bonus
// reads this so it never pays twice -- a reload or a retaken zone finds its key already here.
// Save state: it lives in the mission namespace so a campaign save carries it.
DUWS_zone_first_captured = [];

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
// exactly while that composition's streamable members are off the map, so presence here answers "is
// this stowed" without touching an object. Not exclusive with DUWS_compositions: pinned members stay
// behind when the rest of their composition leaves, so a hardpoint whose gun never stows appears in
// both. Records are built when stowed, not when built, so damage, looted crates and moved props are
// captured as they actually are. Transient by design -- nothing here outlives the session; a campaign
// restore replays the builders instead.
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

DUWSMP_CP_death_cost = 2;publicVariable "DUWSMP_CP_death_cost";

dynamic_weather_enable = true;publicVariable "dynamic_weather_enable";	

commandpointsblu1 = 30;publicVariable "commandpointsblu1";

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

hardcore_mode_enable = false;publicVariable "hardcore_mode_enable";

// Opfor gets tanks
HeavyArmor = 1;publicVariable "HeavyArmor";

hq_manually_placed = false;publicVariable "hq_manually_placed";

HQ_pos_found_generated = false;publicVariable "HQ_pos_found_generated";

MASTER_allLocations_filtered = [];//publicVariable "MASTER_allLocations_filtered";
MASTER_allLocationsPos = [];publicVariable "MASTER_allLocationsPos";

// [successChance, [[payoutKind, weight], ...], nothingKey] per search source.
//
// combat is unflagged and rolls at the search, not spawn: any enemy corpse is searchable, and the
// per-player clock (DUWS_searchCooldown) -- not this chance -- bounds intel volume, so its chance is
// high; a rarer roll would only tax a five-minute wait with an empty result. objective and civ_frisk
// are flagged at spawn with chance 1 (never miss, single-use); they read this table only for kinds.
//
// Weights, not a cumulative if-ladder: a ladder's bands each depend on the one above, so adding a
// kind means re-deriving every constant below it, where a weight table just adds a row.
//
// Kinds draw without replacement; one whose payout reports nothing left drops out and the remainder
// re-draw, so an exhausted pool cannot turn a search into silence -- the failure already paid for
// once, when a dry pool returned quietly.
//
// civ_frisk is flagged on every civilian with its own `nothing` weight, keeping the shipped
// 37.5 / 12.5 / 50 split exact (the arrest is the price, paid before this). It no longer carries a
// separate empty-handed line of its own: that read a body holding nothing and a detainee carrying
// nothing as different sentences, but both are the same act by the same searcher, and the odd
// wording read as a different system rather than a different subject.
DUWS_searchSources = createHashMapFromArray [
    ["combat",    [0.80, [["intel", 2], ["money", 11], ["document", 7]],           "STR_DUWS_T_INTEL_FOUND_n"]],
    ["objective", [1,    [["intel", 1]],                                             "STR_DUWS_T_INTEL_FOUND_n"]],
    ["civ_frisk", [1,    [["money", 3], ["document", 1], ["nothing", 4]],            "STR_DUWS_T_INTEL_FOUND_n"]]
];

// The physical intel items a "document" search find drops, and a patrol camp's table may hold. Only
// base-game Item_ ground holders (each has an Item_ ground variant, so createVehicle works and a dropped
// copy survives rather than vanishing) belong here. Weighted, parallel arrays: cheap 1-CP items dominate
// and the guaranteed-reveal FilesSecret is rare. Labels are the readable name a hint uses -- these holders
// carry generic or empty displayNames, so the label is the mission's to own. Shared so the search payout
// and the camp draw from one list rather than two that drift apart.
DUWS_intelDocuments = ["Item_MobilePhone", "Item_Wallet_ID", "Item_SmartPhone",
    "Item_FlashDisk", "Item_Files", "Item_FilesSecret"];
DUWS_intelDocumentWeights = [30, 30, 20, 10, 6, 4];
DUWS_intelDocumentLabels = ["STR_DUWS_T_INTEL_ITEM_phone", "STR_DUWS_T_INTEL_ITEM_wallet",
    "STR_DUWS_T_INTEL_ITEM_smartphone", "STR_DUWS_T_INTEL_ITEM_flashdrive",
    "STR_DUWS_T_INTEL_ITEM_files", "STR_DUWS_T_INTEL_ITEM_filessecret"];

// Seconds a player must wait between combat-corpse searches. The combat source no longer flags
// bodies at spawn: any enemy corpse is searchable and the success roll is spent at the search, so
// this clock -- not troop density -- is what bounds intel volume. Deliberately long to keep that
// volume low without per-source balancing. Objective and civ_frisk searches are single-use and bypass it.
// Broadcast because the search action's condition gates the prompt on the client.
DUWS_searchCooldown = 300; publicVariable "DUWS_searchCooldown";

manually_chosen = false;publicVariable "manually_chosen";

Mission_available = true;publicVariable "Mission_available";

// The side-mission gate: a new mission may start only once this many in-game hours have passed since
// the last one started -- see shared/functions/fnc_mission_gate_left.sqf for the clock and why. This
// is the whole wait between missions: the slot itself frees the moment one ends, so this paces them.
// A rest at HQ skips three in-game hours and so clears the gate in one go.
// Broadcast because the readout and the strategic map both read it on the client.
mission_gate_hours = 3;publicVariable "mission_gate_hours";

// The last mission's start, stamped as a campaign-date number (dateToNumber date). Zero until the
// first mission, which reads as long past and so opens the gate.
DUWS_lastMissionStartDate = 0;publicVariable "DUWS_lastMissionStartDate";

MissionLocations = [];publicVariable "MissionLocations";

// moreUrban zones and missions
moreUrban = 1;publicVariable "moreUrban";

// Share of a zone's mobile garrison fielded at once (1 = all). Below 1, the remainder seeds the
// reserve pool so even a x1 zone reinforces. Default here covers the pre-commit window and a campaign
// that predates the setting; the campaign screen overwrites it (fnc_process_campaign_menu).
garrison_density = 1;publicVariable "garrison_density";

opfor_ai_skill = [0.55,0.75];publicVariable "opfor_ai_skill";

opfor_SOLDIER_X = "";

player_is_choosing_hqpos = false;publicVariable "player_is_choosing_hqpos";

PosOfBLUHQ = [];publicVariable "PosOfBLUHQ";

serv_zones_array = [];publicVariable "serv_zones_array";

simple_zones_enable = false;publicVariable "simple_zones_enable";

apocalypse_mode = false; publicVariable "apocalypse_mode";

WARCOM_blufor_ap = 0;publicVariable "WARCOM_blufor_ap";
WARCOM_opfor_ap = 0;publicVariable "WARCOM_opfor_ap";
// Ladder input and its tier, per side. The earned counter only ever rises (credited by the recurring
// faucets, never by spending), so the tier derived from it is a one-way ratchet a spent-down wallet
// cannot lower. Seeded to match a starting-AP preset in fnc_WARCOM_init; these are the pre-preset
// defaults. Not yet carried by the campaign save -- a reload re-derives the tier from a wallet since
// spent down, which the persistence pass closes (docs/plans/campaign_persistence_plan.md).
WARCOM_blufor_ap_earned = 0;publicVariable "WARCOM_blufor_ap_earned";
WARCOM_opfor_ap_earned = 0;publicVariable "WARCOM_opfor_ap_earned";
WARCOM_blufor_tier = 0;publicVariable "WARCOM_blufor_tier";
WARCOM_opfor_tier = 0;publicVariable "WARCOM_opfor_tier";
WARCOM_init_done = false;publicVariable "WARCOM_init_done";

// Declared here, not just in fnc_WARCOM_init: the area-of-influence read (DUWS_fnc_aoi_covers /
// _bandPos) resolves zone control off this list, and hardpoint generation samples the band a full
// phase before fnc_WARCOM_init runs. Undefined there, every band draw threw and the flank/AA/roadblock
// passes placed nothing. Empty = every zone OPFOR, which is the truth at hour zero; WARCOM_init resets it.
WARCOM_zones_controled_by_BLUFOR = [];

// choose between "none" - "tropical" - "arid" - "temperate" - "temperate_cold" - "mediterranean"
weather_type = "none";publicVariable "weather_type";

// Zeus visibility
ZeusStatus = 2;publicVariable "ZeusStatus";

// Civilian faction. Defaulted here like every other environment setting: six subsystems read it with
// no isNil guard, so leaving it unset makes each error separately and civilians never generate, with
// nothing in the log naming the cause. "med" is the only pool entirely base-game Altis classes, so it
// is the one default that cannot pull in a mod dependency on the map this mission ships for.
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
// minimum space between 2 zones (in meters) // SOON OBSOLETE
zones_spacing = 1200; 
// Determine the maximum radius a generated zone can have
zones_max_radius = 1000;publicVariable "zones_max_radius"; 
// Determine the minium radius a generated zone can have. SHOULD NOT BE UNDER 200.
zones_min_radius = 200;publicVariable "zones_min_radius";

// Hardpoint streaming, per type: [spawnRadius, grace, neverStream, airRing].
//   spawnRadius  distance BLUFOR wake the emplacement at (a fight holds it past this; see the tick).
//                800 for direct-fire nests that must open up before the player closes; 600 for the rest --
//                an OP screens its sector past this ring anyway (OP_OBSERVE_RADIUS), and a radio mast or a
//                battery is destroyed up close, so none of those needs to wake at gun range
//   grace        seconds empty before it stows
//   neverStream  built once and kept resident, never stowed. Mortar and artillery hold so OPCOM can
//                task them with no player near; a minefield holds so its mines are never stowed off
//                the map, leaving its own hazard list as the real count of what is armed. Only the
//                composition is pinned -- the loose garrison still streams, so a battery's defenders
//                stow when its ring is empty rather than patrolling the whole campaign. The gun crew is
//                the exception and stays live: a frozen crew cannot fire
//   airRing      a second, larger radius answered only by aircraft; 0 = none. AA reaches out to
//                catch a jet overhead its ground ring would never notice, without waking on
//                every distant foot patrol.
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

// Zone air streaming: a player-crewed aircraft or a UAV committing to a zone wakes its garrison, where
// the ground ring discounts anything airborne (fnc_duws_bluforNear, "a helicopter on the deck is still
// nobody arriving"). Committing, not transiting, and player-crewed, not AI: only a player-flown heli or
// a UAV holding under DUWS_zoneAirCommitSpeed counts, so a jet at cruise, an AI transit, or an AI
// support heli places nothing -- no garrison stood up for aircraft the player is not steering. This is
// the zone's own reach; AA keeps the raw, ungated air ring above so it still catches any jet. Ring 0
// turns the feature off -- the zone's air answer falls back to ground only. Server-only: the consumers
// (fnc_createzone, the site poller, the zone raise worker) all run on the server.
DUWS_zoneAirRing = 1500;
DUWS_zoneAirCommitSpeed = 250;   // km/h; a player heli inbound or UAV on-station sits under it, a jet at cruise does not

// The radio tower's mast: the one composition member left simulated and damageable, and the object
// fnc_hardpoint_stream watches to clear the tower -- destroying it takes the hardpoint, not beating its
// garrison. The rest of the base stays frozen invulnerable cover. Server-only, like every hardpoint
// consumer.
DUWS_radioMastClass = "Land_TTowerBig_2_F";

// How common each hardpoint type is before terrain -- the base weight the siting loop multiplies the
// terrain score by; each map's keys ARE its roll set, so a type absent from a map is never rolled for
// that pass. Two mixes: a zone's fortification ring is the ground-assault set (MG the backbone, GMG the
// rare supporting weapon); the standalone AoI net also fields AA (weighted under MG so it does not
// out-place the guns on the flat ground AA favours) and leans harder on roadblocks. Minefields and the
// fire-support types are in neither -- OPCOM's to place, never rolled at init. OPs are absent from the maps
// too, but a dedicated band pass rolls them at init (an inline OP-only mix, one per zone at HP_OBS_P
// probability). fnc_hardpoint_lay picks the map by whether the row files under a zone (a zoneKey) or stands
// alone ("").
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

// Bounty for destroying a standalone hardpoint, [CP, AP], read by fnc_hardpoint_stream when it clears.
// Types not listed pay the base 5 CP and no AP: only the strategic emplacements a player crosses the
// map to kill pay above the floor -- the batteries OPCOM fires from (ARTY, MORTAR) and the radio tower,
// whose 5 km reach makes it the greatest single loss to OPFOR. Where a type pays AP it is earned (raises
// the BLUFOR tier), the mission-reward contract, not a spend.
DUWS_hardpointBounty = createHashMapFromArray [
    ["RADIO", [10, 10]], ["ARTY", [10, 5]], ["MORTAR", [10, 0]]
];

// The loose garrison each hardpoint type fields: one DUWS_teamRosters token, or an array of them for a
// type fielding several groups, resolved per side when crewed -- read by fnc_hardpoint_register and the
// raise worker so every placer fields it the same way, as DUWS_hardpointStreaming drives streaming.
// "" is no loose garrison: a minefield alone gets none, its men would stand on its own mines.
// An observation post is a lookout, not a strongpoint: a close security team holds the post while a recon
// patrol screens wide, so it keeps eyes out past its own ground instead of hugging the bunker.
// AT and AA field the weapons team, not the rifle team: defenders carry launchers matching the emplaced
// gun's role (AT nest -> standoff AT, AA nest -> MANPADS) instead of a generic section. Trade-off:
// wp_team has no AR, GL or marksman, so those two hold harder against armour and air but lighter
// against a dismounted assault.
// A radio tower is a strategic objective with 5 km reach, so it fields a heavier patrol -- a rifle team
// plus two weapons teams to contest the air and armour brought against it, part screening wide
// (widepatrol) to meet the approach while the rest hold the mast close. Its gun crew is separate and
// always placed.
// Artillery and mortars are batteries OPCOM fires from, so their loose garrison scales to the threat:
// artillery (longer reach, greater loss) holds two weapons teams and a rifle team; a mortar holds one
// weapons team and a light patrol. Gun crews are separate and stay resident while the loose garrison
// streams, so OPCOM keeps firing between raids. On each, one element screens wide (widepatrol) to catch
// the assault on the rim while the rest hold close.
DUWS_hardpointGarrison = createHashMapFromArray [
    ["MG", "team"], ["AT", "wp_team"], ["GMG", "team"], ["ROADBLOCK", "team"],
    ["OP", ["closepatrol:team", "widepatrol:recon"]], ["AA", "wp_team"], ["MORTAR", ["wp_team", "widepatrol:patrol"]], ["ARTY", ["wp_team", "wp_team", "widepatrol:team"]],
    ["RADIO", ["wp_team", "widepatrol:wp_team", "widepatrol:team"]], ["MINEFIELD", ""]
];

// Per-posture spawn band and circuit radius, each a fraction of the spawn radius the caller passes.
// [minFrac, maxFrac, patrolFrac]: a group spawns between minFrac and maxFrac of that radius from centre
// and circuits at patrolFrac. Read by fnc_spawn_team/fnc_spawn_vehicle for placement and by
// fnc_apply_posture for waypoint reach -- one table so the two cannot disagree: a wide patrol spawns and
// lives on the outer ring, a close one hugs the objective. A posture absent here (hqpatrol, none) keeps
// the old uniform band since those place their own men; garrison spawns inner and claims structures
// within its own fixed reach, so patrolFrac applies only on the fallback patrol when nothing is found.
DUWS_postureBands = createHashMapFromArray [
    ["closepatrol", [0.1, 0.5, 0.4]],
    ["widepatrol",  [0.5, 1.0, 0.9]],
    ["garrison",    [0.1, 0.5, 0.4]]
];

// The margin beyond a zone's own radius that its streaming reaches: a zone raises and holds its
// garrison for BLUFOR this much further out than the capture trigger tests, so the men are on the
// objective before the players who tripped it arrive. Read by fnc_createZone and fnc_zone_stream_init.
DUWS_streamArrivalMargin = 400;

// Zone reserve / reinforcement tuning. The enemy multiplier is reserve depth: a zone always fields at
// most its x1 tier composition on the ground, and the surplus (mult-1) copies wait as a pool that
// refills the garrison to that x1 group count as casualties are taken. Server-side only, so not
// broadcast (the DUWS_streamArrivalMargin pattern). Read by fnc_zone_reserve and fnc_zone_spawn_sizes;
// the model is docs/info/gameplay/garrison_and_reserves.md.
//
// The global OPFOR-side group throttle. When the live east group count reaches this, zone garrison
// spawns and refills pause and their tokens stay pooled. Below the engine's 144-groups-per-side hard
// cap (past which createGroup returns grpNull silently) with slack for transient spikes: the co-op
// backstop for several players in several zones plus hardpoints summing past the wall, which the
// per-zone ceilings alone would not catch.
DUWS_zoneGroupCeiling = 130;

// The event trigger fraction. A zone whose live groups fall below this fraction of its x1 ceiling
// pulls an immediate refill wave rather than waiting for the poll, so reinforcement reads as waves
// rather than one-in-one-out.
DUWS_zoneReinforceFrac = 0.5;

// The floor distance a reinforcement spawns from the nearest player, in metres. Flat, not
// zone-relative, so it reads the same at a 50 m base and a 1300 m island -- a radius-relative distance
// would drop reserves a kilometre out of the island and on top of the player in the base.
DUWS_zoneReserveSpawnDist = 400;

// How far to look for a road around a chosen far-side spawn point, in metres. A reserve wave rides
// trucks now, so it stands up on drivable ground rather than on a hillside a truck cannot leave. Wide
// enough to find a road off most approaches, tight enough that the road pick stays near the anti-flank
// bearing. No road in range leaves the off-road point -- some approaches simply have none.
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
// centre -- so a naturally large zone claims proportionally more ground than a small one, and every
// source owns a band outside its own footprint. Read only by fnc_aoi_init's coverage tests, all
// server-side, so not broadcast (the pattern DUWS_streamArrivalMargin already sets). The values are
// large against Altis by intent: OPFOR influence blankets most of the map at start and the player
// opens with 2 km around the HQ. Tuning lives here; see docs/info/gameplay/opfor_area_of_influence.md.
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

// OPCOM perception. Plain globals not #define -- the opcom files that read them load by compile-path and
// run later, out of reach of a macro scoped to this file. Influence-grid geometry in metres:
OPCOM_GRID_CELL   = 500;
OPCOM_GRID_SPREAD = 1000;

// The single loop cadence in seconds: one tick senses, ages belief and rebuilds the grid (Phase 2 scores
// and commits one action on the same tick; Phase 4 steps movement here too). Kept fast on purpose -- a
// finer tick reads as a more reactive commander, and movement/economy scale with it (smaller steps, finer
// spend) rather than breaking.
OPCOM_TICK_PERIOD = 5;

// Belief decay in real time, converted to tick counts so OPCOM_TICK_PERIOD stays a pure resolution knob:
// retune the tick and the memory horizon holds. Counted in ticks, not seconds, so a savegame gap does not
// silently age belief (diag_tickTime is not restored -- docs/info/architecture/arma_engine_gotchas.md).
OPCOM_BELIEF_FRESH_S  = 240;
OPCOM_BELIEF_EXPIRE_S = 960;
OPCOM_BELIEF_FRESH  = OPCOM_BELIEF_FRESH_S  / OPCOM_TICK_PERIOD;
OPCOM_BELIEF_EXPIRE = OPCOM_BELIEF_EXPIRE_S / OPCOM_TICK_PERIOD;

// Threat men a sighted BLUFOR group is worth: each AI counts as one, each human as OPCOM_PLAYER_WORTH --
// a player is more dangerous than an equal AI, so a group carrying one weighs heavier on the grid. Tune.
OPCOM_PLAYER_WORTH = 3;

// Men-count placeholders the grid rebuild deposits where no real strength is tracked: a BLU-held zone
// (the player's garrison is not modelled, but the commander knows it is held) and a standing OPFOR
// hardpoint (its crew). Phase 2 replaces both with firepower-weighted force.
OPCOM_GRID_ZONE_ENEMY_MEN = 8;
OPCOM_GRID_HP_MEN         = 3;

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

// Campaign-size throttle on every passive faucet: the zone AP trickle and town income on both
// sides. Computed once after generation from the ACTUAL zone count (fnc_WARCOM_init), so a large
// campaign does not pay linearly more on every tick -- total passive income grows as sqrt(zones)
// above the reference size rather than in proportion. 1 until WARCOM init sets it, so the default
// six-zone campaign is unthrottled and any tick before init pays the base rate. Server-only.
DUWS_econ_throttle = 1;

// OPFOR's flat AP floor, per economy tick, independent of what it holds. Insurance for a director
// that has lost its towns, not the faucet that paces escalation -- town income outweighs it several
// times over while the enemy holds its zone-adjacent towns. Credits the tier with the rest of OPFOR
// income; unthrottled, being a floor rather than a faucet. Server; tuning.
opfor_flat_ap_income = 2;

insurgent_mode_enable = false; publicVariable "insurgent_mode_enable";

// Campaign game mode: "duws", "guerilla" or "apocalypse". Republished by the faction screen once the
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
