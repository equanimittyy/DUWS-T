// Locality: server -- the ask-enemy action remoteExecs here.
/*
    fnc_civ_askEnemy_server.sqf
    参数: [_civilian, _caller]
    在服务器上处理打听敌情：检查该城镇声望、掷判定、扣除纸币、挑选附近的红方班组。
    结果交给 fnc_civ_askEnemy_reveal 在询问者本机呈现。
*/
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};

[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_askopforloc"] remoteExec ["fnc_duws_dialogue", _caller];

// The civilian sends its town along, so this is exact rather than a distance test.
private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;

// Movement commands are ignored unless the group is local, and civilians are the server's.
// Running these on the asking client, as this did before the gate moved, was a silent no-op.
private _fnc_runOff = {
    private _runPos = (getPos _civilian) getPos [50 + random 50, random 360];
    _civilian doMove _runPos;
};

_civilian disableAI "PATH";

if (_rep <= 0) exitWith {
    sleep 5;
    _civilian enableAI "PATH";
    call _fnc_runOff;
    ["refuse"] remoteExec ["fnc_civ_askEnemy_reveal", _caller];
};

private _chance = (_rep * 0.1) min 0.7;
sleep 3;
_civilian enableAI "PATH";

if (random 1 >= _chance) exitWith {
    call _fnc_runOff;
    ["fail"] remoteExec ["fnc_civ_askEnemy_reveal", _caller];
};

_caller removeMagazineGlobal "Money_roll";

private _nearEastGroups = allGroups select {
    side _x == EAST &&
    { alive (leader _x) && { (leader _x) distance _caller <= 700 } }
};
if (count _nearEastGroups == 0) exitWith {
    ["none"] remoteExec ["fnc_civ_askEnemy_reveal", _caller];
};

["found", getPos (leader (selectRandom _nearEastGroups))] remoteExec ["fnc_civ_askEnemy_reveal", _caller];
