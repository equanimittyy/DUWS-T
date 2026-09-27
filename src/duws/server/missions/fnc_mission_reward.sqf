// Locality: server -- all 20 callers are mission threads running server-side, and it
// credits the shared CP and AP pools, so it must stay that way.

_cpreward = _this select 0;
_apreward = _this select 1;
_mission_name = _this select 2;

// Civilians off, RAVAGE and WBK register no town reputation, which zeroes BLUFOR's passive CP
// town faucet (server/warcom/fnc_zonesundercontrol.sqf). Missions exist in every configuration, so
// the substitute rides them: mission CP lifts when the faucet is absent, restoring its rough share
// through a route that is always there. Gated on civ_town_rep being empty, not on the mode name, so
// a fourth mode added later inherits it. BLUFOR only -- OPFOR keeps its OPCOM drip and a symmetric
// lift would over-pay it; AP is untouched, coming from zones every configuration has.
private _civsOffLift = if ((count (missionNamespace getVariable ["civ_town_rep", []])) == 0) then { 1.5 } else { 1 };
// Difficulty bonus: the hard offers -- seated deep in enemy territory -- carry a per-mission multiplier
// (1.5x-2x, scaled by depth) set by name at request time (client/missions/fnc_stratmap.sqf). Unlike the
// civs-off lift this is a worth multiplier on the mission itself, so it scales both currencies.
// DUWS_rewardBoost holds [name, multiplier] pairs; an absent list or an easy (unlisted) mission pays flat.
private _difficultyMult = 1;
if (!isNil "DUWS_rewardBoost") then {
	private _i = DUWS_rewardBoost findIf {(_x select 0) isEqualTo _mission_name};
	if (_i >= 0) then { _difficultyMult = (DUWS_rewardBoost select _i) select 1 };
};
// One floor over the whole multiplier stack: the payout always rounds down, difficulty bonus included.
_cp_multiplied_reward = floor (_cpreward * cp_reward_multiplier * _civsOffLift * _difficultyMult);
// The player's reward multiplier scales both mission currencies, so one campaign knob governs CP and
// AP payouts alike. The civs-off lift is not applied to AP: it substitutes for the absent town-CP
// faucet, and AP already comes from zones in every configuration.
_ap_multiplied_reward = floor (_apreward * cp_reward_multiplier * _difficultyMult);
["INFO", "MISSION", format ["'%1' succeeded, paying %2 CP and %3 AP",
	_mission_name, _cp_multiplied_reward, _ap_multiplied_reward]] call fnc_log;
[_cp_multiplied_reward, format ["mission %1", _mission_name]] remoteExec ["fnc_cp_adjust", 2];

// Missions are a faucet BLUFOR earns, so the whole AP reward credits the tier counter (4th arg).
["BLU", _ap_multiplied_reward, format ["mission %1", _mission_name], _ap_multiplied_reward] remoteExec ["fnc_ap_adjust", 2];

[] spawn fnc_operative_mission_complete;

sleep 10;
["cpaddedmission",[_cp_multiplied_reward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
["apaddedmission",[_ap_multiplied_reward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
