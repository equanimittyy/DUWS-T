// Shared offer-time cluster finder: snaps a dot to the nearest building cluster and returns a real building, so
// a "map" dot on open ground still sites on something a garrison or squad can hold.
//
// Runs client-side in the picker, so broadcast state and pure engine queries only -- never the server-only
// fnc_usableBuildings or token vocabulary. That vocabulary being server-only is why the seat floor is a fixed
// count the caller passes, not the mission's live squad size.
//
// Contract: [_pos, _minBuildings, _minSeatSlots, _townPolicy, _zoneStandoff] -> [] reject, or [_buildingPos].
//   _townPolicy "reject-all" | "allow-neutral" (only side-held towns rejected); _zoneStandoff 0 disables.
params ["_pos", "_minBuildings", "_minSeatSlots", "_townPolicy", "_zoneStandoff"];

// ACCEPT_RADIUS stays under the adopting threads' building search, so the vetted building is one they re-derive to.
#define SNAP_RADIUS   1500
#define ACCEPT_RADIUS 350

private _zones = missionNamespace getVariable ["zone_meta_array", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];
private _held = [];
if (_townPolicy isEqualTo "allow-neutral") then {
    _held = (missionNamespace getVariable ["DUWS_enemy_town_pos", []]) + (missionNamespace getVariable ["DUWS_blufor_town_pos", []]);
};

// Nearest-first; isNull guard takes the nearest match (not an exitWith in the then, which could fire for the
// then only and let a farther cluster overwrite a nearer one).
private _locs = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], SNAP_RADIUS];
private _seat = objNull;
{
    if (isNull _seat) then {
        private _c = locationPosition _x;
        private _blocked = switch (_townPolicy) do {
            case "allow-neutral": { (_circles findIf { _x params ["_tc", "_r"]; (_c distance2D _tc < _r) && {(_held findIf { _x distance2D _tc < 5 }) >= 0} }) >= 0 };
            default { (_circles findIf { _x params ["_tc", "_r"]; _c distance2D _tc < _r }) >= 0 };
        };
        if (!_blocked) then {
            private _usable = (nearestTerrainObjects [_c, ["House"], ACCEPT_RADIUS, true]) select { !(((_x buildingPos 3) select 0) == 0) };
            if (count _usable >= _minBuildings) then {
                private _si = _usable findIf {
                    private _bp = getPos _x;
                    (count (_x buildingPos -1) >= _minSeatSlots)
                        && { _zoneStandoff <= 0 || {(_zones findIf { _x params ["", "_zp", "_zs"]; (_bp distance2D _zp) < (_zs + _zoneStandoff) }) < 0} }
                };
                if (_si >= 0) then { _seat = _usable select _si };
            };
        };
    };
} forEach _locs;

if (isNull _seat) exitWith { [] };
[getPos _seat]
