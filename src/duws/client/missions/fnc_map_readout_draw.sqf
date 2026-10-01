// Locality: the client that clicked. Draws the answer fnc_map_readout_query sent back, for a zone or
// for a civilian town.
// Not a hint: the engine's hint box renders beneath findDisplay 12, so a hint raised over the
// open map plays its sound and shows nothing. fnc_map_prompt draws on the map display itself.
// Empty arguments mean the click missed everything revealed.
if (!hasInterface) exitWith {};

params [["_kind", ""], ["_data", []], ["_note", ""]];

private _text = localize "STR_DUWS_T_civ_mapview_miss";
private _buy = [];
private _buyTier = 0;

// SQF has no string repeat, and the bar is two runs of it in different colours.
private _fnc_pipes = {
	params ["_n"];
	private _s = "";
	for "_i" from 1 to _n do { _s = _s + "|" };
	_s
};

// Green for what is left, grey for what is gone. A bar rather than a percentage because this is read
// while deciding where to go next -- proportion at a glance beats a figure the player has to weigh
// against a garrison size they cannot see. Twenty segments wide, so a full garrison reads as a solid
// block; the query owns the scale.
private _fnc_bar = {
	params ["_seg"];
	format [localize "STR_DUWS_T_zone_mapview_garrison",
		format ["<t color='#55ff55'>%1</t><t color='#7f7f7f'>%2</t>",
			[_seg] call _fnc_pipes, [20 - _seg] call _fnc_pipes]]
};

// Roman for the tier, because the ladder is written that way everywhere the player meets it, and
// arabic would collide with the strength figure sitting under it. Clamped rather than trusted: this
// arrives over the network, and an out-of-range index is a script error inside a map click.
private _fnc_tier = {
	params ["_tier"];
	private _label = [localize "STR_DUWS_T_mapview_garrison_none", "I", "II", "III", "IV"]
		select (((round _tier) max 0) min 4);
	format [localize "STR_DUWS_T_mapview_garrison_tier", _label]
};

switch (_kind) do {

	case "ZONE": {
		_data params [["_name", ""], ["_zoneKind", ""], ["_held", false], ["_seg", 0], ["_tier", 0],
			["_hold", ""], ["_offer", []]];
		_buy = _offer;
		_buyTier = _tier;
		// The kind qualifies the callsign rather than taking a line of its own, the way it reads on the
		// marker. Guarded because a zone answers the readout from the moment it registers but files its
		// kind at the end of build-out: a click inside that window would otherwise print "Foxtrot ()".
		private _title = _name;
		if !(_zoneKind isEqualTo "") then { _title = format ["%1 (%2)", _name, _zoneKind] };
		private _lines = [format ["<t size='1.2'>%1</t>", _title]];
		// Above the strength bar, and printed on a held zone too: tier is what the ground is worth
		// fighting for and strength is how much of it is left, so the pair reads in that order
		// whichever side holds it.
		//
		// A zone OPFOR have just retaken says so instead. The men are owed and not yet standing, so a
		// numeral here would report a garrison that is not there.
		_lines pushBack (if (_hold isEqualTo "MOBILISING") then {
			format [localize "STR_DUWS_T_mapview_garrison_tier",
				localize "STR_DUWS_T_mapview_garrison_mobilising"]
		} else {
			[_tier] call _fnc_tier
		});
		// A bar wherever there is a garrison to measure. A zone the player holds at tier 0 has none, and a
		// full run of grey there would read as a garrison wiped rather than one never built.
		if (_held && {_tier < 1}) then {
			_lines pushBack localize "STR_DUWS_T_zone_mapview_held";
		} else {
			_lines pushBack ([_seg] call _fnc_bar);
		};
		_text = _lines joinString "<br/>";
	};

	case "TOWN": {
		_data params [["_name", ""], ["_pop", 0], ["_hasRep", false], ["_rep", 0], ["_income", 0],
			["_side", ""], ["_ap", 0]];
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
			// A neutral town prints what it is worth, not the nothing it currently pays: reading the
			// map before moving is how the player picks which town to work on, and a bare "none"
			// makes every unturned town look equally pointless. Both figures are the town's worth --
			// _income side-gated to what a banded town pays, _ap the worth a neutral one turns into.
			_lines pushBack (switch (_side) do {
				case "BLU": { format [localize "STR_DUWS_T_civ_mapview_income_blu", _income] };
				case "OPF": { format [localize "STR_DUWS_T_civ_mapview_income_opf", _income] };
				default { format [localize "STR_DUWS_T_civ_mapview_income_none", _ap] };
			});
		};
		_text = _lines joinString "<br/>";
	};

};

