
// SET OPFOR AI AIM to 0.2
// SET OPFOR/BLUFOR VEHICLES/UNITS REARM/REFUEL EVERY 10min
//  - only vehicles & units not part of player groups
if (!isServer) exitWith {};
[] spawn {
	while {true} do {
		_eastUnits = [];
		_eastVehicles = [];
		_westVehicles_temp = [];
		_westAI_VehUnits = [];
		_westUnits_temp = [];
			
		// EAST & WEST UNITS
		{
			if ((side _x) == EAST) then {
				_eastUnits pushBack _x;
			};
			if ((side _x) == WEST) then {
				_westUnits_temp pushBack _x;
			};
		} forEach allUnits;
	
		// SET EAST UNITS
		{
			_x setSkill ["aimingaccuracy", 0.2];
			_x setVehicleAmmo 1;
		} forEach _eastUnits;

		sleep 5;
			
		// FIND VEHICLES with drivers
		{
			if ((side _x) == EAST && alive driver _x) then {
				_eastVehicles pushBack _x;
			};
			if ((side _x) == WEST && alive driver _x) then {
				_westVehicles_temp pushBack _x;
			};
		} forEach vehicles;
			
		sleep 5;

		// EAST VEHICLES
		{
			if ((side _x) == EAST) then {
				_x setFuel 1;
				_x setVehicleAmmo 1;
			};
		} forEach _eastVehicles;

		sleep 5;

		// WEST VEHICLES and UNITS
		// only vehicles & units not part of player groups
		{
			_veh = _x;
			{
				if (leader _veh == _x) exitWith {};  
				_westAI_VehUnits pushback _veh;
			} foreach call BIS_fnc_ListPlayers;
		} forEach _westVehicles_temp + _westUnits_temp;

		sleep 600;
	};
};

// Reset TF waypoints every 30 min
// and nudge any vehicles that have "stalled"
[] spawn {
	
	while {true} do {
		BLUFOR_primary_chg = true;publicVariable "BLUFOR_primary_chg";
		//wait until the gps loops (4sec) finish
		sleep 4.1;
		BLUFOR_primary_chg = false;publicVariable "BLUFOR_primary_chg";
		sleep 1800;
	};
};


