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

// 只有30%的死亡会被计入。The roll can sit this low because reputation is localised now: a bad
// engagement costs the campaign nothing outside the town it happened in, and the roll is what
// stops a firefight in a populated town turning it over on stray rounds.
if (random 10 < 7) exitWith {};

// 必须有玩家在附近（200米内）
if !([getPos _unit] call fnc_civ_playerNear) exitWith {};

// 蓝方击杀 → 扣该城镇声望。No total is printed: the caller cannot know what the writer's clamp
// will actually apply, and the town marker carries the figure.
if (side _killer == WEST || side _instigator == WEST) then {
    [_unit getVariable ["civ_locIndex", -1], -1, "civilian_harmed"] call fnc_town_rep_adjust;
    ["info", [
        localize "STR_DUWS_T_cycuqbvj",
        localize "STR_DUWS_T_civ_rep_down"
    ]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
};