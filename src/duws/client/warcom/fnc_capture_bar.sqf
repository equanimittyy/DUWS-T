// Locality: client, remoteExec'd by DUWS_fnc_siteTakeTell each time a capture's failed tests change. _done is the
// meter, 0 to 1: with no _blockers it fills over _hold, otherwise it drains _decay times as fast.
// A HUD layer, not the hint box: the count runs under the fight, and the flag's report must stay readable over it.
params ["_name", "_done", "_hold", "_decay", "_blockers", "_pos", "_ring"];
if (!hasInterface || {player distance2D _pos > _ring}) exitWith {};

// Each message supersedes the last: an older copy's loop sees the bump and stops drawing.
DUWS_captureBarRun = (missionNamespace getVariable ["DUWS_captureBarRun", 0]) + 1;
private _run = DUWS_captureBarRun;

private _layer = "DUWS_CaptureBar" call BIS_fnc_rscLayer;
private _disp = uiNamespace getVariable ["DUWS_captureBarDisplay", displayNull];
if (isNull _disp) then {
    _layer cutRsc ["DUWS_CaptureBar", "PLAIN", 0, false];
    waitUntil { _disp = uiNamespace getVariable ["DUWS_captureBarDisplay", displayNull]; !isNull _disp || {DUWS_captureBarRun != _run} };
};
if (DUWS_captureBarRun != _run) exitWith {};

private _line = _disp displayCtrl 8818;
private _fill = _disp displayCtrl 8820;
private _full = ctrlPosition (_disp displayCtrl 8819);
private _draining = count _blockers > 0;
private _secs = if (_draining) then { _done * _hold / _decay } else { (1 - _done) * _hold };
private _from = +_full;
_from set [2, (_full select 2) * _done];
private _to = +_full;
_to set [2, (_full select 2) * ([1, 0] select _draining)];
_fill ctrlSetPosition _from;
_fill ctrlCommit 0;
_fill ctrlSetPosition _to;
_fill ctrlCommit _secs;
(_disp displayCtrl 8821) ctrlSetStructuredText parseText ((_blockers apply { localize _x }) joinString "<br/>");

private _end = time + _secs;
waitUntil {
    _line ctrlSetText (if (_draining) then { format [localize "STR_DUWS_T_ZONE_CAPTURE_HALTED", _name] } else {
        format [localize "STR_DUWS_T_ZONE_CAPTURE_COUNTDOWN", _name, ceil ((_end - time) max 0)]
    });
    sleep 0.2;
    // The server sends only on a change, so a player who walks out of the ring would otherwise watch a stale count.
    DUWS_captureBarRun != _run || {time >= _end} || {player distance2D _pos > _ring}
};
if (DUWS_captureBarRun == _run) then { _layer cutText ["", "PLAIN"] };
