// Locality: client, remoteExec'd by DUWS_fnc_siteTakeTell. _left -1 means the hold broke on the _blocker test.
// A HUD layer, not the hint box: the count runs under the fight, and the flag's refusal must stay readable over it.
params ["_key", "_name", "_left", "_hold", "_blocker"];
if (!hasInterface) exitWith {};

// A player can stand in two zones' rings, so a break ends only the count it belongs to.
if (_left < 0 && {(missionNamespace getVariable ["DUWS_captureBarKey", ""]) isNotEqualTo _key}) exitWith {};
DUWS_captureBarKey = _key;
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
private _empty = +_full;

if (_left < 0) then {
    // Emptied, not frozen: a break restarts the whole count.
    _empty set [2, 0];
    _fill ctrlSetPosition _empty;
    _fill ctrlCommit 0;
    _line ctrlSetText format [localize "STR_DUWS_T_ZONE_CAPTURE_HALTED", _name, localize _blocker];
    sleep 5;
} else {
    _empty set [2, (_full select 2) * (1 - _left / _hold)];
    _fill ctrlSetPosition _empty;
    _fill ctrlCommit 0;
    _fill ctrlSetPosition _full;
    _fill ctrlCommit _left;
    private _end = time + _left;
    waitUntil {
        _line ctrlSetText format [localize "STR_DUWS_T_ZONE_CAPTURE_COUNTDOWN", _name, ceil ((_end - time) max 0)];
        sleep 0.2;
        DUWS_captureBarRun != _run || {time >= _end}
    };
};
if (DUWS_captureBarRun == _run) then { _layer cutText ["", "PLAIN"] };
