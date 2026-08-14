// Locality: server. The informant ping: a hint to the asking player giving the informant's bearing
// and distance from where they stand, so walking and asking around triangulates him. Reached from the
// reaction roll (fnc_intel_ask_request) and from a paid bribe (fnc_civ_serve's INFORMANT case).
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _caller) exitWith {};

private _inf = missionNamespace getVariable ["DUWS_intel_informant", objNull];
if (isNull _inf || !alive _inf) exitWith {
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_INTEL_INFORMANT_ASK_GONE"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 16-point compass, offset by half a sector so each name spans its arc; distance to the nearest 5 m.
private _dir = _caller getDir _inf;
private _dist = round ((_caller distance2D _inf) / 5) * 5;
private _pts = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
private _compass = _pts select (floor (((_dir + 11.25) mod 360) / 22.5));

[format [localize "STR_DUWS_T_INTEL_INFORMANT_ASK_REVEAL", _dist, _compass]] remoteExec ["hint", _caller];
