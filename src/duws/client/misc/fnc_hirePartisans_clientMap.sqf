// fnc_hirePartisans_clientMap.sqf
// 客户端执行：打开地图选择游击队部署位置，强制无法关闭地图
if (!hasInterface) exitWith {};

params ["_caller", "_count"];

// 防止重复打开地图
if (!isNil "hirePartisans_mapOpen" && {hirePartisans_mapOpen}) exitWith {
    hint "You are already placing a partisan squad.";
};
hirePartisans_mapOpen = true;

// 将参数存入玩家变量（作为全局传递桥梁）
player setVariable ["DUWS_partisan_caller", _caller];
player setVariable ["DUWS_partisan_count", _count];

private _got = ["PARTISANS", {
    params ["_pos"];
    ["PARTISANS"] call fnc_mapclick_release;
    openMap false;
    hirePartisans_mapOpen = false;

    // 直接从玩家变量取值，避免 spawn 参数传递问题
    [_pos] spawn {
        params ["_pos"];
        private _caller = player getVariable "DUWS_partisan_caller";
        private _count  = player getVariable "DUWS_partisan_count";
        player setVariable ["DUWS_partisan_caller", nil];
        player setVariable ["DUWS_partisan_count", nil];
        sleep 0.3;
        [_caller, _pos, _count] remoteExec ["fnc_hirePartisans_spawnDeployed", 2];
    };
    true;
}] call fnc_mapclick_claim;
// The flag is raised above this point, so a refused claim has to lower it again or the action
// stays permanently "already placing a squad".
if (!_got) exitWith { hirePartisans_mapOpen = false; };

openMap true;
// Drawn on the map, not hinted: the hint box renders beneath the map display, so this
// instruction was issued one line before the map covered it and never reached the player --
// who was then held in a map that refuses to close, with nothing saying why.
["Click on the map to deploy your partisans. You cannot close the map until you choose a location."] call fnc_map_prompt;

// 强制保持地图打开，直到点击
while {hirePartisans_mapOpen} do {
    if (!visibleMap) then {
        openMap true;
    };
    sleep 0.1;
};