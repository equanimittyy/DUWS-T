
// SET OPFOR AI AIM to 0.2
// REARM/REFUEL OPFOR VEHICLES & UNITS EVERY 10min
if (!isServer) exitWith {};

// How far from a player an enemy has to be for a resupply to mean anything. Generous on purpose --
// a unit wants its ammo back well before it can be engaged, and being generous costs nothing here
// because the query is one per player rather than one per unit.
#define RESUPPLY_RADIUS 1200

[] spawn {
	while {true} do {
		// Map-wide but one-shot: the aim value never varies, so a unit that has taken it is skipped
		// and what remains is an array walk rather than an engine call per enemy alive. Kept
		// map-wide rather than folded into the proximity pass below because a unit has to be
		// carrying its skill before anyone reaches it, and this cycle is ten minutes long.
		{
			if ((side _x) == EAST && {!(_x getVariable ["DUWS_aimSkillSet", false])}) then {
				_x setSkill ["aimingaccuracy", 0.2];
				_x setVariable ["DUWS_aimSkillSet", true];
			};
		} forEach allUnits;

		// Holds the cycle at the 610 s the two collect-then-apply pauses added up to.
		sleep 10;

		// Anchored on players off the spatial index rather than swept map-wide. Rearming an enemy
		// nobody can reach demonstrates nothing, and the sweep this replaces called setVehicleAmmo
		// and setFuel for every OPFOR unit and vehicle in the campaign every ten minutes -- a cost
		// that grew with the campaign to keep ammo in guns no player was near.
		private _near = [];
		{
			_near append (_x nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], RESUPPLY_RADIUS]);
		} forEach (call BIS_fnc_listPlayers);
		// Players standing together return each other's neighbours, and a top-up applied twice is
		// two engine calls for one result.
		_near = _near arrayIntersect _near;

		{
			if ((side _x) == EAST) then {
				if (_x isKindOf "CAManBase") then {
					_x setVehicleAmmo 1;
				} else {
					// Crewed only, as before: an abandoned vehicle is not a threat to resupply.
					if (alive driver _x) then {
						_x setFuel 1;
						_x setVehicleAmmo 1;
					};
				};
			};
		} forEach _near;

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


