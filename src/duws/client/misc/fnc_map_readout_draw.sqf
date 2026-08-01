// Locality: the client that clicked. Draws the answer fnc_map_readout_query sent back, for a zone or
// for a civilian town.
// Not a hint: the engine's hint box renders beneath findDisplay 12, so a hint raised over the
// open map plays its sound and shows nothing. fnc_map_prompt draws on the map display itself.
// Empty arguments mean the click missed everything revealed.
if (!hasInterface) exitWith {};

params [["_kind", ""], ["_data", []]];

private _text = localize "STR_DUWS_T_civ_mapview_miss";

// SQF has no string repeat, and the bar is two runs of it in different colours.
private _fnc_pipes = {
	params ["_n"];
	private _s = "";
	for "_i" from 1 to _n do { _s = _s + "|" };
	_s
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
		_data params [["_name", ""], ["_held", false], ["_seg", 0], ["_tier", 0]];
		private _lines = [format ["<t size='1.2'>%1</t>", _name]];
		// Above the strength bar, and printed on a held zone too: tier is what the ground is worth
		// fighting for and strength is how much of it is left, so the pair reads in that order
		// whichever side holds it.
		_lines pushBack ([_tier] call _fnc_tier);
		if (_held) then {
			// No bar on a zone the player owns: a full run of grey would read as a garrison wiped
			// rather than as one that was never there.
			_lines pushBack localize "STR_DUWS_T_zone_mapview_held";
		} else {
			// Green for what is left, grey for what is gone. A bar rather than a percentage because
			// this is read while deciding where to go next -- proportion at a glance beats a figure
			// the player has to weigh against a zone size they cannot see. Twenty segments wide, so
			// a full garrison reads as a solid block; the query owns the scale.
			private _bar = format ["<t color='#55ff55'>%1</t><t color='#7f7f7f'>%2</t>",
				[_seg] call _fnc_pipes, [20 - _seg] call _fnc_pipes];
			_lines pushBack format [localize "STR_DUWS_T_zone_mapview_garrison", _bar];
		};
		_text = _lines joinString "<br/>";
	};

	case "TOWN": {
		_data params [["_name", ""], ["_pop", 0], ["_hasRep", false], ["_rep", 0], ["_income", 0],
			["_side", ""], ["_ap", 0], ["_tier", 0], ["_hold", ""]];
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
			// makes every unturned town look equally pointless. _income is what the tick actually
			// credits, _ap what the town becomes worth once it picks a side.
			_lines pushBack (switch (_side) do {
				case "BLU": { format [localize "STR_DUWS_T_civ_mapview_income_blu", _income] };
				case "OPF": { format [localize "STR_DUWS_T_civ_mapview_income_opf", _income] };
				default { format [localize "STR_DUWS_T_civ_mapview_income_none", _ap] };
			});
			// Last, so it sits where a zone's tier does -- directly above where a town strength bar
			// would go. Inside the reputation gate with the rest: a town that registers no
			// reputation can hold no tier either, and printing "None" would read as a town that
			// merely happens to be ungarrisoned.
			//
			// A held town prints why in place of the tier, and the two holds read differently: a
			// town that has just fallen has men on the way, a town that was cleared has men coming
			// back. Neither says "destroyed" -- a word that final would have the player write the
			// town off, and both of these end.
			_lines pushBack (switch (_hold) do {
				case "TAKEN": {
					format [localize "STR_DUWS_T_mapview_garrison_tier",
						localize "STR_DUWS_T_mapview_garrison_taken"]
				};
				case "REGROUP": {
					format [localize "STR_DUWS_T_mapview_garrison_tier",
						localize "STR_DUWS_T_mapview_garrison_regroup"]
				};
				default { [_tier] call _fnc_tier };
			});
		};
		_text = _lines joinString "<br/>";
	};

};

[_text] call fnc_map_prompt;

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
	};
};
