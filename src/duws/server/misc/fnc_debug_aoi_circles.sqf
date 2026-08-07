// Locality: server -- remoteExec'd to 2 by fnc_debug_opcom_view. Gathers every AoI emitter's reach as
// [center, radius] and hands the list straight back to the requesting client to draw, the way
// fnc_map_readout_query answers the board. Server-side because the reaches (the AOI_* constants) and
// the banded-town reputations are server-only; the emitter positions are mostly broadcast, but
// gathering here keeps one reader of the reach model. Read-only and it only draws rings on the caller's
// own map, so it needs no game_master re-gate beyond the client menu's.
if (!isServer) exitWith {};
params ["_requester"];

private _circles = [];

// OPFOR radio towers: AOI_TOWER_REACH from each mast still standing.
{ if ((_x select 2) isEqualTo "RADIO") then { _circles pushBack [_x select 1, AOI_TOWER_REACH] } } forEach DUWS_hardpoints;

// Zones: reach measured from the radius, whoever holds them.
{ _x params ["", "_zp", "_zs"]; _circles pushBack [_zp, _zs + AOI_ZONE_REACH] } forEach zone_meta_array;

// Player HQ and every FOB.
if !(PosOfBLUHQ isEqualTo []) then { _circles pushBack [PosOfBLUHQ, AOI_HQ_REACH] };
{ _circles pushBack [_x, AOI_FOB_REACH] } forEach Array_of_FOBpos;

// Banded towns only -- a neutral town emits nothing, so it draws no ring.
private _reps = missionNamespace getVariable ["civ_town_rep", []];
private _locs = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
{
    if (abs _x >= 10) then {
        _circles pushBack [getPos (_locs select _forEachIndex), (_radii select _forEachIndex) + AOI_TOWN_REACH];
    };
} forEach _reps;

_circles remoteExec ["fnc_debug_aoi_draw", _requester];
