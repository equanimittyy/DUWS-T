// Locality: client -- invoked from a comm-menu expression (shared/includes/supports_radio_modern.hpp).
//
// Calling this does not consume the entry (removeAfterExpressionCall = 0), so none of the refusals
// below hands it back. Three of the four outcomes here are refusals the player is meant to act on
// straight away -- nothing under the cursor, wrong kind of vehicle, one already assigned -- and an
// entry that vanished on each of them made a permanent team unlock behave like a spent charge.

_target = cursorObject;

// One MHQ at a time. Every player carries the designation entry, so without this the second
// SetVehicleVarName repoints MHQ1 at a new vehicle while the first keeps its actions -- leaving a
// deploy action and a respawn point acting on globals describing something else. Tested with alive,
// not isNil: fnc_MHQ_destroyed leaves the dead object in the variable.
//
// hintC rather than hint: this one has to be read. A corner hint competes with whatever notification
// the player is already looking at, and the refusal has to teach two verbs rather than report a
// failure. Pointing at the current MHQ is the likeliest way to arrive here and gets its own line,
// because answering that with the general one-at-a-time rule reads as the mission not knowing what
// the player is looking at.
if (!isNil "MHQ1" && {alive MHQ1}) exitWith {
	hintC localize (["STR_DUWS_T_mhq_exists", "STR_DUWS_T_mhq_is_this"] select (_target == MHQ1));
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