// Site-finder for the HVT convoy hunt. Runs client-side inside the offer picker
// (client/missions/fnc_stratmap.sqf), so it reads only broadcast state.
//
// The picker hands a candidate near a chosen OPFOR zone; this ejects the convoy SPAWN 5-10 km out into
// open ground and returns THAT as the offer/spawn point. So the map icon the player clicks is where the
// columns start, and the haven they flee to (fnc_hvt_dest_pick, from the ejected spawn) is a real zone
// the far side of the run. Ejecting the spawn -- rather than requiring two OPFOR zones 5 km apart -- is
// what lets the mission offer on tight, cluster-zoned maps: open ground 5-10 km from a zone is abundant
// where a second distant zone is not, and a clustered map ejected out from becomes 5-10 km from the whole
// cluster.
//
// Tries bearings at the far distance first and pulls back 500 m at a time to the 5 km floor -- a capped
// number of bearings per distance -- taking the first ejection that lands on drivable ground (snapped to a
// road, off water) with a clean haven reachable from it. None inside the floor -> [], and the picker drops
// this candidate and draws another zone.
//
// Contract: [_candidatePos] -> [_spawnPos] | [].
params ["_pos"];

// TUNABLE. Eject band the spawn is thrown into, the pull-back step, the bearing rolls tried at each
// distance before pulling back, and the road-snap reach. Kept in step with the 5-10 km band fnc_hvt_dest_pick
// picks the haven from.
#define EJECT_MAX      10000
#define EJECT_MIN      5000
#define EJECT_STEP     500
#define TRIES_PER_DIST 8
#define ROAD_SNAP      400

private _out = [];
private _dist = EJECT_MAX;
while { _out isEqualTo [] && {_dist >= EJECT_MIN} } do {
    private _t = 0;
    while { _out isEqualTo [] && {_t < TRIES_PER_DIST} } do {
        _t = _t + 1;
        private _p = _pos getPos [_dist, random 360];
        if (!(surfaceIsWater _p)) then {
            private _roads = _p nearRoads ROAD_SNAP;
            if !(_roads isEqualTo []) then {
                private _sp = getPosATL (_roads select 0);
                if (!(surfaceIsWater _sp) && {!(([_sp] call fnc_hvt_dest_pick) isEqualTo [])}) then {
                    _out = [_sp];
                };
            };
        };
    };
    _dist = _dist - EJECT_STEP;
};
_out
