// Locality: the client that clicked. Draws the answer fnc_civ_townQuery sent back.
// Not a hint: the engine's hint box renders beneath findDisplay 12, so a hint raised over the
// open map plays its sound and shows nothing. fnc_map_prompt draws on the map display itself.
// Empty arguments mean the click missed every revealed town.
if (!hasInterface) exitWith {};

params [["_name", ""], ["_pop", 0], ["_hasRep", false], ["_rep", 0], ["_income", 0], ["_side", ""]];

private _text = localize "STR_DUWS_T_civ_mapview_miss";
if (_name isNotEqualTo "") then {
	private _lines = [
		format ["<t size='1.2'>%1</t>", _name],
		format [localize "STR_DUWS_T_civ_mapview_pop", _pop]
	];
	// A town with no registered reputation shows neither it nor an income line, rather than a
	// pair of zeroes a player would read as "neutral, earns nothing" instead of "not modelled".
	if (_hasRep) then {
		// Printed as stored, not rounded: a town at 9.7 shown as 10 would contradict the
		// neutral colour of the icon the player just clicked.
		_lines pushBack format [localize "STR_DUWS_T_civ_mapview_rep", _rep];
		private _incomeKey = switch (_side) do {
			case "BLU": { "STR_DUWS_T_civ_mapview_income_blu" };
			case "OPF": { "STR_DUWS_T_civ_mapview_income_opf" };
			default { "STR_DUWS_T_civ_mapview_income_none" };
		};
		_lines pushBack format [localize _incomeKey, _income];
	};
	_text = _lines joinString "<br/>";
};

[_text] call fnc_map_prompt;

// A serial rather than a script handle, because the banner is one shared control: the timer
// from an earlier click must not wipe a later click's readout when its ten seconds are up.
// uiNamespace, not missionNamespace: this is display state, and the mission namespace is
// serialized into save games.
private _seq = (uiNamespace getVariable ["DUWS_civ_mapInfo_seq", 0]) + 1;
uiNamespace setVariable ["DUWS_civ_mapInfo_seq", _seq];

[_seq] spawn {
	params ["_seq"];
	sleep 10;
	if ((uiNamespace getVariable ["DUWS_civ_mapInfo_seq", 0]) isEqualTo _seq) then {
		[""] call fnc_map_prompt;
	};
};
