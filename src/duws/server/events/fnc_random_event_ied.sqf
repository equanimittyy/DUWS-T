// Locality: server -- roadside IEDs, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town against the player.
//
// A loose scatter of identical junk piles on roads across a wide area ahead of the player, at least MIN_DIST
// off and clear of every town, drawn randomly across the road network rather than strung down one stretch.
// Each is independently, secretly live
// (IED_LIVE_CHANCE, kept very low on purpose -- almost every pile is a bluff and a pure-decoy field is the
// usual outcome: the point is to make the player wary of every pile, not to kill them; a live pile is the
// exception and all-live is vanishingly rare). A live pile cooks a Mk82 bomb when a BLUFOR man
// stands or crouches, or any BLUFOR vehicle rolls, within ARM_RANGE -- but holds for a lone prone man, so a
// live one is only approached safely by crawling in prone. The disarm (fnc_random_event_ied_defuse) is not
// stance-gated; every pile, live or decoy, carries that same disarm within reach, so the two cannot be told
// apart -- a decoy clears to nothing, a live one to a command point. No emplacer unit exists, so nothing here
// is marked isHostile and nothing can be shot: the
// shell has no instigator, so a civilian caught in the blast is charged to no one, and the fire.sqf
// legal-target invariant has no unit to apply to.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

#define IED_COUNT_MIN 5
#define IED_COUNT_MAX 20
#define MIN_DIST 300
#define FWD_SPREAD 200
#define SCATTER 1000
#define IED_MIN_SEP 50
#define IED_LIVE_CHANCE 0.10
#define ARM_RANGE 20
#define FUSE (random 2)
#define LIFETIME 900
#define TICK 0.5

private _pileClasses = [
	"Land_GarbageBags_F", "Land_GarbagePallet_F", "Land_GarbageWashingMachine_F",
	"Land_Tyres_F", "Land_JunkPile_F"
];

private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];

// Every town zone as [centre, radius], so no pile lands inside one -- the field sits out in open country.
private _towns = [];
{ _towns pushBack [getPos _x, _radii param [_forEachIndex, 0]] } forEach _locs;
private _fnc_inTown = { params ["_p"]; (_towns findIf { (_p distance2D (_x select 0)) < (_x select 1) }) >= 0 };

// Anchor the field forward of the player -- MIN_DIST..MIN_DIST+FWD_SPREAD ahead of where they face -- so it
// is come upon ahead rather than dropped on them or pinned to a town.
private _anchor = _player getPos [MIN_DIST + random FWD_SPREAD, getDir _player];

// Every road across the wide disc around the anchor: never in a town, never inside MIN_DIST of the player.
private _roads = (_anchor nearRoads SCATTER) select {
	!([getPosATL _x] call _fnc_inTown) && { (_x distance2D _player) >= MIN_DIST }
};
if (_roads isEqualTo []) exitWith {};
_roads = _roads call BIS_fnc_arrayShuffle;

private _count = IED_COUNT_MIN + floor (random (IED_COUNT_MAX - IED_COUNT_MIN + 1));

// Draw from the shuffled set keeping every pick IED_MIN_SEP (50 m) off the ones already taken: the shuffle
// spreads the field randomly across the road network, not a row marching down one road, and the separation
// stops two landing on top of each other.
private _spots = [];
{
	if (count _spots >= _count) exitWith {};
	private _rp = getPosATL _x;
	if ((_spots findIf { (getPosATL _x distance2D _rp) < IED_MIN_SEP }) < 0) then { _spots pushBack _x };
} forEach _roads;

