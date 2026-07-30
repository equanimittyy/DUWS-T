// Locality: server -- clients remoteExec the completed hold action here.
//
// One search per body, for the whole team. The roll and the payout both live here because the
// client cannot be trusted with either: the hold action's remove-on-completion is per machine and
// the flag beneath it was set without the broadcast argument, so in co-op every player searched
// the same corpse for their own reward. A roll a client makes is also a roll a client can retry.
if (!isServer) exitWith {};

params ["_corpse", "_caller", ["_targetPos", []]];
if (isNull _corpse || {isNull _caller}) exitWith {};

// Claimed before the payout resolves, not after: the reveal branch sleeps between its two lines of
// dialogue, and a claim written on the way out would leave that window open to a second searcher.
if (_corpse getVariable ["DUWS_corpse_searched", false]) exitWith {};
_corpse setVariable ["DUWS_corpse_searched", true, true];

private _playerName = name _caller;
private _rand = random 1;

// 60% pays, split between revealing the objective and a flat pool credit. A reveal roll on a
// mission with no target position falls through to the credit rather than returning silently --
// the shape it replaces guarded the whole branch on `count _targetPos == 3` and did nothing at all
// when that failed, so two of the seventeen missions paid at 20% and read as a broken action.
if (_rand < 0.4 && {count _targetPos == 3}) exitWith {
    private _markerName = format ["intel_reveal_%1", round time];
    createMarker [_markerName, _targetPos];
    _markerName setMarkerShape "ICON";
    _markerName setMarkerType "o_unknown";
    _markerName setMarkerColor "ColorRed";
    _markerName setMarkerSize [0.8, 0.8];
    _markerName setMarkerText localize "STR_DUWS_T_INTEL_TARGET";
    [_markerName] spawn { sleep 120; deleteMarker (_this select 0); };
    ["info", [localize "STR_DUWS_T_INTEL_FOUND_TARGETtitle",
        localize "STR_DUWS_T_INTEL_FOUND_TARGETdesc"]] remoteExec ["BIS_fnc_showNotification", 0];
    [_playerName, ([localize "STR_DUWS_T_INTEL_FOUND_TARGET"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    ["INFO", "MISSION", format ["%1 searched a body: objective revealed at %2",
        _playerName, _targetPos]] call fnc_log;
    [] spawn {
        sleep 8;
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_FOUND_TARGET2"] remoteExec ["fnc_duws_dialogue", 0];
    };
};

if (_rand < 0.6) exitWith {
    [1, "corpse_intel"] call fnc_cp_adjust;
    ["BLU", 1, "corpse_intel"] call fnc_ap_adjust;
    [_playerName, localize "STR_DUWS_T_INTEL_FOUND_x"] remoteExec ["fnc_duws_dialogue", 0];
    ["infosearch", [localize "STR_DUWS_T_INTEL_BONUS_TITLE",
        format [localize "STR_DUWS_T_INTEL_BONUS_DESC", 1, 1]]] remoteExec ["BIS_fnc_showNotification", 0];
};

// Spoken to the searcher alone: a body that held nothing is their business, not the team's.
[_playerName, localize "STR_DUWS_T_INTEL_FOUND_n"] remoteExec ["fnc_duws_dialogue", _caller];
