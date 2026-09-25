// Locality: server, spawned once at boot. The road network as plain arrays, so fnc_convoy_path's A* never asks the
// engine for a position or a neighbour mid-search: node i sits at DUWS_convoy_roadPos select i (ATL) and links to the
// indices in DUWS_convoy_roadNbr select i. DUWS_convoy_roadIdx maps a road's key to its node. The key is the segment
// centre rounded to the metre as an [x, y] pair, because a road object is no hashmap key and one packed number cannot
// hold two ~30 km coords without rounding distinct segments together. DUWS_convoy_roadNbr is written last, so it is
// also the ready flag.

#define CG_BRIDGE 15   // at a sparsely connected road, roads within this many metres join as neighbours: this hops the
                       // dropped junction links and isolated stub ends that would otherwise split the network and send
                       // a whole leg off-road across open field. The edge costs its real gap length, so A* stays optimal.

private _t0 = diag_tickTime;
private _pos = [];
private _nbr = [];
private _idx = createHashMap;
private _roads = [];
private _intern = {
    params ["_r"];
    private _p = getPosATL _r;
    private _k = [round (_p select 0), round (_p select 1)];
    private _j = _idx getOrDefault [_k, -1];
    if (_j < 0) then {
        _j = count _pos;
        _idx set [_k, _j];
        _pos pushBack _p;
        _roads pushBack _r;
    };
    _j
};
{ [_x] call _intern } forEach ([worldSize / 2, worldSize / 2] nearRoads worldSize);

// Interning a neighbour can grow _roads, so the loop runs to the live count.
private _i = 0;
while {_i < count _roads} do {
    private _r = _roads select _i;
    private _n = roadsConnectedTo _r;
    if (count _n < 2) then {
        { if (_x != _r && {!(_x in _n)}) then { _n pushBack _x } } forEach ((_pos select _i) nearRoads CG_BRIDGE);
    };
    _nbr set [_i, _n apply { [_x] call _intern }];
    _i = _i + 1;
};

["INFO", "BOOT", format ["road graph: %1 roads in %2 ms", count _pos, round ((diag_tickTime - _t0) * 1000)]] call fnc_log;
DUWS_convoy_roadPos = _pos;
DUWS_convoy_roadIdx = _idx;
DUWS_convoy_roadNbr = _nbr;
