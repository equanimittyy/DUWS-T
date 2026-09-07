// Locality: server. OPCOM's belief store: the parallel arrays the commander plans against instead of
// live player state, plus the strategic-tick clock decay ages stamps against. Handle-free and never
// broadcast -- the mission namespace is the save file, and no client reads belief.
if (!isServer) exitWith {};

DUWS_opcom_belief_key  = [];   // subject: a BLUFOR group netId, a zone index, a FOB index, "HQ"
DUWS_opcom_belief_pos  = [];   // [x,y,0] as last observed, never a live lookup (the sense edge gate enforces it)
DUWS_opcom_belief_time = [];   // DUWS_opcom_tick at the observation
DUWS_opcom_belief_str  = [];   // believed BLUFOR force there

// Transient (not stored): prior tick's `east knowsAbout` per group netId, so the sweep tells an acquisition
// (rising/steady) from the fading tail (falling). Rebuilt on loop start; a mid-tail load costs one harmless tick.
DUWS_opcom_ka_prev = createHashMap;

DUWS_opcom_tick = 0;
