// Locality: server -- remoteExec'd to 2 by fnc_debug_opcom_view. Gathers every AoI emitter's reach as
// [center, radius, side] and hands the list straight back to the requesting client to draw, the way
// fnc_map_readout_query answers the board. Server-side because the reaches (the AOI_* constants) and
// the banded-town reputations are server-only; the emitter positions are mostly broadcast, but
// gathering here keeps one reader of the reach model. Read-only and it only draws rings on the caller's
// own map, so it needs no game_master re-gate beyond the client menu's.
if (!isServer) exitWith {};
params ["_requester"];

private _circles = [];

// OPFOR radio towers: AOI_TOWER_REACH from each mast still standing.
{ if ((_x select 2) isEqualTo "RADIO") then { _circles pushBack [_x select 1, AOI_TOWER_REACH, "opfor"] } } forEach DUWS_hardpoints;

// Zones: reach measured from the radius; the side is the controller's, by the same proximity test the
// capture triggers use -- a zone not on the BLUFOR-held list is OPFOR, which is every zone at the start.
{
    _x params ["", "_zp", "_zs"];
    private _side = ["opfor", "blufor"] select ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0);
    _circles pushBack [_zp, _zs + AOI_ZONE_REACH, _side];
} forEach zone_meta_array;

// Player HQ and every FOB, always BLUFOR.
if !(PosOfBLUHQ isEqualTo []) then { _circles pushBack [PosOfBLUHQ, AOI_HQ_REACH, "blufor"] };
{ _circles pushBack [_x, AOI_FOB_REACH, "blufor"] } forEach Array_of_FOBpos;

// Banded towns only -- a neutral town emits nothing, so it draws no ring. The rep's sign is the side:
// >= +10 BLUFOR, <= -10 OPFOR, the same band that flips the town for garrison and income.
private _reps = missionNamespace getVariable ["civ_town_rep", []];
private _locs = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
{
    if (abs _x >= 10) then {
        private _side = ["opfor", "blufor"] select (_x >= 10);
        _circles pushBack [getPos (_locs select _forEachIndex), (_radii select _forEachIndex) + AOI_TOWN_REACH, _side];
    };
} forEach _reps;

// Wrapped: the draw side reads params [["_circles", []]], so the list must arrive as the single
// argument. Sent bare, params would bind _circles to its first triple and the draw would iterate
// that triple's members, reading a coordinate number where it expects a [pos, radius, side] row.
[_circles] remoteExec ["fnc_debug_aoi_draw", _requester];