// Sit each pile off to one side of the road (perpendicular to how the road runs), out on the verge and flat to
// the slope, rather than on the crown where traffic would clip it.
private _piles = [];
{
	private _road = _x;
	private _rp = getPosATL _road;
	private _side = ([_road] call fnc_civ_roadDir) + selectRandom [90, -90];
	private _off = _rp getPos [3 + random 3, _side];
	private _pile = createVehicle [selectRandom _pileClasses, [_off select 0, _off select 1, 0], [], 0, "CAN_COLLIDE"];
	if (!isNull _pile) then {
		_pile setPosATL [_off select 0, _off select 1, 0];
		_pile setVectorUp (surfaceNormal (getPosATL _pile));
		_pile enableSimulation false;   // a live charge must not be nudged off its spot by traffic
		private _live = random 1 < IED_LIVE_CHANCE;
		_pile setVariable ["DUWS_ied_state", ["decoy", "live"] select _live, false];
		// Public so each client's hold-action condition reads the pile; set on every pile so live and decoy
		// look alike, cleared on defuse or trip to drop the action.
		_pile setVariable ["DUWS_ied_active", true, true];
		// Live pile: full 6 s defuse. Decoy: no charge, so instant (duration 0) -- the tell comes only once
		// the player has already committed. Not stance-gated; only the trip ignores a prone man.
		private _act = [
			_pile,
			localize "STR_DUWS_T_EVENT_IED_DEFUSE",
			"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
			"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
			"(_target getVariable ['DUWS_ied_active', false]) && {_target distance player < 4}",
			"(_target getVariable ['DUWS_ied_active', false])",
			{}, {},
			{ params ["_pile", "_caller"]; [_pile, _caller] remoteExec ["fnc_random_event_ied_defuse", 2]; },
			{}, [], ([0, 6] select _live), 0, true, false
		];
		// Every interface (the SP/listen host included), but not a dedicated server that has none;
		// JIP-keyed to the pile so a late joiner gets it and deleting the pile drops the queued message.
		_act remoteExec ["BIS_fnc_holdActionAdd", [0, -2] select isDedicated, _pile];
		// Hand every pile to the sweep at spawn -- live or decoy, approached or not, it collects on its
		// own clock. A junk pile is a static prop, so a raw DUWS_binMe flag is inert (fnc_random_event_ied_defuse).
		[_pile, LIFETIME] call fnc_duws_disposeAfter;
		_piles pushBack _pile;
	};
} forEach _spots;
if (_piles isEqualTo []) exitWith {};

// Field centre = mean pile position. The proximity watch gates on this, not the seed town, because the field
// can spread well off the town the seed search was centred on.
private _fieldCenter = [0, 0, 0];
{ _fieldCenter = _fieldCenter vectorAdd (getPosATL _x) } forEach _piles;
_fieldCenter = _fieldCenter vectorMultiply (1 / count _piles);

// Watch radius follows the field's own reach (furthest pile from centre, plus the arm range): a fixed radius
// would miss edge piles now the scatter can run a kilometre wide, so a live pile would never trip.
private _fieldRadius = 0;
{ _fieldRadius = _fieldRadius max (_x distance2D _fieldCenter) } forEach _piles;
private _watch = _fieldRadius + ARM_RANGE + 50;

private _liveCount = { (_x getVariable ["DUWS_ied_state", "decoy"]) == "live" } count _piles;
["INFO", "CIV", format ["IED event: %1 piles (%2 live) ahead of player, rolled at town %3", count _piles, _liveCount, _townIndex]] call fnc_log;

// Pure-decoy field: no proximity watch to run, nothing to track. The piles delete themselves on the
// disposeAfter clock set at spawn.
if (_liveCount == 0) exitWith {};

[_piles, _fieldCenter, _watch] spawn {
	params ["_piles", "_fieldCenter", "_watch"];
	private _deadline = time + LIFETIME;
	// Runs until every live pile has resolved (defused or blown) or the field times out.
	while {
		time < _deadline
		&& { { (_x getVariable ["DUWS_ied_state", "decoy"]) == "live" } count _piles > 0 }
	} do {
		// No one near the field: nothing can trip, so skip the per-pile scan until a player returns.
		if ((allPlayers findIf { alive _x && { (_x distance2D _fieldCenter) < _watch } }) < 0) then {
			sleep TICK;
		} else {
		// Once per tick, not per pile: every live pile tests the same BLUFOR.
		private _blu = allUnits select { side (group _x) == west && { alive _x } };
		{
			private _pile = _x;
			if (!isNull _pile && { (_pile getVariable ["DUWS_ied_state", "decoy"]) == "live" }) then {
				private _pp = getPosATL _pile;
				// Trip on any BLUFOR in range that is not a lone prone man: crew ride vehicle _u != _u,
				// so a drive-over always fires; only crawling in on foot is safe.
				private _trip = (_blu findIf {
					(_x distance2D _pp) < ARM_RANGE
					&& { !(vehicle _x == _x && { stance _x == "PRONE" }) }
				}) >= 0;
				if (_trip) then {
					_pile setVariable ["DUWS_ied_state", "gone", false];
					_pile setVariable ["DUWS_ied_active", false, true];
					[_pile, _pp] spawn {
						params ["_pile", "_pp"];
						sleep FUSE;
						// Spawn the bomb above ground and shove it down: a munition created at rest never
						// fuzes (arma_engine_gotchas.md). Mk82, the laser-guided bomb support round, as car_bomb.
						private _bomb = createVehicle ["Bo_Mk82", [_pp select 0, _pp select 1, (_pp select 2) + 0.5], [], 0, "CAN_COLLIDE"];
						_bomb setVelocity [0, 0, -30];
						if (!isNull _pile) then { deleteVehicle _pile };
					};
				};
			};
		} forEach _piles;
		sleep TICK;
	};
	};
	// Each pile deletes itself on the disposeAfter clock set at spawn.
};
