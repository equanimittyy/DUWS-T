// Site-finder for the informant hunt: accepts a picker candidate only where a populated civilian town
// sits, and returns that town's centre. The hunt needs a crowd to hide him and the Tomata town-rep
// system for the "ask about informant" roll, so any map/mode without it -- civilians off, RAVAGE, WBK
// -- rejects every candidate, dropping the offer rather than siting on empty ground then aborting
// after the player picked.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only broadcast
// state: duws_town_circles (town centres + radii, published by fnc_civ_init_Tomata) and CIV_PRESENCE.
// Server-only civ_town_rep is read later in the thread, for the friendly/neutral/enemy branch.
//
// Contract: [_candidatePos] -> [] reject, or [_townCentre] accept.
params ["_pos"];

// duws_town_circles is built for RAVAGE/WBK too, but those modes carry no town reputation, so the
// ask/branch would have nothing to read: gate them out the same way the civs-off CP lift does.
if (isNil "CIV_PRESENCE" || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) exitWith { [] };

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

// Snap to the nearest town centre, accept only if within reach of the picker's wanted offer (else a
// candidate in empty country drags the mission across the map). Reject retries, bounded by its cap.
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

// An undiscovered enemy town is a blind trap -- no planning a hunt in a town you don't yet know is
// hostile. So reject only the pair undiscovered AND hostile: a discovered enemy town wears its
// hostility on the map (fair), and an undiscovered friendly/neutral town holds no surprise. Discovery
// = the town icon's global alpha (0 until revealed, painted global-effect so a client reads it).
// Hostility = membership of the broadcast enemy-town list, rep <= -10. Garrison-only hostility can't
// arise undiscovered: climbing out of the OPFOR band takes the interaction that reveals the town.
private _discovered = markerAlpha (format ["civ_icon_%1", _bestIdx]) > 0;
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _hostile = (_enemyTowns findIf { _x distance2D _bestPos < 5 }) >= 0;
if (!_discovered && _hostile) exitWith { [] };

// He flees to enemy ground: no OPFOR-held zone at least 1 km off means nowhere to run (a BLUFOR zone
// or the player's FOB is nonsense), so the offer is dropped. WARCOM_zones_controled_by_OPFOR is
// broadcast for the client picker; every zone starts OPFOR-held, moving to BLUFOR only when captured.
private _enemyZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
if ((_enemyZones findIf { _x distance2D _bestPos >= 1000 }) < 0) exitWith { [] };

[_bestPos]
