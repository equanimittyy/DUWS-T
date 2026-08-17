// Site-finder for the informant hunt: accepts a picker candidate only where a
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
private _bestIdx = -1;
private _bestD = 1e9;
{
    _x params ["_c", ""];
    private _d = _c distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _bestPos = _c; _bestIdx = _forEachIndex };
} forEach _circles;

if (_bestPos isEqualTo [] || {_bestD > _ACCEPT_RADIUS}) exitWith { [] };

// An enemy town the player has not found yet is a blind trap -- there is no planning a hunt in a
// town you do not yet know is hostile. So reject only the pair undiscovered AND hostile: a
// discovered enemy town wears its hostility on the map and is a fair offer, and an undiscovered
// friendly/neutral town holds no nasty surprise. Discovery is the town icon's global alpha (0
// until revealed, painted with a global-effect command so a client reads it). Hostility is
// membership of the broadcast enemy-town list the reputation band keeps current -- rep <= -10.
// Garrison-only hostility (a garrison standing while rep sits above the band) cannot arise on an
// undiscovered town: climbing a town out of the OPFOR band takes the interaction that reveals it,
// so on ground the player has never seen, enemy reputation is the whole of hostile.
private _discovered = markerAlpha (format ["civ_icon_%1", _bestIdx]) > 0;
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _hostile = (_enemyTowns findIf { _x distance2D _bestPos < 5 }) >= 0;
if (!_discovered && _hostile) exitWith { [] };

// The informant flees to enemy ground: with no OPFOR-held zone at least 1 km off there is nowhere for
// him to run (fleeing to a BLUFOR zone or the player's own FOB is nonsense), so the offer is dropped
// rather than sited here. WARCOM_zones_controled_by_OPFOR is broadcast, so the client picker can see
// it; every zone starts OPFOR-held and moves to the BLUFOR list only when captured.
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
if ((_enemyZones findIf { _x distance2D _bestPos >= 1000 }) < 0) exitWith { [] };

[_bestPos]
