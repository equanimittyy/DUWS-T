// Locality: server -- OPFOR physically standing on a piece of ground, whoever spawned them.
// usage: [_pos, _radius] call fnc_opfor_count_at
//
// Deliberately owner-blind, unlike fnc_zone_garrison_count: this answers "is this ground held",
// which anyone standing on it denies whether they are the local garrison, a side mission's guards,
// or a patrol passing through.
//
// Crew are unpacked because a CAManBase-only query does not report anyone riding in something,
// which would let an APC parked on an objective read as nobody there. Static weapons come back
// through the same query, so a manned emplacement counts as the defender it is.
//
// Units already ordered out never count. A withdrawal is not a defence, and leaving them in would
// let a retreat bounding across an objective stall a capture indefinitely.

if (!isServer) exitWith { 0 };

params ["_pos", ["_radius", 100]];

private _n = 0;
{
    private _members = if (_x isKindOf "CAManBase") then { [_x] } else { crew _x };
    {
        if (alive _x && {side _x == EAST} && {!(_x getVariable ["DUWS_retreating", false])}) then {
            _n = _n + 1;
        };
    } forEach _members;
} forEach (_pos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius]);
_n
