// Locality: server -- the recruit action remoteExecs here.
/*
    fnc_civ_recruit_server.sqf
    参数: [_civilian, _caller]
    在服务器上处理招募判定：检查该城镇声望、掷判定。
    成功则交给 fnc_recruitSuccessServer，失败由 fnc_civ_recruit_reveal 在招募者本机呈现。
*/
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};

// Exact, not a distance test: the civilian carries the town it was spawned into.
private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;

// doMove is ignored unless the group is local, and civilians belong to the server. Running it
// on the recruiting client, as this did before the gate moved, was a silent no-op.
private _fnc_runOff = {
    _civilian doMove ((getPos _civilian) getPos [50 + random 50, random 360]);
};

if (_rep <= 0) exitWith {
    call _fnc_runOff;
    ["refuse"] remoteExec ["fnc_civ_recruit_reveal", _caller];
};

// 每点声望10%，最高70%
private _chance = (_rep min 7) * 0.1;
if (random 1 >= _chance) exitWith {
    call _fnc_runOff;
    ["fail"] remoteExec ["fnc_civ_recruit_reveal", _caller];
};

// fnc_recruitSuccessServer clears captive and broadcasts it itself, so the client-side
// setCaptive and fnc_globalSetCaptive pair this replaces was doing the work twice.
[_civilian, _caller, netId _civilian] call fnc_recruitSuccessServer;
