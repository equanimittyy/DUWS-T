// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.

[east] call fnc_autodetect_watchVehicles;


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


// Same filter the AutoDetect picker applies: apocalypse mode rolls zombie factions, every other mode
// rolls the rest -- so a random OPFOR is never zombies off-theme, nor an army in the zombie campaign.
_wantZombies = (missionNamespace getVariable ["duws_gamemode", "duws"]) isEqualTo "apocalypse";

_factions = (call BIS_fnc_getFactions) select {
	getNumber (configFile >> "CfgFactionClasses" >> _x >> "side") in [0,1,2] &&
	!(getNumber (configFile >> "CfgFactionClasses" >> _x >> "priority") in [4]) &&
	{([_x] call fnc_factionIsZombie) isEqualTo _wantZombies}
};

_factions2d = (_factions apply {[getText (configFile >> "CfgFactionClasses" >> _x >> "displayName"), _x]} select { _x#0 != "" });
factionList = [];
{ if !( _x#0 in flatten factionList ) then { factionList append [_x]} } forEach _factions2d;	// sanitize factions with multiple sides (duplicates)
factionList;	// for listbox

//_factionData = ("(gettext (_x >> 'faction') == _faction ) && !('base' in toLower configname _x)" configClasses (configfile >> "CfgVehicles")) apply {configName _x};
//[_faction, [_factionData, "apcs"] call fnc_factionGetFiltered ];

 
fnc_factionGen = {
	_faction = _this;
	//systemChat str _faction;
	{ _x call fnc_faction_resolve } forEach (["opfor", [_faction] call fnc_parseFaction] call fnc_faction_ladders);

};


// Held in selectedFaction_OPF like a picked faction, so a saved campaign reloads the faction it rolled.
if (isNil "selectedFaction_OPF") then { selectedFaction_OPF = (selectRandom factionList) select 1 };
selectedFaction_OPF call fnc_factionGen;


o_arraysToRandomize = (["opfor"] call fnc_faction_schema) apply {_x select 0};


// Pools published, not collapsed by a timer. See fnc_faction_pools for what a thread per role gets wrong.
[o_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
