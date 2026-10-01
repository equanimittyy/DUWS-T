// Locality: server. Priced as OPCOM's same buy.
if (!isServer) exitWith {};

params [["_ref", []], ["_action", ""], ["_caller", objNull]];
if (isNull _caller) exitWith {};
_ref params [["_kind", ""], ["_id", []]];
if (_kind isNotEqualTo "ZONE") exitWith {};

private _fortify = _action isEqualTo "FORTIFY";
private _cost = [OPCOM_AP_REINFORCE, OPCOM_AP_FORTIFY] select _fortify;
// The defaults fail closed: a site no longer BLUFOR's answers [] and reads as contested.
([_ref] call fnc_map_readout_offer) params [["_contested", true], ["_canReinforce", false], ["_canFortify", false]];

// A refused offer needs no note: the redraw shows the site as it now stands.
private _note = "";
if (!_contested && {[_canReinforce, _canFortify] select _fortify}) then {
	if (WARCOM_blufor_ap < _cost) then {
		_note = "STR_DUWS_T_mapview_buy_no_ap";
	} else {
		private _reason = format ["map readout %1 by %2", toLower _action, name _caller];
		["BLU", -_cost, _reason] call fnc_ap_adjust;
		if (_fortify) then {
			[[_id] call fnc_zone_key, _reason] call fnc_zone_garrison_fortify;
			_note = "STR_DUWS_T_mapview_buy_fortified";
		} else {
			[[_id] call fnc_zone_key, _reason] call fnc_zone_garrison_reinforce;
			_note = "STR_DUWS_T_mapview_buy_reinforced";
		};
	};
};

// Redrawn from the zone's own centre, which the nearest-centre pick always resolves back to this zone.
[_id, _caller, _note] call fnc_map_readout_query;
