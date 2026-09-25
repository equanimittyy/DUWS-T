// Locality: client -- the load screen's list selection (shared/includes/campaign_load_menu.hpp).
private _sel = lbCurSel 9802;
private _row = if (_sel < 0) then { [] } else { DUWS_saveList param [lbValue [9802, _sel], []] };

// Faction and map names come from config, and structured text drops its whole body on a stray bracket or ampersand.
private _plain = { (_this splitString "<>&") joinString " " };
private _factionName = {
	params ["_file", "_sel", "_list"];
	if (_file in ["AUTODETECT", "AUTODETECT_RANDOM"] && {_sel isNotEqualTo ""}) exitWith {
		getText (configFile >> "CfgFactionClasses" >> _sel >> "displayName")
	};
	private _i = _list findIf { (_x select 2) isEqualTo _file };
	if (_i < 0) then { _file } else { (_list select _i) select 1 }
};

private _text = localize "STR_DUWS_T_fork_none";
if (_row isNotEqualTo []) then {
	_row params ["", "_pairs", "_why"];
	private _h = createHashMapFromArray _pairs;
	private _world = _h getOrDefault ["world", ""];
	private _mapName = getText (configFile >> "CfgWorlds" >> _world >> "description");
	_text = format [localize "STR_DUWS_T_fork_detail",
		_h getOrDefault ["day", 1], ([_mapName, _world] select (_mapName isEqualTo "")) call _plain,
		_h getOrDefault ["held", 0], _h getOrDefault ["zones", 0], _h getOrDefault ["cp", 0],
		([_h getOrDefault ["blu", ""], _h getOrDefault ["bluSel", ""], Factions_Available_BLUFOR_X] call _factionName) call _plain,
		([_h getOrDefault ["opf", ""], _h getOrDefault ["opfSel", ""], Factions_Available_OPFOR_X] call _factionName) call _plain];
	switch (_h getOrDefault ["ended", ""]) do {
		case "won": { _text = _text + "<br/><br/>" + localize "STR_DUWS_T_fork_ended_won" };
		case "lost": { _text = _text + "<br/><br/>" + localize "STR_DUWS_T_fork_ended_lost" };
	};
	if (_why isNotEqualTo "") then {
		_text = _text + "<br/><br/>" + format ["<t color='#ff9933'>%1</t>", localize _why];
	} else {
		private _missing = DUWS_saveOutcomes select { !(_x in (_h getOrDefault ["groups", []])) };
		if (_missing isNotEqualTo []) then {
			_text = _text + "<br/><br/>" + format ["<t color='#ff9933'>%1</t>", format [localize "STR_DUWS_T_fork_missing", _missing joinString ", "]];
		};
	};
};
((uiNamespace getVariable ["DUWS_forkDisplay", displayNull]) displayCtrl 9803) ctrlSetStructuredText parseText
	format ["<t size='0.85'>%1</t>", _text];
ctrlEnable [9808, _row isNotEqualTo [] && {(_row select 2) isEqualTo ""}];
ctrlEnable [9809, _row isNotEqualTo []];
ctrlEnable [9811, _row isNotEqualTo []];