_buy params [["_ref", []], ["_contested", false], ["_canReinforce", false], ["_canFortify", false],
	["_reinforceAp", 0], ["_fortifyAp", 0]];
if (_contested) then { _text = format ["%1<br/>%2", _text, localize "STR_DUWS_T_mapview_buy_contested"] };
if (_note isNotEqualTo "") then { _text = format ["%1<br/>%2", _text, localize _note] };

[_text] call fnc_map_prompt;

// On the map display, not in a dialog: a dialog draws over the map.
private _disp = findDisplay 12;
{ ctrlDelete (_disp displayCtrl _x) } forEach [91335, 91336];
private _rows = [];
if (_canReinforce) then {
	_rows pushBack ["REINFORCE", format [localize "STR_DUWS_T_mapview_buy_reinforce", _reinforceAp]];
};
if (_canFortify) then {
	_rows pushBack ["FORTIFY", format [localize "STR_DUWS_T_mapview_buy_fortify",
		["I", "II", "III", "IV"] select (((round _buyTier) max 0) min 3), _fortifyAp]];
};
if (_rows isNotEqualTo [] && {!isNull _disp}) then {
	(ctrlPosition (_disp displayCtrl 91334)) params ["_bx", "_by", "_bw", "_bh"];
	private _w = _bw * 0.3;
	private _h = safezoneH * 0.035;
	private _gap = safezoneH * 0.008;
	private _left = _bx + (_bw - (count _rows) * _w - ((count _rows) - 1) * _gap) / 2;
	{
		_x params ["_action", "_label"];
		private _btn = _disp ctrlCreate ["RscButton", 91335 + _forEachIndex];
		_btn ctrlSetPosition [_left + _forEachIndex * (_w + _gap), _by + _bh + _gap, _w, _h];
		_btn ctrlCommit 0;
		_btn ctrlSetText _label;
		// fnc_command_fill's COST_COLOUR: orange marks a button that spends.
		_btn ctrlSetTextColor [1, 0.502, 0, 1];
		_btn ctrlEnable !_contested;
		_btn setVariable ["duws_buy", [_ref, _action]];
		_btn ctrlAddEventHandler ["ButtonClick", {
			params ["_btn"];
			// One click, one purchase: the redraw that answers it brings fresh buttons.
			{ ((ctrlParent _btn) displayCtrl _x) ctrlEnable false } forEach [91335, 91336];
			((_btn getVariable "duws_buy") + [player]) remoteExec ["fnc_map_readout_buy", 2];
		}];
	} forEach _rows;
};

// A serial rather than a script handle, because the banner is one shared control: the timer
// from an earlier click must not wipe a later click's readout when its ten seconds are up.
// uiNamespace, not missionNamespace: this is display state, and the mission namespace is
// serialized into save games.
private _seq = (uiNamespace getVariable ["DUWS_mapReadout_seq", 0]) + 1;
uiNamespace setVariable ["DUWS_mapReadout_seq", _seq];

[_seq] spawn {
	params ["_seq"];
	sleep 10;
	if ((uiNamespace getVariable ["DUWS_mapReadout_seq", 0]) isEqualTo _seq) then {
		[""] call fnc_map_prompt;
		{ ctrlDelete ((findDisplay 12) displayCtrl _x) } forEach [91335, 91336];
	};
};
