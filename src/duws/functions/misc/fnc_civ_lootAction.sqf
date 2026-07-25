// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (some callers remoteExec to target 0, others to target 2, so it can run anywhere).
/*
    fnc_civ_lootAction.sqf
    参数: _unit - 平民单位
    为平民添加搜刮动作（喝令举手 + 搜身），由客户端执行，需在所有客户端通过 remoteExec 添加。
    要求：
        - 无声望限制
        - 动作A：50%成功使平民举手并添加动作B；无论成败，声望降低0.5
        - 动作B：概率获得物品并生成在地面，5秒后70%平民武装化转为resistance并攻击发起者
        多人模式兼容：关键游戏状态修改在服务器执行。
        修改：移除所有 CP 奖励，仅产生地面物品。
        修改2：情报物品和电子产品随机掉落指定物品的数量（可能全部掉落，也可能部分掉落）。
*/
params ["_unit"];

if (isNull _unit) exitWith {};

// ========== 辅助函数：移除所有动作（远程执行） ==========
if (isNil "fnc_removeAllActions") then {
    fnc_removeAllActions = {
        params ["_unit"];
        removeAllActions _unit;
    };
    publicVariable "fnc_removeAllActions";
};

// ========== 动作A：喝令举手 ==========
private _actionAID = _unit addAction [
    format ["<t color='#ff0000'>%1</t>", localize "STR_DUWS_T_HANDSUP"],
    {
        params ["_target", "_caller", "_actionId"];
        [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_HANDSUP1"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        
        // 让平民停止移动（临时禁用AI路径）
        _target disableAI "PATH";
        // 移除平民身上所有现有动作
        removeAllActions _target;
        [_target] remoteExec ["fnc_removeAllActions", 0];
        
        // 无论成功失败，声望降低0.5
        // Applied on the server, so _rep is the expected total for the message below
        // rather than a value read back from the global.
        private _rep = (missionNamespace getVariable ["Player_Reputation", 0]) - 0.5;
        [-0.5] remoteExec ["fnc_rep_adjust", 2];
        ["info", [localize "STR_DUWS_T_civloot", format [localize "STR_DUWS_T_civloot2", _rep]]] remoteExec ["BIS_fnc_showNotification", 0];
        sleep 3;
        
        // 90%成功率
        if (random 1 < 0.9) then {
            // 成功：播放举手投降动画
            [_target, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];
            _target setVariable ["isSurrendered", true];
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HANDSUP2"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            
            [localize "STR_DUWS_T_HANDSUP_SUCCESS"] remoteExec ["hint", _caller];
            
            // 添加动作B（搜身）
            [_target] remoteExec ["fnc_civ_lootAction_addActionB", 0];
        } else {
            // 失败：平民逃跑
            _target enableAI "PATH";
            private _runDir = random 360;
            private _runDist = 50 + random 50;
            private _runPos = getPos _target getPos [_runDist, _runDir];
            _target doMove _runPos;
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HANDSUP3"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            [localize "STR_DUWS_T_HANDSUP_FAIL"] remoteExec ["hint", _caller];
            
            // 10秒后恢复AI（如果还活着）
            [_target] spawn {
                params ["_u"];
                sleep 10;
                if (alive _u) then { _u enableAI "PATH"; };
            };
        };
        
        // 移除动作A本身（防止重复点击）
        _target removeAction _actionId;
    },
    nil,
    6,
    true,
    true,
    "",
    format ["_this distance _target < 15 && !(_target getVariable ['isSurrendered', false])"]
];

_unit setVariable ["lootActionA_ID", _actionAID];

// ========== 动作B：搜身（该函数需远程调用添加到平民） ==========
if (isNil "fnc_civ_lootAction_addActionB") then {
    fnc_civ_lootAction_addActionB = {
        params ["_unit"];
        if (isNull _unit) exitWith {};
        
        // 移除可能残留的其他动作
        removeAllActions _unit;
        
        private _actionBID = _unit addAction [
            format ["<t color='#ffaa00'>%1</t>", localize "STR_DUWS_T_LOOT"],
            {
                params ["_target", "_caller", "_actionId"];
                [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT1"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                
                // 移除动作B本身，防止重复搜身
                _target removeAction _actionId;
                
                // 概率决定奖励（仅物品，无CP）
                private _roll = random 1;
                private _items = [];
                private _hintMsg = "";
                sleep 3;
                
                if (_roll < 0.10) then {
                    // 10% 获得情报物品，随机掉落数量（1到3个）
                    private _intelPool = ["Item_Files", "Item_Wallet_traitor", "Item_FlashDisk"];
                    private _dropCount = 1 + floor random (count _intelPool);
                    _items = [];
                    for "_i" from 1 to _dropCount do {
                        _items pushBack (selectRandom _intelPool);
                    };
                    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT2"] remoteExec ["BIS_fnc_showSubtitle", 0];
                    _hintMsg = localize "STR_DUWS_T_LOOT_INTEL";
                } else {
                    if (_roll < 0.30) then {
                        // 15% 获得电子产品，随机掉落数量（1到3个，从包含重复的池中随机抽取）
                        private _elecPool = ["Item_SmartPhone", "Item_MobilePhone", "Item_MobilePhone"];
                        private _dropCount = 1 + floor random (count _elecPool);
                        _items = [];
                        for "_i" from 1 to _dropCount do {
                            _items pushBack (selectRandom _elecPool);
                        };
                        [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT3"] remoteExec ["BIS_fnc_showSubtitle", 0];
                        _hintMsg = localize "STR_DUWS_T_LOOT_ELECTRONICS";
                    } else {
                        if (_roll < 0.60) then {
                            // 30% 获得8个钱币
                            _items = ["Item_Money_roll", "Item_Money_roll", "Item_Money_roll", "Item_Money_roll","Item_Money_roll", "Item_Money_roll", "Item_Money_roll", "Item_Money_roll"];
                            [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT4"] remoteExec ["BIS_fnc_showSubtitle", 0];
                            _hintMsg = localize "STR_DUWS_T_LOOT_MONEY2";
                        } else {
                            if (_roll < 0.85) then {
                                // 25% 获得2个钱币
                                _items = ["Item_Money_roll","Item_Money_roll"];
                                [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT5"] remoteExec ["BIS_fnc_showSubtitle", 0];
                                _hintMsg = localize "STR_DUWS_T_LOOT_MONEY1";
                            } else {
                                // 15% 无奖励
                                _items = [];
                                [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_LOOT6"] remoteExec ["BIS_fnc_showSubtitle", 0];
                                _hintMsg = localize "STR_DUWS_T_LOOT_NOTHING";
                            };
                        };
                    };
                };
                
                // 生成物品（仅在服务器执行以确保全局同步）
                if (count _items > 0) then {
                    [_items, getPosATL _target] spawn {
                        params ["_items", "_basePosATL"];
                        {
                            private _obj = createVehicle [_x, [0,0,0], [], 0, "CAN_COLLIDE"];
                            private _angle = random 360;
                            private _dist = random 1;
                            private _spawnPos = _basePosATL getPos [_dist, _angle];
                            _spawnPos set [2, (_basePosATL select 2) + 0.05];
                            _obj setPos _spawnPos;
                            _obj setDir random 360;
                            _obj enableSimulation true;
                            [_obj] spawn { sleep 60; deleteVehicle (_this select 0); };
                        } forEach _items;
                    };
                };
                
                // 提示玩家
                hint _hintMsg;
                
                // 5秒后判定平民是否武装反抗（需要在服务器执行）
                [_target, _caller] remoteExec ["fnc_civ_lootAction_handleArmed", 2];
                
            },
            nil,
            6,
            true,
            true,
            "",
            format ["_this distance _target < 3 && _target getVariable ['isSurrendered', false]"]
        ];
        _unit setVariable ["lootActionB_ID", _actionBID];
    };
    publicVariable "fnc_civ_lootAction_addActionB";
};

// ========== 服务器端函数：处理武装反抗 ==========
    fnc_civ_lootAction_handleArmed = {
        params ["_unit", "_caller"];
        if (!isServer) exitWith {};
        sleep 5;
        
        // 50%概率且单位存活
        if (random 1 < 0.5 && alive _unit) then {
            // 添加武器（从平民武器池随机选择）
            private _weaponPool = [
                ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
                ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
                ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
                ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
                ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
                ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
                ["hgun_P07_F", "16Rnd_9x21_Mag"],
                ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
            ];
            private _weaponEntry = selectRandom _weaponPool;
            private _weapon = _weaponEntry select 0;
            private _mag = _weaponEntry select 1;
            
            // 移除举手动画（在所有客户端播放）
            [_unit, ""] remoteExec ["switchMove", 0];
            // 转为resistance阵营
            private _oldGroup = group _unit;
            private _newGroup = createGroup resistance;
            [_unit] joinSilent _newGroup;
            if (!isNull _oldGroup && {count units _oldGroup == 0}) then { deleteGroup _oldGroup; };
            
            // 给予武器和弹药
            removeAllWeapons _unit;
            for "_i" from 1 to 3 do { _unit addMagazineGlobal _mag; };
            _unit addWeapon _weapon;
            
            // 设置AI行为并攻击发起搜身的玩家
            _unit setBehaviour "COMBAT";
            _unit setCombatMode "RED";
            _unit enableAI "PATH";
            _unit reveal [_caller, 4];
            _unit doWatch _caller;
            _unit doTarget _caller;
            // 提示（发送给发起者）
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_LOOT_REVENGE"] remoteExec ["BIS_fnc_showSubtitle", 0];
            [localize "STR_DUWS_T_LOOT_REVENGE_HINT"] remoteExec ["hint", 0];
            sleep 2;
            _unit commandFire _caller;
        };
    };
    publicVariable "fnc_civ_lootAction_handleArmed";

// 平民死亡时移除所有动作（防止尸体残留动作）
_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["fnc_removeAllActions", 0];
}];