// Locality: server -- the zone capture trigger's condition while BLUFOR hold the zone; mirrors fnc_zone_capture_ready.
// No BLUFOR garrison exists yet, so the headcount alone decides. Not `EAST SEIZED`, which cannot fire while one BLUFOR
// stands in the radius: a zone changes hands under a live fight.
if (!isServer) exitWith { false };

params ["_trg"];
private _pos = _trg getVariable ["DUWS_zonePos", []];
if (_pos isEqualTo []) exitWith { false };

(count (list _trg)) > ([_pos, (triggerArea _trg) select 0, WEST] call fnc_side_count_at)
