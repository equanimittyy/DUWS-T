// Offer filter for the rescue-squad mission: snaps the candidate onto the nearest building cluster (village or
// hamlet, never a registered town) that holds a building big enough to seat the whole squad. The thread aborts
// if it cannot seat the squad, so vetting the cluster at offer time makes that a clean no-offer, not a launch
// abort. Client-side in the picker, so it reads only broadcast state (nearestLocations, zone_meta_array,
// duws_town_circles). The thread re-derives the exact building within its search radius from this position.
//
// Contract: [_candidatePos] -> [] reject, or [_snappedPos] accept.
params ["_pos"];

// ACCEPT_RADIUS stays under the thread's 400 m building search so the vetted seat is one it can reach.
// SEAT_SLOTS clears the recon token's fixed 5-man roster (a mod swaps classes, not the count) with a slot to
// spare -- the picker can't read that count live (server-only), and over-rejecting a hamlet beats a launch abort.
#define SNAP_RADIUS   1500
#define ACCEPT_RADIUS 350
#define MIN_BUILDINGS 3
#define SEAT_SLOTS    6
#define ZONE_STANDOFF 150

private _zones = missionNamespace getVariable ["zone_meta_array", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];

// nearestLocations is nearest-first; the isNull guard keeps the nearest qualifying cluster.
private _locs = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], SNAP_RADIUS];
private _seat = objNull;
{
    if (isNull _seat) then {
        private _c = locationPosition _x;
        // No towns: skip a settlement inside any registered town circle (hamlets pass).
        if ((_circles findIf { _x params ["_tc", "_r"]; _c distance2D _tc < _r }) < 0) then {
            private _usable = (nearestTerrainObjects [_c, ["House"], ACCEPT_RADIUS, true]) select { !(((_x buildingPos 3) select 0) == 0) };
            if (count _usable >= MIN_BUILDINGS) then {
                // One seat that clears the capturable-zone standoff.
                private _si = _usable findIf {
                    private _bp = getPos _x;
                    !(((_x buildingPos SEAT_SLOTS) select 0) == 0)
                        && { (_zones findIf { _x params ["", "_zp", "_zs"]; (_bp distance2D _zp) < (_zs + ZONE_STANDOFF) }) < 0 }
                };
                if (_si >= 0) then { _seat = _usable select _si };
            };
        };
    };
} forEach _locs;

if (isNull _seat) exitWith { [] };
[getPos _seat]
