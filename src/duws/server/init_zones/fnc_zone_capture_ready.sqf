// Locality: server -- called from the zone capture trigger's condition, which is created
// server-local for exactly this reason: the garrison peak below is a server-side global, and a
// client evaluating this would read nil and answer for a zone whose state it cannot see.
// usage: [thisTrigger] call fnc_zone_capture_ready
//
// Replaces `WEST SEIZED` on the BLUFOR-takes-it direction. SEIZED demands the whole trigger area be
// empty of OPFOR, which made a capture a sweep of every last patrol out to the zone radius; this
// asks the two questions that actually describe taking ground -- is the garrison beaten, and does
// the player hold the objective itself.
//
// The OPFOR-takes-it-back direction still uses `EAST SEIZED`. There is no BLUFOR garrison figure to
// judge a retake against, and OPFOR retakes are driven by WARCOM assault waves rather than by a
// force being ground down.

if (!isServer) exitWith { false };

// The same fraction the town garrison breaks at. One number for "this force is finished" across the
// campaign, so a player learns it once.
#define BREAK_FRACTION 0.2

// The composition itself. Capture means standing on the objective, not thinning its defenders from
// a ridge a kilometre away -- this is the clause that keeps a zone something you enter.
#define CENTRE_RADIUS 50

params ["_trg"];
private _pos = _trg getVariable ["DUWS_zonePos", []];
private _key = _trg getVariable ["DUWS_zoneKey", ""];
if (_pos isEqualTo [] || {_key == ""}) exitWith { false };

private _peak = missionNamespace getVariable [format ["DUWS_zonePeak_%1", _key], 0];

// No peak means the zone is stowed, mid-spawn, or not OPFOR's. Refusing here is what stops a player
// walking onto empty ground and taking it before its garrison has been placed -- and it only holds
// while every teardown discharges fnc_zone_garrison_dropped, which is where that contract is stated.
if (_peak <= 0) exitWith { false };

// This zone's own garrison, by roster and wherever it is standing -- not by proximity. A WARCOM
// reinforcement wave is not this zone's garrison and cannot restore it, and a patrol that has
// wandered past the ring is still the zone's and still has to be dealt with.
if (([_key] call fnc_zone_garrison_count) > BREAK_FRACTION * _peak) exitWith { false };

// Deliberately unkeyed, unlike the test above. This one asks whether the objective is physically
// held, and anyone standing on it denies it whoever spawned them. Withdrawing units are excluded by
// fnc_opfor_count_at itself, so a retreat bounding through the centre cannot stall a capture.
([_pos, CENTRE_RADIUS] call fnc_opfor_count_at) == 0
