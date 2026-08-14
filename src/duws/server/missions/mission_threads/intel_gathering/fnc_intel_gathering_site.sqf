// Site-finder for the intel mission (informant hunt): accepts a picker candidate only where a
// populated civilian town sits, and returns that town's centre. The hunt needs a crowd to hide the
// informant in and the Tomata town-reputation system for the "ask about informant" roll, so any map
// or mode without it -- civilians off, RAVAGE, WBK -- rejects every candidate and the offer is
// dropped rather than sited on empty ground (the old failure: sited anywhere, then aborted after the
// player picked).
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only broadcast
// state: duws_town_circles (town centres + radii, published by fnc_civ_init_Tomata for exactly this)
// and CIV_PRESENCE. The server-only civ_town_rep is read later in the thread, for the
// friendly/neutral/enemy branch.
//
// Contract: [_candidatePos] -> [] reject, or [_townCentre] accept.
params ["_pos"];

// duws_town_circles is built for RAVAGE/WBK too, but those modes carry no town reputation, so the
// ask/branch would have nothing to read: gate them out the same way the civs-off CP lift does.
if (isNil "CIV_PRESENCE" || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) exitWith { [] };

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

// Snap to the nearest town centre and accept only if one sits within reach of where the picker
// wanted the offer, so a candidate deep in empty country does not drag the mission across the map.
// A reject sends the picker back for another candidate, bounded by its own retry cap.
private _ACCEPT_RADIUS = 2500;
private _bestPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    private _d = _c distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _bestPos = _c };
} forEach _circles;

if (_bestPos isEqualTo [] || {_bestD > _ACCEPT_RADIUS}) exitWith { [] };
[_bestPos]
