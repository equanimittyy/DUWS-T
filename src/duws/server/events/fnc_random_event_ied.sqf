// Locality: server -- roadside IEDs, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town against the player.
//
// A scatter of identical junk piles on the roads around the town. Each is independently, secretly live
// (IED_LIVE_CHANCE, no floor -- a field of pure decoys is a legal, deliberately anticlimactic outcome, and
// all-live is vanishingly rare). A live pile cooks an 82mm mortar shell when a BLUFOR man stands or crouches, or
// any BLUFOR vehicle rolls, within ARM_RANGE -- but holds for a lone prone man, which is the only way to
// crawl in and defuse it (fnc_random_event_ied_defuse). Every pile, live or decoy, carries that same prone
// defuse and a client-side world icon (fnc_random_event_ied_markers), so the two cannot be told apart --
// a decoy clears to nothing, a live one to a command point. No emplacer unit exists, so nothing here is marked
// isHostile and nothing can be shot: the shell has no instigator, so a civilian caught in the blast is
// charged to no one, and the fire.sqf legal-target invariant has no unit to apply to.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

#define IED_COUNT_MIN 4
#define IED_COUNT_MAX 6
#define IED_REACH 350
#define IED_MIN_SEP 40
#define IED_LIVE_CHANCE 0.35
#define ARM_RANGE 10
#define FUSE (0.5 + random 1)
#define LIFETIME 1200
#define TICK 0.5

private _pileClasses = [
	"Land_GarbageBags_F", "Land_GarbagePallet_F", "Land_GarbageWashingMachine_F",
	"Land_LuggageHeap_03_F", "Land_LuggageHeap_01_F", "Land_Tyres_F", "Land_JunkPile_F",
	"Land_WoodenCart_F", "Land_Sacks_heap_F", "Land_Sacks_goods_F", "Land_Pallets_F"
];

private _townPos = getPos _player;
private _townRadius = 0;
if (_townIndex >= 0) then {
	private _locs = missionNamespace getVariable ["civ_locations", []];
	private _radii = missionNamespace getVariable ["civ_radii", []];
	if (_townIndex < count _locs) then {
		_townPos = getPos (_locs select _townIndex);
		_townRadius = _radii param [_townIndex, 0];
	};
};
private _fieldReach = _townRadius + IED_REACH;

// Roads ringing the town's approaches, out to IED_REACH past its edge but never inside the town itself --
// the roads in are mined, the streets are not. Thinned so piles do not clump: a greedy spread that keeps
// each new road IED_MIN_SEP off the ones already taken. With no town (player fallback) _townRadius is 0,
// so the ring filter is a no-op and this stays the old anchor-centred search.
private _roads = (_townPos nearRoads _fieldReach) select { (_x distance2D _townPos) >= _townRadius };
_roads = _roads call BIS_fnc_arrayShuffle;
if (_roads isEqualTo []) exitWith {};

private _count = IED_COUNT_MIN + floor (random (IED_COUNT_MAX - IED_COUNT_MIN + 1));
private _spots = [];
{
	if (count _spots >= _count) exitWith {};
	private _rp = getPosATL _x;
	if ((_spots findIf { (getPosATL _x distance2D _rp) < IED_MIN_SEP }) < 0) then { _spots pushBack _x };
} forEach _roads;
if (_spots isEqualTo []) exitWith {};

// Sit each pile off to one side of the road (perpendicular to how the stretch runs), out on the verge and
// flat to the slope, rather than on the crown where traffic would clip it.
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
		// Public so a client's hold-action condition and the world icon can see the pile. Set on every pile,
		// live or decoy, so the two are indistinguishable; false on defuse or trip drops both the action and
		// the icon.
		_pile setVariable ["DUWS_ied_active", true, true];
		// A live pile takes the full 6 s prone defuse; a decoy has no charge to work, so its defuse is
		// instant (duration 0). The tell comes only once the player has already committed and triggered it.
		private _act = [
			_pile,
			localize "STR_DUWS_T_EVENT_IED_DEFUSE",
			"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_ca.paa",
			"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_ca.paa",
			"(_target getVariable ['DUWS_ied_active', false]) && {stance player == 'PRONE'} && {_target distance player < 4}",
			"(_target getVariable ['DUWS_ied_active', false]) && {stance player == 'PRONE'}",
			{}, {},
			{ params ["_pile"]; [_pile] remoteExec ["fnc_random_event_ied_defuse", 2]; },
			{}, [], ([0, 6] select _live), 0, true, false
		];
		// Every interface (the SP/listen host included), but not a dedicated server that has none;
		// JIP-keyed to the pile so a late joiner gets it and deleting the pile drops the queued message.
		_act remoteExec ["BIS_fnc_holdActionAdd", [0, -2] select isDedicated, _pile];
		_piles pushBack _pile;
	};
} forEach _spots;
if (_piles isEqualTo []) exitWith {};

