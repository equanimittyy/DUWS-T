// Site-finder for the HVT convoy hunt. Client-side in the offer picker
// (client/missions/fnc_stratmap.sqf), so it reads only broadcast state.
//
// The picker hands a candidate near an OPFOR zone; this ejects the convoy SPAWN 3-10 km out into open
// ground and returns THAT as the offer/spawn point -- so the map icon is the column start, and the haven
// they flee to (fnc_hvt_dest_pick, from the ejected spawn) is a real zone the far side of the run. Ejecting
// the spawn rather than requiring two OPFOR zones 3 km apart lets the mission offer on tight, cluster-zoned
// maps: open ground 3-10 km out is abundant where a second distant zone is not, and a clustered map ejected
// out from becomes 3-10 km from the whole cluster.
//
// Far distance first, pulling back 500 m to the 3 km floor with a capped bearing count per distance, taking
// the first ejection on drivable ground (road-snapped, off water) with a clean haven reachable. None inside
// the floor -> [], and the picker draws another zone.
//
// Contract: [_candidatePos] -> [_spawnPos] | [].
params ["_pos"];

// TUNABLE. Eject band, pull-back step, bearing rolls per distance, road-snap reach. Kept in step with the
// 3-10 km band fnc_hvt_dest_pick picks the haven from.
#define EJECT_MAX      10000
#define EJECT_MIN      3000
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
