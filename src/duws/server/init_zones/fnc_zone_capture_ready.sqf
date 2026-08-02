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

// The fraction below which a garrison is finished. One number for it across the campaign, so a
// player learns it once.
#define BREAK_FRACTION 0.2

params ["_trg"];
private _pos = _trg getVariable ["DUWS_zonePos", []];
private _key = _trg getVariable ["DUWS_zoneKey", ""];
if (_pos isEqualTo [] || {_key == ""}) exitWith { false };

private _peak = missionNamespace getVariable [format ["DUWS_zonePeak_%1", _key], 0];

// No peak means the zone is stowed, mid-spawn, or not OPFOR's. Refusing here is what stops a player
// walking onto empty ground and taking it before its garrison has been placed -- and it only holds
// while every teardown discharges fnc_zone_garrison_dropped, which is where that contract is stated.
if (_peak <= 0) exitWith { false };

// This zone's own garrison, by roster and wherever it is standing -- not by proximity. A side
// mission's guards, or a neighbouring town's garrison, are not this zone's and cannot restore it;
// a patrol that has wandered past the ring is still the zone's and still has to be dealt with.
if (([_key] call fnc_zone_garrison_count) > BREAK_FRACTION * _peak) exitWith { false };

// Who holds the ground, over the trigger's own area so both sides are counted across the same
// circle. Deliberately unkeyed, unlike the test above: anyone standing here counts for their side
// whoever spawned them, so a side mission's guards defend the zone and a passing patrol contests it.
//
// `list` is the engine's own record of what activates this trigger, which is WEST PRESENT -- the
// same set the `this` beside this call is true for, so the two cannot disagree about who is here.
private _radius = (triggerArea _trg) select 0;
(count (list _trg)) > ([_pos, _radius] call fnc_opfor_count_at)
