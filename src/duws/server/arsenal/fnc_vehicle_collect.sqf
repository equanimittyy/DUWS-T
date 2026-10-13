// Locality: server, by remoteExecCall from the Loot into vehicle hold action, so the vehicle's room is
// read and spent in one unscheduled step and two players cannot load one vehicle past full. Room is config
// mass against maximumLoad, because the cargo add commands ignore capacity.
//
// A ground holder moves whole or not at all: cargo has no remove-one command, and a partial move would
// have to rebuild its containers. A body moves slot by slot, so a full vehicle still takes the rifle off a
// body whose backpack does not fit. A container lands empty with its contents loose, so nothing has to
// find the new container object to refill it.
if (!isServer) exitWith {};
params ["_veh", "_caller"];
if (!alive _veh || {isNull _caller}) exitWith {};

private _massOf = {
	params ["_cls"];
	private _w = configFile >> "CfgWeapons" >> _cls;
	if (isClass _w) exitWith { (getNumber (_w >> "WeaponSlotsInfo" >> "mass")) max (getNumber (_w >> "ItemInfo" >> "mass")) };
	private _m = 0;
	{ if (isClass (configFile >> _x >> _cls)) exitWith { _m = getNumber (configFile >> _x >> _cls >> "mass") } } forEach ["CfgMagazines", "CfgVehicles", "CfgGlasses"];
	_m
};
private _weaponMass = {
	params ["_w"];
	private _m = [_w select 0] call _massOf;
	{ _m = _m + ([_w param [_x, ""]] call _massOf) } forEach [1, 2, 3, 6];
	{ private _mag = _w param [_x, []]; if (_mag isNotEqualTo []) then { _m = _m + ([_mag select 0] call _massOf) } } forEach [4, 5];
	_m
};
// Cargo is DUWS_fnc_campaignCargo's shape: [weapons, [mag, ammo] pairs, items, backpacks, [[container, cargo], ...]].
private _cargoMass = {
	params ["_cargo"];
	_cargo params ["_weapons", "_mags", "_items", "_packs", "_nested"];
	private _m = 0;
	{ _m = _m + ([_x] call _weaponMass) } forEach _weapons;
	{ _m = _m + ([_x select 0] call _massOf) } forEach _mags;
	{ _m = _m + ([_x] call _massOf) } forEach (_items + _packs);
	{ _m = _m + ([_x select 1] call _cargoMass) } forEach _nested;
	_m
};
// A preset backpack class carries config contents that addBackpackCargoGlobal would add a second time.
private _addCargo = {
	params ["_cargo"];
	_cargo params ["_weapons", "_mags", "_items", "_packs", "_nested"];
	{ _veh addWeaponWithAttachmentsCargoGlobal [_x, 1] } forEach _weapons;
	{ _veh addMagazineAmmoCargo [_x select 0, 1, _x select 1] } forEach _mags;
	{ _veh addItemCargoGlobal [_x, 1] } forEach _items;
	{ _veh addBackpackCargoGlobal [_x call BIS_fnc_basicBackpack, 1] } forEach _packs;
	_moved = _moved + count _weapons + count _mags + count _items + count _packs;
	{ [_x select 1] call _addCargo } forEach _nested;
};
private _take = {
	params ["_cargo"];
	private _m = [_cargo] call _cargoMass;
	if (_m > _room) exitWith { _left = true; false };
	_room = _room - _m;
	[_cargo] call _addCargo;
	true
};
// A getUnitLoadout container lists [weapon array, n], [magazine, n, ammo] or [item, n].
private _contentsCargo = {
	params ["_contents"];
	private _cargo = [[], [], [], [], []];
	{
		_x params ["_c", ["_n", 1]];
		for "_k" from 1 to _n do {
			if (_c isEqualType []) then { (_cargo select 0) pushBack _c } else {
				if (count _x > 2) then { (_cargo select 1) pushBack [_c, _x select 2] } else { (_cargo select 2) pushBack _c };
			};
		};
	} forEach _contents;
	_cargo
};

private _room = getNumber (configFile >> "CfgVehicles" >> typeOf _veh >> "maximumLoad") - ([[_veh] call DUWS_fnc_campaignCargo] call _cargoMass);
private _moved = 0;
private _left = false;
private _sources = nearestObjects [_veh, ["CAManBase", "WeaponHolder", "GroundWeaponHolder", "WeaponHolderSimulated"], 50];
{
	if (_x isKindOf "CAManBase") then {
		if (alive _x) then { continue };
		private _body = _x;
		private _l = getUnitLoadout _body;
		private _weapons = [];
		private _worn = [];
		private _linked = [];
		{
			private _w = _l select _x;
			if (_w isNotEqualTo [] && {[[[_w], [], [], [], []]] call _take}) then { _weapons pushBack (_w select 0) };
		} forEach [0, 1, 2, 8];
		{
			private _c = _l select _x;
			if (_c isNotEqualTo []) then {
				private _cargo = [_c select 1] call _contentsCargo;
				(_cargo select ([2, 3] select (_x == 5))) pushBack (_c select 0);
				if ([_cargo] call _take) then { _worn pushBack _x };
			};
		} forEach [3, 4, 5];
		{
			private _cls = _l select _x;
			if (_cls != "" && {[[[], [], [_cls], [], []]] call _take}) then { _worn pushBack _x };
		} forEach [6, 7];
		{
			if (_x != "" && {[[[], [], [_x], [], []]] call _take}) then { _linked pushBack _x };
		} forEach (_l select 9);
		if ((_weapons + _worn + _linked) isNotEqualTo []) then {
			if (local _body) then { [_body, _weapons, _worn, _linked] call fnc_body_strip } else { [_body, _weapons, _worn, _linked] remoteExec ["fnc_body_strip", _body] };
		};
	} else {
		private _cargo = [_x] call DUWS_fnc_campaignCargo;
		if (_cargo isNotEqualTo [[], [], [], [], []] && {[_cargo] call _take}) then {
			clearWeaponCargoGlobal _x;
			clearMagazineCargoGlobal _x;
			clearItemCargoGlobal _x;
			clearBackpackCargoGlobal _x;
		};
	};
} forEach (_sources arrayIntersect _sources);

if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["vehicle collect %1 into %2: moved=%3 left=%4 room=%5", name _caller, typeOf _veh, _moved, _left, _room]] call fnc_log; };
if (_moved == 0 && {!_left}) exitWith { [localize "STR_DUWS_T_VEHICLE_COLLECT_NONE"] remoteExec ["hint", _caller]; };
private _msg = format [localize "STR_DUWS_T_VEHICLE_COLLECT_DONE", _moved];
if (_left) then { _msg = _msg + "\n" + localize "STR_DUWS_T_VEHICLE_COLLECT_FULL" };
[_msg] remoteExec ["hint", _caller];
