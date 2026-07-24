
_cost = _this select 0;

_target = cursorObject;
if (_target == objNull) exitWith {
	hint localize "STR_DUWS_T_imz98waj";
	[player,"mobile_HQ"] call BIS_fnc_addCommMenuItem;
};

_goodVeh = false;
if (_target isKindOf "car" || _target isKindOf "tank") then {_goodVeh = true};

if (!_goodVeh) exitWith {
	hint localize "STR_DUWS_T_1gk907or";
	[player,"mobile_HQ"] call BIS_fnc_addCommMenuItem;
};

[-_cost] remoteExec ["fnc_cp_adjust", 2];

// Give MHQ a name with public variable
_Varname = "MHQ1";
_target SetVehicleVarName _VarName;
_target Call Compile Format ["%1=_This ; PublicVariable ""%1""",_VarName];

// Create MHQ marker
["select"] remoteExec ["fnc_MHQ_addActions", 2];

// Add Deploy action
["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,true];

// Add flag
MHQ1 forceFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";