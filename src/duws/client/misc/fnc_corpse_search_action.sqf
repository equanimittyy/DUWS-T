/*
    fnc_corpse_search_action.sqf
    在尸体上添加长按搜身获取情报的动作
    参数: _netId (尸体网络ID)
*/
if (!hasInterface) exitWith {};

params ["_netId"];
private _corpse = objectFromNetId _netId;
if (isNull _corpse) exitWith {};

if (_corpse getVariable ["corpse_search_action_added", false]) exitWith {};
_corpse setVariable ["corpse_search_action_added", true];

// Sampled when the body is armed, not when it is searched: the mission that produced this corpse
// may well have ended by then, and fnc_mission_end clears the global on the way out. Carried into
// the action's own argument array below, which is what the completion block reads.
private _targetPos = missionNamespace getVariable ["current_mission_target_pos", []];

// 添加长按动作
[
    _corpse,                                                            // 目标对象
    localize "STR_DUWS_T_SEARCH_CORPSE_ACTION",                                // 动作标题
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",      // 空闲图标
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",      // 进度图标
    // The claim is broadcast from the server, so the entry disappears on every machine once anyone
    // has searched this body -- one search per corpse for the whole team, not one per player.
    "_this distance _target < 3 && !(_target getVariable ['DUWS_corpse_searched', false])",
    "_caller distance _target < 3",                                     // 进度条件
    {                                                                   // 开始代码
        params ["_target", "_caller", "_actionId", "_arguments"];
        private _playerName = name _caller;
        [_playerName, localize "STR_DUWS_T_SEARCH_START_SUBTITLE"] remoteExec ["fnc_duws_dialogue", _caller];
    },
    {},                                                                 // 每帧代码
    {                                                                   // 完成代码
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_targetPos"];
        // The roll and the payout are the server's: a roll made here is a roll a client can retry,
        // and the claim that makes a body single-use has to be authoritative to be worth anything.
        [_target, _caller, _targetPos] remoteExec ["fnc_corpse_search_claim", 2];
    },
    {},                                                                 // 中断代码
    [_targetPos],                                                       // 传递参数
    2,                                                                  // 持续时间（秒）
    30,                                                                  // 优先级
    true,                                                               // 完成后移除
    false                                                               // 不在昏迷状态显示
] call BIS_fnc_holdActionAdd;

["INFO", "MISSION", format ["HoldAction added to corpse %1", _corpse]] call fnc_log;
