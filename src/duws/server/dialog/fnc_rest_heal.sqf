// Locality: server -- callers remoteExec to target 2.

// _restSite: the object the rest was called on (HQ satellite phone or FOB). Only troops
// standing near it are treated, so resting can't patch up a player mid-firefight elsewhere.
params ["_restSite", "_hours", "_overcast", "_rain", "_fog", "_lightning"];

private _healRadius = 100;
private _restedPlayers = (call BIS_fnc_ListPlayers) select {_x distance _restSite < _healRadius};

// Every screen must be fully black before the clock moves: three hours of sky change
// landing in one frame reads as an engine glitch rather than as nightfall.
[["", "BLACK OUT", 1.5]] remoteExec ["titleCut", 0];
sleep 1.7;

{deleteVehicle _x} forEach allDeadMen;

// Heals enemies standing inside the radius also. AI is local to the server, so this runs here.
{
	if (isPlayer _x) then { continue };
	_x setdammage 0;
} forEach (allUnits select {_x distance _restSite < _healRadius});

// Players heal on their own machine: setDamage and ACE's fullHealLocal both need the unit
// local, so healing them from here would treat nobody but the host.
{
	[{
		player setdammage 0;
		if (isClass (configFile >> "CfgPatches" >> "ace_medical") || isClass (configFile >> "CfgPatches" >> "ace_main")) then {
			[player] call ace_medical_treatment_fnc_fullHealLocal;
		};
	}] remoteExec ["BIS_fnc_Spawn", _x];
} forEach _restedPlayers;

skiptime _hours;

// Gated server-side too, so the parameter holds even if a client sent weather values anyway.
if ((["DUWS_RestWeather", 1] call BIS_fnc_getParamValue) == 1) then {
    // Rain renders only over overcast >= 0.5, so floor it when rain is wanted (guards a direct call
    // that skips the menu's slider coupling). Rain is set after the forced overcast, not before.
    if (_rain > 0) then { _overcast = _overcast max 0.5 };
    0 setOvercast _overcast;
    forceWeatherChange;
    0 setRain _rain;
    0 setFog [_fog, 0.05, 20];
    // setLightnings shows only during a storm; a value here does nothing visible unless rain is up.
    0 setLightnings _lightning;
};

[["", "BLACK IN", 1.5]] remoteExec ["titleCut", 0];
sleep 0.3;

// Announced here rather than by the caller: the screen has been black and the clock has moved,
// so the line lands on a team that has visibly rested instead of on one still standing in
// daylight waiting for the fade to start.
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_restsuccess"] call fnc_cs)]
	remoteExec ["fnc_duws_dialogue", 0];

[{hint localize "STR_DUWS_T_437x650k"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
sleep 2;
[] remoteExec ["fnc_bottom_right_message", [0,-2] select isDedicated,false];
