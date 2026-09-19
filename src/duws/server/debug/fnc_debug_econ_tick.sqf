// Locality: server. A real tick, not a dry run: it pays both sides, and the 30-minute clock keeps its own schedule.
if (!isServer) exitWith {};

params [["_caller", objNull]];
if (isNull _caller) exitWith {};

(call fnc_zonesundercontrol) params ["_towns", "_bluCP", "_bluZoneAP", "_opfTownAP", "_opfZoneAP", "_killCP"];

private _rows = [
	"pools",
	["BLU CP", format ["+%1", _bluCP + _killCP], format ["town %1, kills %2, now %3", _bluCP, _killCP, commandpointsblu1]],
	["BLU AP", format ["+%1", _bluZoneAP], format ["zone trickle, now %1", WARCOM_blufor_ap]],
	["OPF AP", format ["+%1", _opfTownAP + _opfZoneAP + opfor_flat_ap_income],
		format ["town %1, zone %2, flat %3, now %4", _opfTownAP, _opfZoneAP, opfor_flat_ap_income, WARCOM_opfor_ap]],
	"aoi drift",
	["Push when covering", format ["OPF -%1, BLU +%2", 1 + DUWS_opforRadioLevel, DUWS_bluforRadioLevel],
		format ["OPF 1 + %1 radio towers, BLU radio tier %2", DUWS_opforRadioLevel, DUWS_bluforRadioLevel]]
];

private _locs = missionNamespace getVariable ["civ_locations", []];
private _worth = missionNamespace getVariable ["civ_town_ap", []];
if (_towns isEqualTo []) then { _rows pushBack ["Towns", "none", "civilians off"] };
{
	_x params ["_old", "_new", "_opforCovers", "_bluforCovers", "_push"];
	private _name = text (_locs param [_forEachIndex, locationNull]);
	if (_name isEqualTo "") then { _name = format ["Unnamed%1", _forEachIndex] };
	private _cover = ["uncovered", "OPF cover", "BLU cover", "OPF + BLU cover"] select (([0, 1] select _opforCovers) + ([0, 2] select _bluforCovers));
	([_new, _worth param [_forEachIndex, 0]] call fnc_civ_townIncome) params ["_income", "_side"];
	private _pays = ["pays nothing", format ["pays %1 %2", _side, _income]] select (_side isNotEqualTo "");
	private _crossed = ["", ", crossed band"] select (((_old <= -10) != (_new <= -10)) || {(_old >= 10) != (_new >= 10)});
	_rows pushBack [_name, format ["%1 -> %2", _old, _new],
		format ["%1, push %2%3, %4%5", _cover, ["", "+"] select (_push > 0), _push, _pays, _crossed]];
} forEach _towns;

diag_log "[DUWS econ tick debug]";
["Economy tick", format ["tick %1, throttle x%2", econ_tick, DUWS_econ_throttle toFixed 2], _rows, _caller] call fnc_debug_ledger_hint;
