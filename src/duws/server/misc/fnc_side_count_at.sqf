// Locality: server -- one side's men physically standing on a piece of ground, whoever spawned them.
// Deliberately owner-blind, unlike a site's roster: this answers "is this ground held",
// which anyone standing on it denies whether they are the local garrison, a side mission's guards,
// or a patrol passing through.
//
// Crew are unpacked because a CAManBase-only query does not report anyone riding in something,
// which would let an APC parked on an objective read as nobody there. Static weapons come back
// through the same query, so a manned emplacement counts as the defender it is.
//
if (!isServer) exitWith { 0 };

params ["_pos", "_radius", "_side"];

private _n = 0;
{
    private _members = if (_x isKindOf "CAManBase") then { [_x] } else { crew _x };
    {
        if (alive _x && {side _x == _side}) then {
            _n = _n + 1;
        };
    } forEach _members;
} forEach (_pos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius]);
_n
