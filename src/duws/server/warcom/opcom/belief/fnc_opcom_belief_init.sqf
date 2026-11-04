// Locality: server. OPCOM's belief store: the parallel arrays the commander plans against instead of
// live player state, plus the strategic-tick clock decay ages stamps against. Handle-free and never
// broadcast -- the mission namespace is the save file, and no client reads belief.
if (!isServer) exitWith {};

_cmd set ["belief_key", []];   // subject: a BLUFOR group netId, a zone index, a FOB index, "HQ"
_cmd set ["belief_pos", []];   // [x,y,0] as last observed, never a live lookup (the sense edge gate enforces it)
_cmd set ["belief_time", []];   // DUWS_opcom_tick at the observation
_cmd set ["belief_str", []];   // believed BLUFOR force there
DUWS_opcom_contested   = createHashMap;   // site key -> true while contested, rebuilt each tick (fnc_opcom_contested)

DUWS_opcom_hqKnown = false;   // one-way, set by fnc_opcom_belief_upsert on the first sighting of an HQ defender
DUWS_opcom_fobsKnown = [];    // FOB site keys, each added the same way on the first sighting of its garrison

DUWS_opcom_tick = 0;
_cmd set ["dbg_fresh", 0];   // groups the sense sweep found freshly-sensed last tick, for the debug line
_cmd set ["dbg_route", [0, 0, 0, 0]];   // grid A* runs, cells expanded, seconds and frames this tick, for the debug line