// Broadcast the field so each client can draw a world icon over every pile (fnc_random_event_ied_markers).
// Appended, not overwritten, and subtracted at teardown so overlapping fields do not clobber one another.
missionNamespace setVariable ["DUWS_ied_piles",
	(missionNamespace getVariable ["DUWS_ied_piles", []]) + _piles, true];

private _liveCount = { (_x getVariable ["DUWS_ied_state", "decoy"]) == "live" } count _piles;
["INFO", "CIV", format ["IED event: %1 piles (%2 live) near town %3", count _piles, _liveCount, _townIndex]] call fnc_log;

// Pure-decoy field: no proximity watch to run, just reap the junk after its life.
if (_liveCount == 0) exitWith {
	[_piles] spawn {
		params ["_piles"];
		sleep LIFETIME;
		missionNamespace setVariable ["DUWS_ied_piles",
			(missionNamespace getVariable ["DUWS_ied_piles", []]) - _piles, true];
		{ if (!isNull _x) then { [_x] call fnc_duws_disposeAfter } } forEach _piles;
	};
};

[_piles, _townPos, _fieldReach] spawn {
	params ["_piles", "_townPos", "_fieldReach"];
	private _deadline = time + LIFETIME;
	// Runs until every live pile has resolved (defused or blown) or the field times out.
	while {
		time < _deadline
		&& { { (_x getVariable ["DUWS_ied_state", "decoy"]) == "live" } count _piles > 0 }
	} do {
		// No one near the field: nothing can trip, so skip the per-pile scan until a player returns.
		if ((allPlayers findIf { alive _x && { (_x distance2D _townPos) < _fieldReach + 100 } }) < 0) then {
			sleep TICK;
		} else {
		{
			private _pile = _x;
			if (!isNull _pile && { (_pile getVariable ["DUWS_ied_state", "decoy"]) == "live" }) then {
				private _pp = getPosATL _pile;
				// Trip on any BLUFOR in range that is not a lone prone man: crew ride vehicle _u != _u,
				// so a drive-over always fires; only crawling in on foot is safe.
				private _trip = {
					alive _x
					&& { side (group _x) == west }
					&& { (_x distance2D _pp) < ARM_RANGE }
					&& { !(vehicle _x == _x && { stance _x == "PRONE" }) }
				} count allUnits > 0;
				if (_trip) then {
					_pile setVariable ["DUWS_ied_state", "gone", false];
					_pile setVariable ["DUWS_ied_active", false, true];
					[_pile, _pp] spawn {
						params ["_pile", "_pp"];
						sleep FUSE;
						// Spawn the shell above ground and shove it down: a shell created at rest never
						// fuzes (arma_engine_gotchas.md). 82mm mortar shell, smaller than car_bomb's 155.
						private _bomb = createVehicle ["Sh_82mm_AMOS", [_pp select 0, _pp select 1, (_pp select 2) + 0.5], [], 0, "CAN_COLLIDE"];
						_bomb setVelocity [0, 0, -30];
						if (!isNull _pile) then { deleteVehicle _pile };
					};
				};
			};
		} forEach _piles;
		sleep TICK;
	};
	};
	missionNamespace setVariable ["DUWS_ied_piles",
		(missionNamespace getVariable ["DUWS_ied_piles", []]) - _piles, true];
	{ if (!isNull _x) then { [_x] call fnc_duws_disposeAfter } } forEach _piles;
};
