// Locality: server. -> [] unless BLUFOR hold the zone, else [contested, can reinforce, can fortify]. The query
// and the buy both read it, so a button never offers what the buy would refuse.
if (!isServer) exitWith { [] };

params [["_ref", []]];
_ref params [["_kind", ""], ["_id", []]];
// The ref arrives from a client button, so anything but a zone fails closed.
if (_kind isNotEqualTo "ZONE") exitWith { [] };

private _key = [_id] call fnc_zone_key;
if (([_key] call DUWS_fnc_garrisonSideOf) isNotEqualTo "BLU") exitWith { [] };

[
	[_key] call DUWS_fnc_opcom_siteContested,
	([_key] call DUWS_fnc_garrisonStrength) < 1 && {([_key] call DUWS_fnc_garrisonReinforceCount) > 0},
	([_key] call fnc_zone_tier) < count DUWS_zoneSpawnTiersBlu
]
