// Shared site-finder for the civilian delivery pair -- Escort Informant and Deliver Supplies. Both hand
// their cargo to a non-enemy town and move that town's reputation on the outcome, and each thread picks
// the nearest non-enemy town to its offer position. So the offer must sit on that same town: this snaps
// the picker's candidate to the nearest non-enemy town centre, guaranteeing the offer's search circle and
// the town the thread delivers to are one and the same, never a circle on one town while the cargo routes
// to another.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it reads only broadcast state:
// duws_town_circles (town centres + radii, from fnc_civ_init_Tomata) and DUWS_enemy_town_pos (OPFOR-band
// town centres, from fnc_enemy_towns_refresh). Civilians off leaves the circles empty and rejects every
// candidate. RAVAGE/WBK carry towns but no reputation, so there the rep move is a harmless no-op.
//
// Registered as both fnc_escort_informant_site and fnc_deliver_supplies_site in server_fnc_init.
//
// Contract: [_candidatePos] -> [] reject, or [_townCentre] accept.
params ["_pos"];

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

// Accept only within reach of the wanted offer, else a candidate whose only non-enemy town lies across the
// map drags the delivery there. Enemy towns (rep <= -10, in the broadcast list) are skipped, matching the
// thread's own pick.
private _ACCEPT_RADIUS = 2500;
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _bestPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    if ((_enemyTowns findIf { _x distance2D _c < 5 }) < 0) then {
        private _d = _c distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _bestPos = _c };
    };
} forEach _circles;

if (_bestPos isEqualTo [] || {_bestD > _ACCEPT_RADIUS}) exitWith { [] };
[_bestPos]
