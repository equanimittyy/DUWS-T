// Locality: any machine -- server-compiled and broadcast. Reads only broadcast globals, so a client
// (the MHQ deploy action, the FOB request) gets the same answer the server would.
//
// True when _pos is within _radius metres (2D) of any OPFOR-held zone or any town in the OPFOR band.
// Zones come from WARCOM_zones_controled_by_OPFOR; the town centres from DUWS_enemy_town_pos, which the
// server rebuilds from civ_town_rep on every band crossing -- civ_town_rep itself is not broadcast, so
// the derived positions are what reaches a client.
fnc_pos_near_enemy = {
    params ["_pos", ["_radius", 1000]];
    private _zones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    if (_zones findIf { _pos distance2D _x < _radius } >= 0) exitWith { true };
    private _towns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
    _towns findIf { _pos distance2D _x < _radius } >= 0
};
