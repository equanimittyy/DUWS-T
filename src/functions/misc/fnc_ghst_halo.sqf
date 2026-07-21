/*
fnc_ghst_halo
--------------
V1.3.2 Script by: Ghost (modified).  
Added support for AI-only HALO (player not included).
Params: [typehalo, althalo, altchute, excludePlayer]
  typehalo: true=group jump (AI), false=single player
  althalo: altitude to start jump
  altchute: auto chute open altitude
  excludePlayer: if true, player does NOT jump (only AI). Requires typehalo=true.
*/

// ========== 定义AI跳伞处理函数（确保服务器可用）==========
DUWS_fnc_aiHalo = {
    params ["_aiNetIds", "_dropPos", "_startAlt", "_chuteAlt"];
    diag_log format ["[DUWS] AI Halo started on server with %1 units", count _aiNetIds];
    private _aiUnits = [];
    {
        private _unit = objectFromNetId _x;
        if (!isNull _unit) then {
            _aiUnits pushBack _unit;
        } else {
            diag_log format ["[DUWS] AI unit with netId %1 is null, skipping", _x];
        };
    } forEach _aiNetIds;

    {
        // 传送 AI 到目标区域上空（不调用 bis_fnc_halo，让它们自然下落）
        private _offsetX = random [10, 50, 100];
        private _offsetY = random [10, 50, 100];
        _x setPos [(_dropPos select 0) + _offsetX, (_dropPos select 1) - _offsetY, _startAlt];
        diag_log format ["[DUWS] AI %1 setPos to %2", _x, getPos _x];
        // 设置无敌
        _x allowDamage false;
    } forEach _aiUnits;

    // 自动开伞监控（直接生成降落伞并强制进入）
    {
        [_x, _chuteAlt] spawn {
            params ["_unit", "_alt"];
            // 等待高度降低到开伞高度
            waitUntil {sleep 0.1; (getPosATL _unit select 2) <= _alt};
            diag_log format ["[DUWS] AI %1 deploying chute via createVehicle and moveInDriver", _unit];
            // 创建降落伞并放置于 AI 当前位置
            private _chute = createVehicle ["Steerable_Parachute_F", (getPosATL _unit), [], 0, "FLY"];
            _chute setPosATL (getPosATL _unit);
            // 降落伞也设置无敌
            _chute allowDamage false;
            // 强制 AI 进入降落伞驾驶员位置
            _unit assignAsDriver _chute;
            _unit moveInDriver _chute;
            // 确保 AI 真正进入（如果 moveInDriver 失败，尝试 moveInAny）
            if (vehicle _unit != _chute) then {
                _unit moveInAny _chute;
            };
            // 等待落地，然后恢复伤害允许
            waitUntil {sleep 0.1; (getPosATL _unit select 2) < 2};
            // 恢复单位伤害允许
            if (alive _unit) then {
                _unit allowDamage true;
            };
            // 恢复降落伞伤害允许（如果还存在）
            if (!isNull _chute) then {
                _chute allowDamage true;
            };
        };
    } forEach _aiUnits;
    diag_log "[DUWS] AI Halo processing complete";
};

// 公开函数以便 remoteExec 调用
publicVariable "DUWS_fnc_aiHalo";

// ========== 主逻辑 ==========
_host = _this select 0;
_caller = _this select 1;
_id = _this select 2;
_params = _this select 3;

_params params [
    ["_typehalo", false, [true, false, 0]],
    ["_althalo", 600, [0]],
    ["_altchute", 70, [0]],
    ["_excludePlayer", false, [true, false]]
];
if (_typehalo isEqualType 0) then { _typehalo = _typehalo > 0; };

if (not alive _host) exitwith {
    hint localize "STR_DUWS_T_royy580r"; 
    _host removeaction _id;
};

_caller groupchat localize "STR_DUWS_T_vtkkn80v";

// 保存玩家负载并打开地图
openMap true;
player setVariable["Saved_Loadout", getUnitLoadout player];
mapclick = false;
onMapSingleClick "clickpos = _pos; mapclick = true; onMapSingleClick """";true;";
waituntil {mapclick or !(visiblemap)};
if (!visibleMap) exitwith {
    _caller groupchat localize "STR_DUWS_T_q639bywa";
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
};
_pos = clickpos;

// ========== AI 跳伞处理 ==========
if (_typehalo) then {
    private _aiUnits = (units group _caller) select {
        isNull objectParent _x && {!isPlayer _x}
    };
    if (count _aiUnits > 0) then {
        private _aiNetIds = _aiUnits apply {netId _x};
        diag_log format ["[DUWS] Client sending AI Halo request for %1 units", count _aiNetIds];
        if (isServer) then {
            // 单机模式，直接调用
            [_aiNetIds, _pos, _althalo, _altchute] call DUWS_fnc_aiHalo;
        } else {
            // 多人模式，发送给服务器
            [_aiNetIds, _pos, _althalo, _altchute] remoteExec ["DUWS_fnc_aiHalo", 2];
        };
    } else {
        diag_log "[DUWS] No AI units to jump";
    };
};

// ========== 玩家跳伞 ==========
if (!_excludePlayer) then {
    _caller setpos [(_pos select 0)+30, _pos select 1, _althalo];
    titleCut ["", "BLACK IN", 5];
    openMap false;

    _bis_fnc_halo_action = _caller addaction [localize "STR_DUWS_T_bd22lcos","A3\functions_f\misc\fn_HALO.sqf",[],1,true,true,"Eject"];
    sleep 5;
    _caller groupchat localize "STR_DUWS_T_sjk84cdc";

    waituntil {sleep 0.1;(position _caller select 2) <= _altchute};
    _caller removeaction _bis_fnc_halo_action;

    if ((vehicle _caller) iskindof "ParachuteBase") exitwith {
        waitUntil {sleep 0.1;isTouchingGround player};
        player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
    };

    _caller groupchat localize "STR_DUWS_T_o3yt6tzg";
    [_caller] spawn bis_fnc_halo;

    waitUntil {sleep 0.1;isTouchingGround player};
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
} else {
    player setUnitLoadout(player getVariable["Saved_Loadout",[]]);
    openMap false;
};