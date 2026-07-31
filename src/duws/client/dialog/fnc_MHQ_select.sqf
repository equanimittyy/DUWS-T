// Locality: client -- invoked from a comm-menu expression (shared/includes/supports_radio_modern.hpp).
//
// Calling this does not consume the entry (removeAfterExpressionCall = 0), so none of the refusals
// below hands it back. All of them are things the player is meant to act on straight away --
// nothing under the cursor, wrong kind of vehicle, one already assigned, one lost too recently --
// and an entry that vanished on each of them made a slot the player is holding behave like a
// spent charge.
//
// Every refusal is a corner hint. hintC was tried for the one-already-assigned case on the grounds
// that it has to be read, and it is the wrong tool: it opens a modal the player has to dismiss
// mid-firefight to get their controls back, which is a heavier interruption than anything a
// refusal warrants.

_target = cursorObject;

// One MHQ at a time. Any squad leader can hold the designation slot, so without this the second
// SetVehicleVarName repoints MHQ1 at a new vehicle while the first keeps its actions -- leaving a
// deploy action and a respawn point acting on globals describing something else. Tested with alive,
// not isNil: fnc_MHQ_destroyed leaves the dead object in the variable.
//
// Pointing at the current MHQ gets its own line, because answering that with the general
// one-at-a-time rule reads as the mission not knowing what the player is looking at.
if (!isNil "MHQ1" && {alive MHQ1}) exitWith {
	hint localize (["STR_DUWS_T_mhq_exists", "STR_DUWS_T_mhq_is_this"] select (_target == MHQ1));
};

// Losing the Mobile HQ costs the team half an hour of it. Without this, designating is free the
// instant the last one burns, so parking the MHQ forward and letting it die is strictly cheaper
// than driving it home -- the one thing a mobile respawn must not reward.
private _until = missionNamespace getVariable ["MHQ_lockout_until", 0];
if (time < _until) exitWith {
	hint format [localize "STR_DUWS_T_MHQ_LOCKOUT", ceil ((_until - time) / 60)];
};

if (_target == objNull) exitWith { hint localize "STR_DUWS_T_imz98waj" };

_goodVeh = false;
if (_target isKindOf "car" || _target isKindOf "tank") then {_goodVeh = true};

if (!_goodVeh) exitWith { hint localize "STR_DUWS_T_1gk907or" };

// Give MHQ a name with public variable
_Varname = "MHQ1";
_target SetVehicleVarName _VarName;
_target Call Compile Format ["%1=_This ; PublicVariable ""%1""",_VarName];

// Create MHQ marker
["select"] remoteExec ["fnc_MHQ_addActions", 2];

// Add Deploy action
["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,"duws_mhq_actions"];

// Add flag
MHQ1 forceFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
