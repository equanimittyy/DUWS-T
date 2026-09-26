// Locality: every machine, from fnc_sitrep_support. Broadcast values only, so every player reads the same summary.
if (!hasInterface) exitWith {};
sleep 1;

private _lines = [
	format [localize "STR_DUWS_T_SITREP_TITLE", [date] call DUWS_fnc_campaignDay], "",
	format [localize "STR_DUWS_T_SITREP_ZONES", count (missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]),
		count (missionNamespace getVariable ["zone_meta_array", []])]
];
// Absent where towns keep no reputation (civilians off, RAVAGE, WBK), which would otherwise read as all neutral.
if (!isNil "DUWS_blufor_town_pos") then {
	private _friendly = count DUWS_blufor_town_pos;
	private _hostile = count (missionNamespace getVariable ["DUWS_enemy_town_pos", []]);
	_lines pushBack format [localize "STR_DUWS_T_SITREP_TOWNS", _friendly, _hostile,
		((count (missionNamespace getVariable ["duws_town_circles", []])) - _friendly - _hostile) max 0];
};
_lines append [
	format [localize "STR_DUWS_T_SITREP_CP", missionNamespace getVariable ["commandpointsblu1", 0]],
	format [localize "STR_DUWS_T_SITREP_AP", missionNamespace getVariable ["WARCOM_blufor_ap", 0],
		[missionNamespace getVariable ["WARCOM_blufor_tier", 1]] call DUWS_fnc_tierName],
	format [localize "STR_DUWS_T_SITREP_ENEMY", [missionNamespace getVariable ["WARCOM_opfor_tier", 1]] call DUWS_fnc_tierName]
];
// The multiplier is the one escalation figure a client holds: 1 + level / 10.
private _level = round (((missionNamespace getVariable ["escalation_multiplier", 1]) - 1) * 10);
if (_level > 0) then { _lines pushBack format [localize "STR_DUWS_T_SITREP_ESCALATION", _level] };

hint parseText (_lines joinString "<br/>");
