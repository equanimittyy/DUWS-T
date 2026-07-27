// Locality: server -- lifted out of server/misc/fnc_civ_init_Tomata.sqf.
/*
    fnc_civ_rep_economy.sqf
    The two civilian background economy loops: reputation recovery after a quiet period, and
    the 15-minute CP reward scaled by reputation. Neither has anything to do with town
    placement, which is why they no longer live in civilian init.
    Launches both threads and returns; safe to `call`.
*/
if (!isServer) exitWith {};

// 声誉恢复线程（保持不变）
[] spawn {
    ["INFO", "CIV", "Reputation recovery thread started"] call fnc_log;
    while {true} do {
        waitUntil {sleep 10; CIV_deaths > 0};
        private _rep = Player_Reputation;
        private _civdeaths = CIV_deaths;
        private _resetTimer = false;
        for "_i" from 1 to 6 do {
            sleep 150;
            if (CIV_deaths > _civdeaths) exitWith {_resetTimer = true};
        };
        if (!_resetTimer) then {
            // The reputation==1 baseline is folded into the condition rather than tested with
            // an early exitWith: exitWith leaves the enclosing while loop, which ended passive
            // recovery for the rest of the campaign the first time reputation returned to 1.
            if (_rep == Player_Reputation && {Player_Reputation != 1}) then {
                // The comparison above needs the live global, so read it before the
                // change is queued; the display then uses the expected total.
                private _expectedRep = Player_Reputation + 1;
                [1, "reputation_recovery"] remoteExec ["fnc_rep_adjust", 2];
                ["repup",[localize "STR_DUWS_T_rqwho9bq",format[localize "STR_DUWS_T_0pluxey2",_expectedRep]]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated,false];
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_repup"] remoteExec ["fnc_duws_dialogue", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                ["INFO", "CIV", format ["Reputation increased to %1", _expectedRep]] call fnc_log;
            };
        };
    };
};

// ========== 声望奖励循环（每15分钟） ==========
[] spawn {
    waitUntil { sleep 1; !isNil "Player_Reputation" };
    sleep 180; // 开局延迟3分钟
    while {true} do {
        sleep 900; // 15分钟
        private _rep = Player_Reputation;
        if (_rep > 0) then {
            private _cpReward = ceil(_rep / 2);
            [_cpReward, "civ_reward"] remoteExec ["fnc_cp_adjust", 2];
            // CP 提醒（使用 cpaddedciv 格式，显示获得的 CP）
            ["CPaddedciv", [_cpReward]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
            [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_cpcivbonus"] remoteExec ["fnc_duws_dialogue", 0];
            [] remoteExec ["fnc_broadcastRadioChatter", 0];
        };
    };
};
