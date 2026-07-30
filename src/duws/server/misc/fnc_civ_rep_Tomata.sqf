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

// 必须有玩家在附近（200米内）
// Presence is the whole gate now. A 30 % roll used to sit in front of it, so a player shooting
// civilians deliberately saw nothing happen most of the time -- which reads as a broken system,
// not as leniency. Same 200 m the building charge uses: both mean one thing by "player involved".
if !([getPos _unit] call fnc_civ_playerNear) exitWith {};

// 蓝方击杀 → 扣该城镇声望。The writer announces the change and owns the clamp, so nothing is
// printed here: the caller cannot know what will actually be applied.
if (side _killer == WEST || side _instigator == WEST) then {
    [_unit getVariable ["civ_locIndex", -1], -1, "civilian_harmed"] call fnc_town_rep_adjust;
};