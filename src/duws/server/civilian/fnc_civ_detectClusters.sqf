// Locality: server -- called by fnc_civ_selectTowns in Dynamic town generation.
if (!isServer) exitWith {[]};

params ["_anchors", "_reach", "_minBuildings", "_mapTowns"];

private _GRID = 800;
private _CLUSTER_RADIUS = 100;
private _TOWN_CLEARANCE = 200;
// Tested against the anchors, the HQ and zone centres: a cluster in a zone would open on OPFOR's books.
private _MILITARY_CLEARANCE = 800;
private _MAX_CLUSTERS = 100;

private _townCentres = _mapTowns apply { getPos _x };
private _points = [];
for "_gx" from 0 to worldSize step _GRID do {
    for "_gy" from 0 to worldSize step _GRID do {
        private _pos = [_gx, _gy, 0];
        if (!surfaceIsWater _pos
            && {(_anchors findIf { _pos distance2D _x <= _reach }) >= 0}
            && {(_anchors findIf { _pos distance2D _x < _MILITARY_CLEARANCE }) < 0}
            && {(_townCentres findIf { _pos distance2D _x < _TOWN_CLEARANCE }) < 0}) then {
            _points pushBack _pos;
        };
    };
};
// Shuffled so that, once the cap binds, the clusters a campaign gets are not always the south-west ones.
_points = _points call BIS_fnc_arrayShuffle;

private _clusters = [];
private _total = count _points;
private _lastPing = 0;
{
    if (count _clusters >= _MAX_CLUSTERS) exitWith {};
    private _count = count ([_x, 2, _CLUSTER_RADIUS] call fnc_usableBuildings);
    if (_count >= _minBuildings) then {
        private _loc = createLocation ["NameVillage", _x, 0, 0];
        _loc setVariable ["DUWS_cluster", true];
        // The 350 m survey a map town and a restored town carry, so registration trims the same list in all three.
        _clusters pushBack [_loc, _count, false, [_x, 2, 350] call fnc_usableBuildings];
    };

    if (diag_tickTime - _lastPing > 1.5) then {
        _lastPing = diag_tickTime;
        [format ["Placing civilians...<br/>surveying building clusters  %1%2  (%3 of %4 sites)",
            round (100 * _forEachIndex / (1 max _total)), "%", _forEachIndex, _total]]
            remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    };
} forEach _points;

_clusters
