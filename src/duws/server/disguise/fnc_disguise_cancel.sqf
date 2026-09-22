// Locality: server. The player takes the disguise off, so no cooldown stamp; the monitor sees the flag
// drop at its next tick and restores the captive state.
params ["_player"];
if (isNull _player) exitWith {};
if !(_player getVariable ["DUWS_disguised", false] || {_player getVariable ["DUWS_enemyDisguised", false]}) exitWith {};

_player setVariable ["DUWS_disguised", false, true];
_player setVariable ["DUWS_enemyDisguised", false, true];
[localize "STR_DUWS_T_DISGUISE_ENDED_CANCEL"] remoteExec ["hint", _player];
