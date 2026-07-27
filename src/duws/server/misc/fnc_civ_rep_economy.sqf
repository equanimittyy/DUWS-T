// Locality: server -- lifted out of server/misc/fnc_civ_init_Tomata.sqf.
/*
    fnc_civ_rep_economy.sqf
    The two civilian background economy loops: a 15-minute CP reward scaled by the campaign-wide
    reputation, and a 30-minute Army Power tick paid by towns in either ownership band. Neither
    has anything to do with town placement, which is why they no longer live in civilian init.
    Launches both threads and returns; safe to `call`.

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

// ========== 城镇军力收入（每30分钟） ==========
// Same cadence as the territory-hold CP tick in fnc_zonesundercontrol.sqf, so the two land
// together and the marker's "/30min" stays honest.
[] spawn {
    while {true} do {
        sleep 1800;
        private _reps = missionNamespace getVariable ["civ_town_rep", []];
        private _worth = missionNamespace getVariable ["civ_town_ap", []];
        private _blu = 0;
        private _opf = 0;
        {
            private _ap = _worth param [_forEachIndex, 0];
            if (_x >= 10) then { _blu = _blu + _ap };
            if (_x <= -10) then { _opf = _opf + _ap };
        } forEach _reps;
        // Two calls, not one per town: fnc_ap_adjust publicVariables and logs every time, so
        // per-town calls would broadcast the same global twenty times a tick for one net change.
        if (_blu > 0) then { ["BLU", _blu, "civ_town_income"] call fnc_ap_adjust };
        if (_opf > 0) then { ["OPF", _opf, "civ_town_income"] call fnc_ap_adjust };
    };
};
