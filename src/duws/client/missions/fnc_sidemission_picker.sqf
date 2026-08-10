// Locality: the client viewing the map. The in-map side-mission picker: draws the generated
// missions on the open map (findDisplay 12) as local markers, lets the player cycle and pick one
// from a bottom bar or by clicking the map, and launches the chosen mission behind an inline
// confirm. Replaces the BIS strategic-map presentation (fnc_stratmap) for the map-view path; both
// share the cached batch from fnc_sidemission_generate.
//
// One dispatcher rather than a function per verb: all picker state lives together and the button
// and map-click handlers call back in with a mode. Handlers spawn this (not call), so the "open"
// path reaches scheduled context for the generator's loading-screen search.
//
// The map has a single onMapSingleClick owner (fnc_mapclick_init). Opening takes it from the zone
// readout ("MAPREADOUT"); closing hands it back by re-arming the readout. Only one of the two
// modes drives the map click at a time.
//
// Control idc block on display 12: 91350 bar bg, 91351 info, 91352 prev, 91353 next, 91354 launch,
// 91355 confirm prompt, 91356 confirm, 91357 cancel.
if (!hasInterface) exitWith {};
disableSerialization;

params ["_mode"];

switch (_mode) do {

	case "toggle": {
		if (uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) then {
			["close"] call fnc_sidemission_picker;
		} else {
			["open"] call fnc_sidemission_picker;
		};
	};

	case "open": {
		if (uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) exitWith {};
		// A mission already active gates a new batch, the same bar fnc_stratmap enforces; over the
		// open map the refusal is a banner, since the hint box renders beneath the map.
		if (isNil "Mission_available" || {!Mission_available}) exitWith {
			[localize "STR_DUWS_T_sidemission_busy"] call fnc_map_prompt;
		};
		if (!((vehiclevarname player) in game_master)) exitWith {
			[localize "STR_DUWS_T_sidemission_gm"] call fnc_map_prompt;
		};
		if (!([] call fnc_sidemission_generate)) exitWith {
			[localize "STR_DUWS_T_sidemission_none"] call fnc_map_prompt;
		};

		private _disp = findDisplay 12;
		if (isNull _disp) exitWith {};

		// Take the map click from the readout. Its flag is cleared so the picker's close can re-arm
		// it through fnc_map_readout_open, which otherwise no-ops while it thinks it is already open.
		["MAPREADOUT"] call fnc_mapclick_release;
		DUWS_mapReadoutOpen = nil;
		[""] call fnc_map_prompt;
		["SIDEMISSIONPICKER", { params ["_pos"]; ["click", _pos] spawn fnc_sidemission_picker; true }] call fnc_mapclick_claim;

		// Stale markers cannot linger past a teardown, but clear defensively: createMarkerLocal on a
		// name that already exists returns "" and every setMarker*Local after it errors.
		{ deleteMarkerLocal _x } forEach (uiNamespace getVariable ["DUWS_sideMissionMarkers", []]);
		private _markers = [];
		{
			_x params ["_mpos", "", "_mname"];
			private _m = createMarkerLocal [format ["DUWS_sm_%1", _forEachIndex], _mpos];
			_m setMarkerTypeLocal "mil_objective";
			_m setMarkerColorLocal "ColorBLUFOR";
			_m setMarkerTextLocal _mname;
			_markers pushBack _m;
		} forEach array_of_missions;
		uiNamespace setVariable ["DUWS_sideMissionMarkers", _markers];

		private _bw = safezoneW * 0.5;
		private _bh = safezoneH * 0.13;
		private _bx = safezoneX + (safezoneW - _bw) / 2;
		private _by = safezoneY + safezoneH * 0.84;
		private _pad = safezoneW * 0.008;

		private _bg = _disp ctrlCreate ["RscText", 91350];
		_bg ctrlSetPosition [_bx, _by, _bw, _bh];
		_bg ctrlSetBackgroundColor [0, 0, 0, 0.75];
		_bg ctrlCommit 0;

		private _info = _disp ctrlCreate ["RscStructuredText", 91351];
		_info ctrlSetPosition [_bx + _pad, _by + _pad, _bw - 2*_pad, _bh * 0.5];
		_info ctrlCommit 0;

		private _prev = _disp ctrlCreate ["RscButton", 91352];
		_prev ctrlSetPosition [_bx + _pad, _by + _bh*0.62, _bw*0.1, _bh*0.3];
		_prev ctrlSetText (localize "STR_DUWS_T_sidemission_prev");
		_prev ctrlAddEventHandler ["ButtonClick", { ["prev"] spawn fnc_sidemission_picker }];
		_prev ctrlCommit 0;

		private _launch = _disp ctrlCreate ["RscButton", 91354];
		_launch ctrlSetPosition [_bx + _bw*0.3, _by + _bh*0.62, _bw*0.4, _bh*0.3];
		_launch ctrlSetText (localize "STR_DUWS_T_sidemission_launch");
		_launch ctrlAddEventHandler ["ButtonClick", { ["confirm"] spawn fnc_sidemission_picker }];
		_launch ctrlCommit 0;

		private _next = _disp ctrlCreate ["RscButton", 91353];
		_next ctrlSetPosition [_bx + _bw - _pad - _bw*0.1, _by + _bh*0.62, _bw*0.1, _bh*0.3];
		_next ctrlSetText (localize "STR_DUWS_T_sidemission_next");
		_next ctrlAddEventHandler ["ButtonClick", { ["next"] spawn fnc_sidemission_picker }];
		_next ctrlCommit 0;

		uiNamespace setVariable ["DUWS_sideMissionPickerOn", true];
		uiNamespace setVariable ["DUWS_sideMissionSel", -1];

		// Preselect the first, so the bar is never blank and the map frames a target on open.
		if (count array_of_missions > 0) then { ["select", 0] call fnc_sidemission_picker };
	};

	case "select": {
		if !(uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) exitWith {};
		params ["", "_idx"];
		private _n = count array_of_missions;
		if (_n == 0) exitWith {};
		_idx = ((_idx % _n) + _n) % _n;   // wrap both directions
		uiNamespace setVariable ["DUWS_sideMissionSel", _idx];

		private _markers = uiNamespace getVariable ["DUWS_sideMissionMarkers", []];
		{
			private _on = (_forEachIndex == _idx);
			_x setMarkerColorLocal (if (_on) then {"ColorYellow"} else {"ColorBLUFOR"});
			_x setMarkerSizeLocal (if (_on) then {[1.4, 1.4]} else {[1, 1]});
		} forEach _markers;

		(array_of_missions select _idx) params ["_mpos", "", "_mname", "_mdesc"];

		private _disp = findDisplay 12;
		private _info = _disp displayCtrl 91351;
		if (!isNull _info) then {
			_info ctrlSetStructuredText parseText format ["<t size='1.1'>%1</t><br/>%2", _mname, _mdesc];
		};

		// Recenter on the selection. Found by type rather than a hardcoded idc, so it does not break
		// if the map control's idc differs.
		private _map = controlNull;
		{ if (ctrlType _x in [100, 101]) exitWith { _map = _x } } forEach (allControls _disp);
		if (!isNull _map) then { _map ctrlMapAnimTo _mpos };
	};

	case "click": {
		if !(uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) exitWith {};
		params ["", "_pos"];
		// While the confirm is up the selection is locked: a stray map click must not move it under
		// a Confirm that already names a mission.
		if (!isNull ((findDisplay 12) displayCtrl 91355)) exitWith {};
		private _best = -1;
		private _bestD = 1e9;
		{
			private _d = (_x select 0) distance2D _pos;
			if (_d < _bestD) then { _bestD = _d; _best = _forEachIndex };
		} forEach array_of_missions;
		// Ignore a click far from every icon, so tapping empty map does not yank the selection
		// across the island.
		if (_best >= 0 && {_bestD < 1500}) then { ["select", _best] call fnc_sidemission_picker };
	};

	case "prev": { ["select", (uiNamespace getVariable ["DUWS_sideMissionSel", 0]) - 1] call fnc_sidemission_picker };
	case "next": { ["select", (uiNamespace getVariable ["DUWS_sideMissionSel", 0]) + 1] call fnc_sidemission_picker };

	case "confirm": {
		private _sel = uiNamespace getVariable ["DUWS_sideMissionSel", -1];
		if (_sel < 0) exitWith {};
		(array_of_missions select _sel) params ["", "", "_mname"];
		private _disp = findDisplay 12;
		if (isNull _disp) exitWith {};

		private _bw = safezoneW * 0.34;
		private _bx = safezoneX + (safezoneW - _bw) / 2;
		private _cy = safezoneY + safezoneH * 0.66;
		private _ch = safezoneH * 0.055;

		private _p = _disp ctrlCreate ["RscStructuredText", 91355];
		_p ctrlSetPosition [_bx, _cy, _bw, _ch];
		_p ctrlSetBackgroundColor [0, 0, 0, 0.85];
		_p ctrlSetStructuredText parseText format ["<t align='center'>%1</t>",
			format [localize "STR_DUWS_T_sidemission_confirm_prompt", _mname]];
		_p ctrlCommit 0;

		private _yes = _disp ctrlCreate ["RscButton", 91356];
		_yes ctrlSetPosition [_bx + _bw*0.1, _cy + _ch + safezoneH*0.008, _bw*0.35, _ch];
		_yes ctrlSetText (localize "STR_DUWS_T_sidemission_confirm");
		_yes ctrlAddEventHandler ["ButtonClick", { ["dolaunch"] spawn fnc_sidemission_picker }];
		_yes ctrlCommit 0;

		private _no = _disp ctrlCreate ["RscButton", 91357];
		_no ctrlSetPosition [_bx + _bw*0.55, _cy + _ch + safezoneH*0.008, _bw*0.35, _ch];
		_no ctrlSetText (localize "STR_DUWS_T_sidemission_cancel");
		_no ctrlAddEventHandler ["ButtonClick", { ["cancelconfirm"] spawn fnc_sidemission_picker }];
		_no ctrlCommit 0;
	};

	case "cancelconfirm": {
		private _disp = findDisplay 12;
		{ private _c = _disp displayCtrl _x; if (!isNull _c) then { ctrlDelete _c } } forEach [91355, 91356, 91357];
	};

	case "dolaunch": {
		private _sel = uiNamespace getVariable ["DUWS_sideMissionSel", -1];
		if (_sel < 0) exitWith {};
		private _block = (array_of_missions select _sel) select 1;
		// Teardown before the launch, not close: the map is about to shut, so re-arming the readout
		// would only openMap true and refresh a screen the next line closes.
		["teardown"] call fnc_sidemission_picker;
		call _block;         // {[N] call fnc_mission_launch} -- remoteExecs the thread, clears cache
		openMap false;       // hand the screen back; request_map_view's waitUntil reopens the menu
	};

	// Remove the picker UI and give the map click back to the background listener. Shared by close
	// and launch; only close re-arms the readout on top.
	case "teardown": {
		private _disp = findDisplay 12;
		{ private _c = _disp displayCtrl _x; if (!isNull _c) then { ctrlDelete _c } }
			forEach [91350, 91351, 91352, 91353, 91354, 91355, 91356, 91357];
		{ deleteMarkerLocal _x } forEach (uiNamespace getVariable ["DUWS_sideMissionMarkers", []]);
		uiNamespace setVariable ["DUWS_sideMissionMarkers", []];
		["SIDEMISSIONPICKER"] call fnc_mapclick_release;
		uiNamespace setVariable ["DUWS_sideMissionPickerOn", false];
		uiNamespace setVariable ["DUWS_sideMissionSel", -1];
	};

	case "close": {
		if !(uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) exitWith {};
		["teardown"] call fnc_sidemission_picker;
		// Give the zone readout its click back, if the map is still open.
		if (visibleMap) then { call fnc_map_readout_open };
	};

};
