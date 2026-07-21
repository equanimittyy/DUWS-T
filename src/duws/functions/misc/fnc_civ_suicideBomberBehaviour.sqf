// fnc_civ_suicideBomberBehaviour.sqf
if (!isServer) exitWith {};
params ["_unit"];

_unit setVariable ["isSuicideBomber", true, true];
_unit setVariable ["isHostile", false, true];  // 初始为 false，击杀会触发声望惩罚
_unit setBehaviour "CARELESS";
_unit setCombatMode "BLUE";
_unit allowFleeing 0;
_unit setUnitPos "UP";
_unit setVariable ["Vcm_Disable", true]; // 若使用VCOM AI则禁用

removeAllActions _unit;
[_unit] remoteExec ["removeAllActions", 0];

private _speedModes = ["LIMITED", "NORMAL", "FULL"];
private _selectedSpeed = selectRandom _speedModes;
_unit setSpeedMode _selectedSpeed;

while {alive _unit} do {
    private _players = allPlayers select { alive _x };
    if (count _players > 0) then {
        private _nearestPlayer = [_players, _unit] call BIS_fnc_nearestPosition;
        private _dist = _unit distance _nearestPlayer;

        if (_dist <= 10) then {
            // 距离 ≤ 10米：转为EAST阵营，标记为敌对，不再随机移动
            if (side _unit != EAST) then {
                private _oldGroup = group _unit;
                private _newGroup = createGroup EAST;
                [_unit] joinSilent _newGroup;
                if (!isNull _oldGroup && {count units _oldGroup == 0}) then { deleteGroup _oldGroup; };
                _unit setVariable ["isHostile", true, true]; // 标记敌对，击杀不再惩罚
                _unit setBehaviour "COMBAT";
                _unit setCombatMode "RED";
                // 保持随机速度，不强制FULL
            };

            if (_dist <= 5) then {
                // 引爆：广播给所有玩家（本地化消息）
                [localize "STR_DUWS_T_SUICIDE_BOMB_DETONATED"] remoteExec ["hint", 0];
                private _bomb = createVehicle ["Bo_GBU12_LGB", getPos _unit, [], 0, "CAN_COLLIDE"];
                private _handler = missionNamespace getVariable "CIV_KILLED_HANDLER";
                [_unit, objNull, objNull] call _handler;
            } else {
                _unit doMove (getPos _nearestPlayer);
            };
        } else {
            // 距离 >10米：平民阵营，有10%概率随机移动，90%概率向玩家移动
            if (random 1 < 0.1) then {
                // 随机移动：选择一个随机方向50-200米的点
                private _randomPos = getPos _unit getPos [50 + random 150, random 360];
                _unit doMove _randomPos;
            } else {
                _unit doMove (getPos _nearestPlayer);
            };
        };
    };
    sleep 0.5;
};