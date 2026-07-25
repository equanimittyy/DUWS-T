// Locality: server -- inherited from server/misc/fnc_civ_handler.sqf.
// fnc_civ_rep_Tomata.sqf (修复版：避免在事件上下文中直接 sleep)
if (!canSuspend) exitWith {
    _this spawn fnc_civ_rep_Tomata;
};

_unit   = _this select 0;
_killer = _this select 1;
_instigator = _this select 2;

// 丧尸/WBK模式不处理
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

// 有50%概率不受惩罚
if (random 10 < 5) exitWith {};

// 必须有玩家在附近（200米内）
private _players_close = false;
{
    if ((_x distance _unit) < 200) exitWith { _players_close = true };
} forEach call BIS_fnc_ListPlayers;

if (!_players_close) exitWith {};

// 蓝方击杀 → 扣声望
if (side _killer == WEST || side _instigator == WEST) then {
    [-0.3, "civilian_harmed"] remoteExec ["fnc_rep_adjust", 2];
    ["info", [
        localize "STR_DUWS_T_cycuqbvj",
        format [localize "STR_DUWS_T_0pluxey2", Player_Reputation - 0.3]
    ]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];

    // 增加平民死亡计数（立即，无需延时）
    CIV_deaths = CIV_deaths + 1;
    publicVariable "CIV_deaths";
};