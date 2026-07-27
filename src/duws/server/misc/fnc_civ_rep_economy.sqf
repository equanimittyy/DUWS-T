// Locality: server -- lifted out of server/misc/fnc_civ_init_Tomata.sqf.
/*
    fnc_civ_rep_economy.sqf
    The civilian background economy loop: a 15-minute CP reward scaled by the campaign-wide
    reputation. It has nothing to do with town placement, which is why it no longer lives in
    civilian init. Launches the thread and returns; safe to `call`. Town Army Power income is
    not here -- it rides the campaign economy tick in server/misc/fnc_zonesundercontrol.sqf so
    the two payouts land on the same clock.

    Passive reputation recovery used to run here and is deliberately gone. Reputation is
    territory now: ground that walks itself back to neutral while the player is elsewhere means
    nothing either side did stays done, and it would fight the OPFOR town capture directly --
    the enemy taking a town and the town un-taking itself fifteen minutes later. Removing it is
    also what bounds the reward loop below, which was an unbounded faucet while something else
    kept pushing reputation back up.
*/
if (!isServer) exitWith {};

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
        };
    };
};
