
if (!isServer) exitWith {};

// How far from a player an enemy has to be for a resupply to mean anything. Generous on purpose --
// a unit wants its ammo back well before it can be engaged, and being generous costs nothing here
// because the query is one per player rather than one per unit.
#define RESUPPLY_RADIUS 1200

[] spawn {
	while {true} do {
		// A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
		try {
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
		// nobody can reach demonstrates nothing, and a full-map setVehicleAmmo/setFuel over every
		// OPFOR unit and vehicle every ten minutes is a cost that grows with the campaign to keep
		// ammo in guns no player is near.
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
		} catch {
			["ERROR", "AI", format ["AI master tick threw, thread held alive: %1", _exception]] call fnc_log;
			sleep 10;
		};
	};
};



