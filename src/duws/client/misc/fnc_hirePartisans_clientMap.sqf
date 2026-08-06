// fnc_hirePartisans_clientMap.sqf
// Client-side: open the map to pick a partisan deploy spot; the map is forced to stay open.
if (!hasInterface) exitWith {};

params ["_caller", "_count"];

// prevent opening the map twice
if (!isNil "hirePartisans_mapOpen" && {hirePartisans_mapOpen}) exitWith {
    hint localize "STR_DUWS_T_partisans_placing_busy";
};
hirePartisans_mapOpen = true;

// stash params on a player variable to bridge them into the spawn below
player setVariable ["DUWS_partisan_caller", _caller];
player setVariable ["DUWS_partisan_count", _count];

private _got = ["PARTISANS", {
    params ["_pos"];
    ["PARTISANS"] call fnc_mapclick_release;
    openMap false;
    hirePartisans_mapOpen = false;

    // read from the player variable; avoids spawn arg-passing issues
    [_pos] spawn {
        params ["_pos"];
        private _caller = player getVariable "DUWS_partisan_caller";
        private _count  = player getVariable "DUWS_partisan_count";
        player setVariable ["DUWS_partisan_caller", nil];
        player setVariable ["DUWS_partisan_count", nil];
        sleep 0.3;
        [_caller, _pos, _count] remoteExec ["fnc_hirePartisans_spawnDeployed", 2];
    };
    true;
}] call fnc_mapclick_claim;
// The flag is raised above this point, so a refused claim has to lower it again or the action
// stays permanently "already placing a squad".
if (!_got) exitWith { hirePartisans_mapOpen = false; };

openMap true;
// Drawn on the map, not hinted: the hint box renders beneath the map display, so this
// instruction was issued one line before the map covered it and never reached the player --
// who was then held in a map that refuses to close, with nothing saying why.
[localize "STR_DUWS_T_partisans_place_brief"] call fnc_map_prompt;

// force the map to stay open until a click
while {hirePartisans_mapOpen} do {
    if (!visibleMap) then {
        openMap true;
    };
    sleep 0.1;
};