// Site-finder for the HVT convoy hunt. Client-side in the offer picker
// (client/missions/fnc_stratmap.sqf), so it reads only broadcast state.
//
// Anchors on the nearest DISCOVERED (revealed) OPFOR-held zone to the picker's candidate -- intel names a
// known base the HVT is leaving, the same discovered gate the informant hunt uses -- then ejects the convoy
// SPAWN 3-10 km out from that zone into open ground and returns THAT as the offer/spawn point. So the map
// icon is the column start, and the haven they flee to (fnc_hvt_dest_pick, from the ejected spawn) is a real
// zone the far side of the run. Ejecting rather than requiring two OPFOR zones 3 km apart lets the mission
// offer on tight, cluster-zoned maps: open ground 3-10 km out is abundant where a second distant zone is not.
//
// Far distance first, pulling back 500 m to the 3 km floor with a capped bearing count per distance, taking
// the first ejection on drivable ground (road-snapped, off water) with a clean haven reachable. No discovered
// held zone, or no clean ejection inside the floor -> [], and the picker draws another type.
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

// Nearest discovered held zone as the ejection anchor. zone_namePOS_pairs rows are [name, pos, revealed];
// held = an OPFOR-controlled centre. None -> no known base to leave from, drop the offer.
private _pairs = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _anchor = [];
private _bestD = 1e10;
{
    _x params ["", "_zp", "_revealed"];
    if (_revealed && {(_enemyZones findIf { _x distance2D _zp < 50 }) >= 0}) then {
        private _d = _zp distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _anchor = _zp };
    };
} forEach _pairs;
if (_anchor isEqualTo []) exitWith { [] };

private _out = [];
private _dist = EJECT_MAX;
while { _out isEqualTo [] && {_dist >= EJECT_MIN} } do {
    private _t = 0;
    while { _out isEqualTo [] && {_t < TRIES_PER_DIST} } do {
        _t = _t + 1;
        private _p = _anchor getPos [_dist, random 360];
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
