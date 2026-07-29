// Locality: client -- the row handlers below run on whoever opened the menu.
/*
    fnc_debug_mission_menu.sqf
    Developer tool: start one side-mission type immediately, ignoring its cooldown and the
    global mission lock. Reached from fnc_debug_menu.sqf. Strings are English-only for the
    same reason as that file.
*/
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every
// client holds a copy it can call, and a forced mission makes the server do real work.
if (!((vehiclevarname player) in game_master)) exitWith {};

// Row order is fnc_mission_begin's mission type, so the index is the argument the server wants
// and the list doubles as the type reference when reading a MISSION log line.
private _types = [
	"Rescue squad", "Steal supply truck", "Kill HVT", "Destroy tower", "Rescue pilot",
	"Kill snipers", "Steal engineering vehicle", "Destroy armour", "Sabotage laptop",
	"Destroy cache", "Destroy radar", "Clear the area (CQB)", "Hold position", "Domination",
	"Protect civilian", "Transport IDAP", "Intel gathering"
];

private _rows = [];
{
	_rows pushBack [format ["%1  (type %2)", _x, _forEachIndex], {
		_this remoteExec ["fnc_debug_force_mission", 2];
		hint format ["Forcing mission type %1.\n\nIts cooldown and the global mission lock are cleared\nfirst, so the thread still opens the way a requested\nmission does. Position and name are picked as usual\nand land in the log.", _this];
	}, _forEachIndex, [1,0.667,0,1]];
} forEach _types;

["Force side mission", _rows] call fnc_open_action_menu;
