

params ["_side"];

_blu_error = false;
_opf_error = false;

switch (_side) do {

	// CUSTOM BLUFOR
    case "blufor": {

		if (BLUfactionDataTemp != "" && BLUFOR_Faction_X == "CUSTOM") then {
			
			// split input on line breaks
			_splitCarriageReturn = BLUfactionDataTemp splitString toString [13,10];
			
			// only keep lines with "blufor_" variable names
			_keepGoodLines = [];
			{
				if ("blufor_" in _x) then {_keepGoodLines pushback [_x]};
			
			} forEach _splitCarriageReturn;

			_keepGoodLines = flatten _keepGoodLines;
			
			// split goodLines on ";"
			_VarObjectPairs = [];
			{
				_foo = _x splitString ";";
				_VarObjectPairs pushback [_foo];
			} forEach _keepGoodLines;

			_VarObjectPairs = flatten _VarObjectPairs;
			
			// delete _VarObjectPairs with "/"
			{
				if (["/", _x] call BIS_fnc_inString) then {_VarObjectPairs deleteAt _forEachIndex};
			} forEach _VarObjectPairs;
			
			diag_log format ["BLUFOR CUSTOM FACTION: %1", str _VarObjectPairs];

			// compile each "variable = className" pair
			{
				call compile _x;
			} forEach _VarObjectPairs;
			
			// check Config for Rifleman className
			if (!isClass(configFile >> "CfgVehicles" >> blufor_SOLDIER_X)) exitWith {_error = true};
			BLUfactionData = _VarObjectPairs;
			publicVariable "BLUfactionData";
		};
	};
	
	// CUSTOM OPFOR
    case "opfor": {

		if (OPFfactionDataTemp != "" && OPFOR_Faction_X == "CUSTOM") then {
			
			// split input on line breaks
			_splitCarriageReturn = OPFfactionDataTemp splitString toString [13,10];

			// only keep lines with "opfor_" variable names
			_keepGoodLines = [];
			{
				if ("opfor_" in _x) then {_keepGoodLines pushback [_x]};
			
			} forEach _splitCarriageReturn;

			_keepGoodLines = flatten _keepGoodLines;

			// split goodLines on ";"
			_VarObjectPairs = [];
			{
				_foo = _x splitString ";";
				_VarObjectPairs pushback [_foo];
			} forEach _keepGoodLines;

			_VarObjectPairs = flatten _VarObjectPairs;

			// delete _VarObjectPairs with "/"
			{
				if (["/", _x] call BIS_fnc_inString) then {_VarObjectPairs deleteAt _forEachIndex};
			} forEach _VarObjectPairs;
			
			diag_log format ["OPFOR CUSTOM FACTION: %1", str _VarObjectPairs];

			// compile each "variable = className" pair
			{
				call compile _x;
			} forEach _VarObjectPairs;
			
			// check Config for Rifleman className
			if (!isClass(configFile >> "CfgVehicles" >> opfor_SOLDIER_X)) exitWith {_opf_error = true};
			OPFfactionData = _VarObjectPairs;
		};
	};
};

if (_opf_error || _blu_error) exitWith {  
	
	while {true} do {

		if (_blu_error) then {
			[{player globalChat localize "STR_DUWS_T_ow2fwl24"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
		} else {
			[{player globalChat localize "STR_DUWS_T_1vnq5jb7"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
		};
		chosen_settings = false;
		sleep 1;
		forceMap false;
		openMap [false, false];
		sleep 2;
		closeDialog 0;
	};
};

