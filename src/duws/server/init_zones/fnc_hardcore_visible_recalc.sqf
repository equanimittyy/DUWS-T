// Locality: server. Writes a networked global, so two machines running it would race.
if (!isServer) exitWith {};

// Task forces refuse to launch while nothing OPFOR holds is on the map, so this flag gates every
// assault (fnc_request_squad, fnc_WARCOM_blu_assault). Recomputed whole
// rather than nudged: capture moves it in one direction and reveal in the other, and a delta
// from either side drifts as soon as they interleave.
if (!hardcore_mode_enable) exitWith {};

private _found = false;
{
    private _zonePos = _x;
    // Positions compared through str because zone_namePOS_pairs carries no index to key on.
    if (zone_namePOS_pairs findIf {(str (_x select 1) == str _zonePos) && {_x select 2}} > -1) exitWith {
        _found = true;
    };
} forEach WARCOM_zones_controled_by_OPFOR;

hardcore_visibleZone_found = _found;
publicVariable "hardcore_visibleZone_found";
