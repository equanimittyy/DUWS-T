// Locality: server. OPCOM's belief store: the parallel arrays the commander plans against instead of
// live player state, plus the strategic-tick clock decay ages stamps against. Handle-free and never
// broadcast -- the mission namespace is the save file, and no client reads belief.
if (!isServer) exitWith {};

DUWS_opcom_belief_key  = [];   // subject: a BLUFOR group netId, a zone index, a FOB index, "HQ"
DUWS_opcom_belief_pos  = [];   // [x,y,0] as last observed, never a live lookup (the sense edge gate enforces it)
DUWS_opcom_belief_time = [];   // DUWS_opcom_tick at the observation
DUWS_opcom_belief_str  = [];   // believed BLUFOR force there
DUWS_opcom_contested   = createHashMap;   // zone key -> true while contested, rebuilt each tick (fnc_opcom_contested)

DUWS_opcom_tick = 0;
DUWS_opcom_dbg_fresh = 0;   // groups the sense sweep found freshly-sensed last tick, for the debug line
