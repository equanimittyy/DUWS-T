// Locality: server. Single writer for the belief store's four parallel rows (key/pos/time/str): insert a
// new subject or refresh an existing one in place, stamped at the current tick. Keying by subject here is
// what keeps the four arrays index-aligned -- every sensor writes through this, so none can push one row
// and forget another.

params ["_key", "_pos", "_str"];

private _i = DUWS_opcom_belief_key findIf { _x isEqualTo _key };
if (_i < 0) then {
    DUWS_opcom_belief_key  pushBack _key;
    DUWS_opcom_belief_pos  pushBack _pos;
    DUWS_opcom_belief_time pushBack DUWS_opcom_tick;
    DUWS_opcom_belief_str  pushBack _str;
} else {
    DUWS_opcom_belief_pos  set [_i, _pos];
    DUWS_opcom_belief_time set [_i, DUWS_opcom_tick];
    DUWS_opcom_belief_str  set [_i, _str];
};

// A sighting is also an observation, so refresh coverage at the sighted cell -- else seeing a threat leaves
// the ground reading unobserved, a contradiction the router would re-scout into. Point stamp (k 0): proves
// this one cell was looked at, not that the sector around a known enemy is clear (the recon/OP sweep's bubble).
[_pos, 0] call fnc_opcom_cover_stamp;

[_pos, _str] call DUWS_fnc_opcom_trafficStamp;

// Until BLUFOR is seen near it the HQ pulls no defense toward itself, so the opening campaign defends evenly
// instead of massing on a base the commander has no business knowing. One-way: a base found once stays found.
if (!DUWS_opcom_hqKnown && {!isNil "PosOfBLUHQ"} && {PosOfBLUHQ isNotEqualTo []} && {(_pos distance2D PosOfBLUHQ) < OPCOM_GRID_CELL * 2}) then {
    DUWS_opcom_hqKnown = true;
    ["INFO", "OPCOM", "player HQ revealed by a sighting near it"] call fnc_log;
};
