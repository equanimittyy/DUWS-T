// Locality: server -- compiled by fnc_factions_check from server/server_init.sqf:31; defines
// faction helpers rather than running logic of its own.

[east] call fnc_autodetect_watchVehicles;


// fn_factionAutoDetect.sqf helpers are compiled once at init (fnc_factions_check).


fnc_factionGen = {
	_faction = _this;
	//systemChat str _faction;
	{ _x call fnc_faction_resolve } forEach (["opfor", [_faction] call fnc_parseFaction] call fnc_faction_ladders);


// Make vars public (dedicated-server compat) from the schema key list, not name-fragment matching
// (a fragment silently drops a role spelled off-pattern). No request catalogue, unlike BLUFOR. Mirrors AUTODETECT_blufor.
_publish = (["opfor"] call fnc_faction_schema) apply {_x select 0};
{ missionNamespace setVariable [_x, missionNamespace getVariable [_x, []], true] } forEach _publish;

}; // end of function: fnc_factionGen

//selectRandom factionList select 1 call fnc_factionGen;

// The faction was chosen during setup (fnc_startup_faction_resolve) and broadcast
// as selectedFaction_OPF; generate its data now, at the deferred commit.
waitUntil { sleep 0.1; !isNil "selectedFaction_OPF" };
selectedFaction_OPF call fnc_factionGen;
sleep 0.5;

o_arraysToRandomize = (["opfor"] call fnc_faction_schema) apply {_x select 0};

// Pools published, not collapsed by a timer. See fnc_faction_pools for what a thread per role gets wrong.
[o_arraysToRandomize] call fnc_faction_pools_publish;
sleep 1;
