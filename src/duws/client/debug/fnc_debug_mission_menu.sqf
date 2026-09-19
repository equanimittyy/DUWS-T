// Locality: client -- the row handlers below run on whoever opened the menu.
/*
    Developer tool, reached from the Debug menu's Missions page. _this is the mode: "start" starts one
    side-mission type now, ignoring its cooldown and the global mission lock; "reroll" rolls a fresh
    offer set, optionally forcing one type into the draw. Strings are English-only for the same reason
    as fnc_debug_menu.
*/
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every
// client holds a copy it can call, and a forced mission makes the server do real work.
if (!((vehiclevarname player) in game_master)) exitWith {};

// Row order is fnc_mission_begin's mission type, so the index is the argument the server wants
// and the list doubles as the type reference when reading a MISSION log line.
private _defs = [
#include "..\..\shared\includes\mission_types.hpp"
];
private _types = _defs apply { _x select 4 };

// Clears fnc_stratmap's cached offer set and reopens the picker, rolling a fresh seven. The cache
// is what keeps a normal back-out on the same offers; this is the intended way to roll new ones.
// The type step forces one type into the draw, to test its siting without the draw RNG.
if (_this == "reroll") exitWith {
	// Clears the start gate the way the force tool does (stamp to 0): a dev re-roll that still
	// tripped the three-hour wait would open the picker but roll a set none could start;
	// fnc_mission_begin re-stamps on the next start. _this is the type to force, -1 to skip.
	private _reroll = {
		DUWS_dbgForceDrawType = _this;
		DUWS_lastMissionStartDate = 0;
		publicVariable "DUWS_lastMissionStartDate";
		DUWS_missionOffers = [];
		[] spawn fnc_stratmap;
	};
	private _rows = [DBG_BACK("missions"), ["(none -- normal re-roll)", _reroll, -1, DBG_ACTION]];
	{
		_rows pushBack [format ["Force %1  (type %2)", _x, _forEachIndex], _reroll, _forEachIndex, DBG_ACTION];
	} forEach _types;
	["Re-roll: force a type into the draw", _rows] call fnc_open_action_menu;
};

private _rows = [DBG_BACK("missions")];
{
	_rows pushBack [format ["%1  (type %2)", _x, _forEachIndex], {
		_this remoteExec ["fnc_debug_force_mission", 2];
		hint format ["Forcing mission type %1.\n\nIts cooldown and the global mission lock are cleared\nfirst, so the thread still opens the way a requested\nmission does. Position and name are picked as usual\nand land in the log.", _this];
	}, _forEachIndex, DBG_ACTION];
} forEach _types;

["Start a side mission now", _rows] call fnc_open_action_menu;
