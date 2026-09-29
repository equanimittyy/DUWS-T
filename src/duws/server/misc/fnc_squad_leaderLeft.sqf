// Locality: server -- spawned by the HandleDisconnect handler in server/server_init.sqf when a player
// leaves as the leader of a squad that holds AI.
params ["_group", "_leaver"];

// At HandleDisconnect the leaver still leads the group; it passes on once their body is deleted (disabledAI = 1).
while {!(["SQUAD", "a departed squad leader's body to be deleted", { isNull _leaver }, 60] call fnc_waitLogged)} do {};
if (isNull _group || {isPlayer leader _group}) exitWith {};

private _humans = (units _group) select { isPlayer _x };
if (_humans isNotEqualTo []) exitWith {
	[_group, _humans select 0] remoteExec ["selectLeader", groupOwner _group];
};

// An escort stays for its mission: a deleted escort reads as a dead one and fails it.
{ _x setVariable ["DUWS_binMe", true] } forEach ((units _group) select { !(_x getVariable ["DUWS_escort", false]) });
