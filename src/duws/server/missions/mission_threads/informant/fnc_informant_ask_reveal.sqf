// Locality: server. The informant ping: a hint to the asking player giving the informant's bearing
// and distance from where they stand, so walking and asking around triangulates him. Reached from the
// reaction roll (fnc_informant_ask_request) and from a paid bribe (fnc_civ_serve's INFORMANT case).
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _caller) exitWith {};

private _inf = missionNamespace getVariable ["DUWS_informant_unit", objNull];
private _townPos = missionNamespace getVariable ["DUWS_informant_townPos", [0, 0, 0]];
private _townRadius = missionNamespace getVariable ["DUWS_informant_townRadius", 200];

// Once he has left town -- driving out, or already gone -- the locals only know which way he went, not
// where he is. A direction, not a live fix.
if (isNull _inf || !alive _inf || {(_inf distance2D _townPos) > _townRadius}) exitWith {
    private _leaveDir = missionNamespace getVariable ["DUWS_informant_leaveDir", ""];
    [localize "STR_DUWS_T_civ", format [localize "STR_DUWS_T_INTEL_INFORMANT_ASK_GONE", _leaveDir]] remoteExec ["fnc_duws_dialogue", _caller];
};

// Still in town: a live bearing + distance from the asking player, to the nearest 5 m.
private _dir = _caller getDir _inf;
private _dist = round ((_caller distance2D _inf) / 5) * 5;
private _pts = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
private _compass = _pts select (floor (((_dir + 11.25) mod 360) / 22.5));

// The local's voice on the subtitle, the bearing on the hint box: the line sells the tip, the hint
// carries the fix. Reached from the free roll and the paid bribe alike, so both read the same.
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_INTEL_INFORMANT_ASK_HIT"] remoteExec ["fnc_duws_dialogue", _caller];
[format [localize "STR_DUWS_T_INTEL_INFORMANT_ASK_REVEAL", _dist, _compass]] remoteExec ["hint", _caller];
