
// SET OPFOR AI AIM to 0.2
// REARM/REFUEL OPFOR VEHICLES & UNITS EVERY 10min
if (!isServer) exitWith {};
[] spawn {
	while {true} do {
		// One pass over each set instead of collecting into an array and walking it again, and
		// the skill applied only to units that have not had it. The value never varies, so
		// re-applying it every cycle was an engine call per enemy on the map for no state change;
		// the ammo top-up is what the cycle exists for and stays unconditional.
		// EAST UNITS
		{
			if ((side _x) == EAST) then {
				if !(_x getVariable ["DUWS_aimSkillSet", false]) then {
					_x setSkill ["aimingaccuracy", 0.2];
					_x setVariable ["DUWS_aimSkillSet", true];
				};
				_x setVehicleAmmo 1;
			};
		} forEach allUnits;

		// Holds the cycle at the 610 s the two collect-then-apply pauses added up to.
		sleep 10;

		// EAST VEHICLES with drivers
		{
			if ((side _x) == EAST && alive driver _x) then {
				_x setFuel 1;
				_x setVehicleAmmo 1;
			};
		} forEach vehicles;

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


