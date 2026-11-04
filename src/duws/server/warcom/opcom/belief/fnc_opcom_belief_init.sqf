// Locality: server. The belief state every commander shares: the strategic-tick clock decay ages stamps against, the
// contest set, and OPFOR's discovery of BLUFOR's bases. Each commander's belief store is its record's
// (fnc_opcom_cmd_new). Handle-free and never broadcast -- no client reads belief.
if (!isServer) exitWith {};

DUWS_opcom_contested   = createHashMap;   // site key -> true while contested, rebuilt each tick (fnc_opcom_contested)

DUWS_opcom_hqKnown = false;   // one-way, set by fnc_opcom_belief_upsert on the first sighting of an HQ defender
DUWS_opcom_fobsKnown = [];    // FOB site keys, each added the same way on the first sighting of its garrison

DUWS_opcom_tick = 0;
