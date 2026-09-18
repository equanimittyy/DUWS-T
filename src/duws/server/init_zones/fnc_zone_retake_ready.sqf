// Locality: server -- the zone capture trigger's condition while BLUFOR hold the zone; mirrors fnc_zone_capture_ready.
// No BLUFOR garrison exists yet, so the headcount over the streaming ring alone decides. Survivors of the garrison
// BLUFOR beat count here: they fight on where they stood (DUWS_fnc_garrisonRelease).
if (!isServer) exitWith { false };

params ["_trg"];
private _key = _trg getVariable ["DUWS_zoneKey", ""];
if (_key == "") exitWith { false };

[_key, "zone", EAST, WEST] call DUWS_fnc_siteOutnumbers
