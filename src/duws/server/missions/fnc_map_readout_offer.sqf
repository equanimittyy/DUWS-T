// Locality: server. -> [] unless BLUFOR hold the site, else [contested, can reinforce, can fortify]. The query
// and the buy both read it, so a button never offers what the buy would refuse.
if (!isServer) exitWith { [] };

params [["_ref", []]];
_ref params [["_kind", ""], ["_id", -1]];

private _isZone = _kind isEqualTo "ZONE";
private _key = if (_isZone) then { [_id] call fnc_zone_key } else { [_id] call fnc_town_site_key };
if (([_key] call DUWS_fnc_garrisonSideOf) isNotEqualTo "BLU") exitWith { [] };

private _tier = if (_isZone) then { [_key] call fnc_zone_tier } else { [_id] call fnc_town_garrison_tierAt };
private _top = count ([DUWS_townSpawnTiersBlu, DUWS_zoneSpawnTiersBlu] select _isZone);

[
	// Nil until OPCOM's loop starts, a few seconds after WARCOM init.
	!isNil "DUWS_opcom_contested" && {[_key] call DUWS_fnc_opcom_siteContested},
	([_key] call DUWS_fnc_garrisonStrength) < 1 && {([_key] call DUWS_fnc_garrisonReinforceCount) > 0},
	_tier < _top
]
