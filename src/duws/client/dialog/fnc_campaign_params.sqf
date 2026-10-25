// Locality: client -- the load screen's EDIT PARAMS dialog (shared/includes/campaign_load_menu.hpp). The edits wait
// here per save until LOAD sends them (fnc_campaign_fork_action.sqf), and the server checks them again.
params ["_action", ["_arg", []]];
if (isNil "DUWS_forkParamEdits") then { DUWS_forkParamEdits = createHashMap };

switch (_action) do {
	case "open": {
		_arg params ["_id", "_rows"];
		if (!createDialog "duws_campaign_params") exitWith {};
		private _display = uiNamespace getVariable "DUWS_forkParamsDisplay";
		(_display displayCtrl 9814) ctrlSetStructuredText parseText format ["<t color='#ff9933'>%1</t>", localize "STR_DUWS_T_fork_params_warn"];
		(ctrlPosition (_display displayCtrl 9817)) params ["_labelX", "_top", "_labelW", "_h"];
		(ctrlPosition (_display displayCtrl 9818)) params ["_valueX", "", "_valueW"];
		private _edited = createHashMapFromArray (DUWS_forkParamEdits getOrDefault [_id, []]);
		private _combos = [];
		{
			_x params ["_param", "_saved"];
			private _cfg = missionConfigFile >> "Params" >> _param;
			private _values = getArray (_cfg >> "values");
			private _y = _top + _forEachIndex * _h * 1.2;
			private _label = _display ctrlCreate ["RscText", -1];
			_label ctrlSetPosition [_labelX, _y, _labelW, _h];
			_label ctrlSetText getText (_cfg >> "title");
			_label ctrlCommit 0;
			private _combo = _display ctrlCreate ["RscCombo", -1];
			_combo ctrlSetPosition [_valueX, _y, _valueW, _h];
			_combo ctrlCommit 0;
			{ _combo lbAdd _x } forEach getArray (_cfg >> "texts");
			_combo lbSetCurSel ((_values find (_edited getOrDefault [_param, _saved])) max 0);
			_combos pushBack [_param, _combo, _saved, _values];
		} forEach _rows;
		_display setVariable ["DUWS_rows", [_id, _combos]];
	};
	case "apply": {
		private _display = uiNamespace getVariable ["DUWS_forkParamsDisplay", displayNull];
		(_display getVariable ["DUWS_rows", ["", []]]) params ["_id", "_combos"];
		private _edits = [];
		{
			_x params ["_param", "_combo", "_saved", "_values"];
			private _value = _values select ((lbCurSel _combo) max 0);
			if (_value isNotEqualTo _saved) then { _edits pushBack [_param, _value] };
		} forEach _combos;
		DUWS_forkParamEdits set [_id, _edits];
		closeDialog 1;
	};
};
