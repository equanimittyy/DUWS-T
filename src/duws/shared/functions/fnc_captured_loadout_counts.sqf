// Tally class -> count from a getUnitLoadout array. The loadout nests counts in three shapes -- a
// weapon's loaded magazine is [mag, ammo] (one magazine), a container holds [class, count] pairs,
// and worn/assigned slots are bare strings -- so a flat pushBackUnique scan would both lose counts
// and miss magazines. Returns a HashMap.
	params [["_loadout", []]];
	private _counts = createHashMap;
	private _bump = {
		params ["_cls", ["_n", 1]];
		if (_cls isEqualType "" && {_cls != ""}) then {
			_counts set [_cls, (_counts getOrDefault [_cls, 0]) + _n];
		};
	};
	// primary/secondary/handgun/binocular share this shape: 0 name, 1 muzzle, 2 pointer, 3 optic,
	// 4/5 [mag, ammo], 6 bipod.
	private _weapon = {
		params ["_w"];
		if (!(_w isEqualType []) || {_w isEqualTo []}) exitWith {};
		{ [_w param [_x, ""]] call _bump; } forEach [0, 1, 2, 3, 6];
		{
			private _m = _w param [_x, []];
			if (_m isEqualType [] && {(count _m) >= 1}) then { [_m select 0, 1] call _bump; };
		} forEach [4, 5];
	};
	// uniform/vest/backpack: [name, [[class, count], ...]].
	private _container = {
		params ["_c"];
		if (!(_c isEqualType []) || {_c isEqualTo []}) exitWith {};
		[_c param [0, ""]] call _bump;
		private _contents = _c param [1, []];
		if (_contents isEqualType []) then {
			{
				if (_x isEqualType [] && {(count _x) >= 1}) then { [_x select 0, _x param [1, 1]] call _bump; };
			} forEach _contents;
		};
	};
	{ [_loadout param [_x, []]] call _weapon; } forEach [0, 1, 2, 8];
	{ [_loadout param [_x, []]] call _container; } forEach [3, 4, 5];
	[_loadout param [6, ""]] call _bump;   // headgear
	[_loadout param [7, ""]] call _bump;   // facewear
	private _assigned = _loadout param [9, []];
	if (_assigned isEqualType []) then { { [_x] call _bump; } forEach _assigned; };
	_counts
