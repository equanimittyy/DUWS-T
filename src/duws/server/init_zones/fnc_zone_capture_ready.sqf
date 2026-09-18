// Locality: server -- called from the zone capture trigger's condition, which is created
// server-local for exactly this reason: the garrison ledger below is server-side, and a
// client evaluating this would read nil and answer for a zone whose state it cannot see.
// usage: [thisTrigger] call fnc_zone_capture_ready
//
// The two conditions of taking ground, held for DUWS_captureHold by the trigger's timeout: the garrison
// beaten, and BLUFOR outnumbering OPFOR over the streaming ring. The retake direction is fnc_zone_retake_ready.

if (!isServer) exitWith { false };

params ["_trg"];
private _key = _trg getVariable ["DUWS_zoneKey", ""];
if (_key == "") exitWith { false };

// Not live means the zone is stowed, mid-spawn, or not OPFOR's. Refusing here stops a player walking
// onto empty ground and taking it before its garrison has been placed -- and it only holds while every
// teardown discharges fnc_zone_garrison_dropped, which is where that contract is stated. Also the cheap
// gate: the trigger has no activation, so this runs on every zone whether or not anyone is near.
if !([_key] call DUWS_fnc_garrisonHeld) exitWith { false };

// This zone's own groups -- wherever they stand, a wandered patrol still counts, a neighbour's garrison never
// does -- plus the tokens its pool still owes (DUWS_fnc_garrisonBeaten). The owed reserves hold the zone
// above the line until the waves have spawned and been beaten, so it cannot fall on an empty perimeter.
if !([_key] call DUWS_fnc_garrisonBeaten) exitWith { false };

// Deliberately unkeyed, unlike the test above: anyone standing in the ring counts for their side whoever
// spawned them, so a side mission's guards defend the zone and a passing patrol contests it.
[_key, "zone", WEST, EAST] call DUWS_fnc_siteOutnumbers
