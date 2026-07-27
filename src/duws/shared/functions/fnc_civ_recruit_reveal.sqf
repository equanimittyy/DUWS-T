// Locality: the recruiting player's machine -- the server remoteExecs the outcome here.
/*
    fnc_civ_recruit_reveal.sqf
    参数: [_outcome]
    呈现招募失败的结果。成功路径不经过这里：fnc_recruitSuccessServer 自己通知玩家。
*/
params ["_outcome"];

if (!hasInterface) exitWith {};

switch (_outcome) do {
    case "refuse": {
        hint (localize "STR_DUWS_T_RECRUIT_FAIL_REP_HINT");
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_FAIL_REP"] call fnc_duws_dialogue;
    };
    case "fail": {
        hint (localize "STR_DUWS_T_RECRUIT_FAIL_HINT");
        [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_FAIL"] call fnc_duws_dialogue;
    };
};
