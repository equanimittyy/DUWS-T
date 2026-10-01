// The sniper role degrades to marksman and rifleman on a faction with no sniper, and a rifleman on a
// perch has no reach.
params ["_class"];
private _primary = (([_class] call fnc_faction_class_loadout) param [0, []]) param [0, ""];
if (((_primary call BIS_fnc_itemType) select 1) == "SniperRifle") exitWith { _class };
"O_sniper_F"
