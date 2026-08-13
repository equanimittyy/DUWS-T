// Locality: server -- called from the zone capture trigger's condition, which is created
// server-local for exactly this reason: the garrison peak below is a server-side global, and a
// client evaluating this would read nil and answer for a zone whose state it cannot see.
// usage: [thisTrigger] call fnc_zone_capture_ready
//
// Replaces `WEST SEIZED` on the BLUFOR-takes-it direction. SEIZED demands the whole trigger area be
// empty of OPFOR, which made a capture a sweep of every last patrol out to the zone radius; this
// asks the two questions that actually describe taking ground -- is the garrison beaten, and does
// BLUFOR outnumber what is still standing on the ground.
//
// The OPFOR-takes-it-back direction still uses `EAST SEIZED`. There is no BLUFOR garrison figure to
// judge a retake against, and OPFOR retakes are driven by WARCOM assault waves rather than by a
// force being ground down.

if (!isServer) exitWith { false };

params ["_trg"];
private _pos = _trg getVariable ["DUWS_zonePos", []];
private _key = _trg getVariable ["DUWS_zoneKey", ""];
if (_pos isEqualTo [] || {_key == ""}) exitWith { false };

// Not live means the zone is stowed, mid-spawn, or not OPFOR's. Refusing here stops a player walking
// onto empty ground and taking it before its garrison has been placed -- and it only holds while every
// teardown discharges fnc_zone_garrison_dropped, which is where that contract is stated.
if !([_key] call DUWS_fnc_garrisonHeld) exitWith { false };

// The garrison beaten: this zone's own roster men -- wherever they are standing, a wandered patrol still
// counts, a neighbour's garrison never does -- plus the men its reserve pool still owes, worn to a tenth
// of the zone's full fighting potential (DUWS_fnc_garrisonBeaten). The owed reserves hold the zone above
// the line until the waves have spawned and been beaten, so it cannot fall on an empty perimeter; at
// multiplier 1 the pool is empty and this is the garrison alone, the one break line across the campaign.
if !([_key] call DUWS_fnc_garrisonBeaten) exitWith { false };

// Who holds the ground, over the trigger's own area so both sides are counted across the same
// circle. Deliberately unkeyed, unlike the test above: anyone standing here counts for their side
// whoever spawned them, so a side mission's guards defend the zone and a passing patrol contests it.
//
// `list` is the engine's own record of what activates this trigger, which is WEST PRESENT -- the
// same set the `this` beside this call is true for, so the two cannot disagree about who is here.
private _radius = (triggerArea _trg) select 0;
(count (list _trg)) > ([_pos, _radius] call fnc_opfor_count_at)
