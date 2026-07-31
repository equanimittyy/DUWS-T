// Locality: server -- spawned once per FOB by server/supports/fnc_fob_server.sqf.
//
// A FOB garrison has never been culled: twelve soldiers per FOB stayed fully simulated for the rest
// of the campaign, at up to floor(zones x 0.7) FOBs. Neither does the HQ's, but there is one of
// those and the player is usually stood in it.
//
// Frozen rather than deleted, which is where this parts company with the zone streaming it
// otherwise copies (init_zones/fnc_spawnWait.sqf). A zone garrison belongs to OPFOR and is rebuilt
// from a table, so deleting it loses nothing. A FOB's belongs to the player: rebuilding it would
// hand back every soldier who had been killed, which is a free version of the 2 CP redeploy bought
// by walking away for two minutes. Freezing keeps each unit's identity and damage, and simulation
// is where nearly all of an idle soldier's cost sits.
//
// enableSimulationGlobal, not enableSimulation: the latter is local, so a server-side freeze would
// leave every client still simulating them.
if (!isServer) exitWith {};

params ["_fob", "_centerPos"];

private _lastSeen = time;

while {!isNull _fob && {alive _fob}} do {
	sleep 10;

	// Players only. fnc_duws_bluforNear is the shared test everywhere else, and it cannot be used
	// here: its AI arm exists to notice BLUFOR arriving on OPFOR ground, so at a friendly base it
	// would count the garrison standing in the middle of the radius and never let it sleep.
	private _near = ((call BIS_fnc_ListPlayers) findIf { (_centerPos distance _x) < base_garrison_sleep_range }) >= 0;
	if (_near) then { _lastSeen = time };
	private _awake = _near || {time - _lastSeen <= base_garrison_sleep_delay};

	// Read each pass rather than captured once: a redeploy replaces the groups wholesale, and a
	// watcher holding the old ones would thaw units that no longer exist while the new ones stayed
	// frozen. Only units whose state actually differs are touched, because the command broadcasts.
	{
		{
			if !((_x getVariable ["DUWS_fobAwake", true]) isEqualTo _awake) then {
				_x enableSimulationGlobal _awake;
				_x setVariable ["DUWS_fobAwake", _awake];
			};
		} forEach (units _x);
	} forEach (_fob getVariable ["FOB_guardGroups", []]);
};
