// Locality: client -- invoked from a comm-menu expression (shared/includes/supports_radio_modern.hpp:209).


// One MHQ at a time. Two players can each be holding an unspent designation token, and without
// this the second SetVehicleVarName repoints MHQ1 at a new vehicle while the first keeps its
// actions -- leaving a deploy action and respawn point acting on globals describing something
// else. Tested with alive, not isNil: fnc_MHQ_destroyed leaves the dead object in the variable.
// hintC rather than hint: this one has to be read. A corner hint competes with whatever notification
// the player is already looking at, and the refusal has to explain a rule -- one MHQ, freed only by
// losing it -- rather than just report a failure.
if (!isNil "MHQ1" && {alive MHQ1}) exitWith {
	hintC localize "STR_DUWS_T_mhq_exists";
	["mobile_HQ"] call fnc_support_comm_add;
};

_target = cursorObject;
if (_target == objNull) exitWith {
	hint localize "STR_DUWS_T_imz98waj";
	["mobile_HQ"] call fnc_support_comm_add;
};

_goodVeh = false;
if (_target isKindOf "car" || _target isKindOf "tank") then {_goodVeh = true};

if (!_goodVeh) exitWith {
	hint localize "STR_DUWS_T_1gk907or";
	["mobile_HQ"] call fnc_support_comm_add;
};


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