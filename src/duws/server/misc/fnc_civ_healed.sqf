// Locality: server -- HandleHeal fires where the healed unit is local, and civilians are the
// server's.
/*
    fnc_civ_healed.sqf
    参数: [_unit, _healer, _isMedic] —— HandleHeal 事件参数
    玩家用原版医疗系统救治平民时，为该城镇加 1 点声望。每个城镇每 30 分钟只计一次。
    返回 false，绝不接管原版治疗流程。

    Listening to the engine rather than offering an action removes the farm the custom heal
    action had: that one credited any civilian, wounded or not, consumed nothing when its 70 %
    roll failed, and drew its FirstAidKits from an arsenal with no limit -- so twenty clicks
    around one town bought the BLUFOR band. Vanilla healing only fires on a unit that is
    actually hurt, and the window below caps what a town can pay out however many are.
*/
params ["_unit", "_healer"];

if (!isServer) exitWith { false };
if (isNull _healer || {!isPlayer _healer}) exitWith { false };

private _idx = _unit getVariable ["civ_locIndex", -1];
if (_idx < 0) exitWith { false };

// Aligned to a 30-minute boundary off mission time, not 30 minutes from this town's last heal.
// Every town therefore rolls over together and in step with the economy ticks, instead of each
// carrying its own drifting clock. HandleHeal can fire more than once for a single treatment,
// which the same window absorbs.
private _window = floor (time / 1800);
private _key = format ["civ_heal_window_%1", _idx];
if ((missionNamespace getVariable [_key, -1]) == _window) exitWith { false };

missionNamespace setVariable [_key, _window];
[_idx, 1, "healed_civilian"] call fnc_town_rep_adjust;
["info", [localize "STR_DUWS_T_rqwho9bq", localize "STR_DUWS_T_civ_rep_up"]]
    remoteExec ["BIS_fnc_showNotification", _healer];

false
