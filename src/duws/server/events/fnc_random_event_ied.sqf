// Locality: server -- roadside IEDs, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town against the player.
//
// A line of identical junk piles laid down one stretch of road on the town's approach, none inside any town
// zone (the run stops at a town edge). Each is independently, secretly live
// (IED_LIVE_CHANCE, kept very low on purpose -- almost every pile is a bluff and a pure-decoy field is the
// usual outcome: the point is to make the player wary of every pile, not to kill them; a live pile is the
// exception and all-live is vanishingly rare). A live pile cooks an 82mm mortar shell when a BLUFOR man
// stands or crouches, or any BLUFOR vehicle rolls, within ARM_RANGE -- but holds for a lone prone man, so a
// live one is only approached safely by crawling in prone. The disarm (fnc_random_event_ied_defuse) is not
// stance-gated; every pile, live or decoy, carries that same disarm within reach and a client-side world icon
// (fnc_random_event_ied_markers), so the two cannot be told apart -- a decoy clears to nothing, a live one to
// a command point. No emplacer unit exists, so nothing here is marked isHostile and nothing can be shot: the
// shell has no instigator, so a civilian caught in the blast is charged to no one, and the fire.sqf
// legal-target invariant has no unit to apply to.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

#define IED_COUNT_MIN 1
#define IED_COUNT_MAX 6
#define IED_REACH 350
#define IED_MIN_SEP 50
#define IED_LIVE_CHANCE 0.06
#define ARM_RANGE 10
#define FIELD_WATCH 500
#define FUSE (0.5 + random 1)
#define LIFETIME 1200
#define TICK 0.5

private _pileClasses = [
	"Land_GarbageBags_F", "Land_GarbagePallet_F", "Land_GarbageWashingMachine_F",
	"Land_LuggageHeap_03_F", "Land_LuggageHeap_01_F", "Land_Tyres_F", "Land_JunkPile_F",
	"Land_WoodenCart_F", "Land_Sacks_heap_F", "Land_Sacks_goods_F", "Land_Pallets_F"
];

private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];

// Every town zone as [centre, radius], so a run can be denied entry to ALL of them, not just the one this
// event anchored on -- a stretch walking toward a neighbouring town stops at its edge.
private _towns = [];
{ _towns pushBack [getPos _x, _radii param [_forEachIndex, 0]] } forEach _locs;
private _fnc_inTown = { params ["_p"]; (_towns findIf { (_p distance2D (_x select 0)) < (_x select 1) }) >= 0 };

// Seed the stretch on the event's town (or the player when off-town), reaching IED_REACH past the town edge.
private _townPos = getPos _player;
private _townRadius = 0;
if (_townIndex >= 0 && {_townIndex < count _locs}) then {
	_townPos = getPos (_locs select _townIndex);
	_townRadius = _radii param [_townIndex, 0];
};
private _fieldReach = _townRadius + IED_REACH;

private _cands = (_townPos nearRoads _fieldReach) select { !([getPosATL _x] call _fnc_inTown) };
if (_cands isEqualTo []) exitWith {};
_cands = _cands call BIS_fnc_arrayShuffle;

private _count = IED_COUNT_MIN + floor (random (IED_COUNT_MAX - IED_COUNT_MIN + 1));

// Lay the piles down one continuous stretch of road, IED_MIN_SEP apart, instead of scattering them around the
// town. Walk the network from a seed, always taking the connected segment that turns least so the line hugs
// the road, dropping a pile each time IED_MIN_SEP of road has been covered; stop at a dead end or a town edge.
// Try a handful of seeds and keep the longest run.
private _spots = [];
{
	private _seed = _x;
	private _run  = [_seed];
	private _cur  = _seed;
	private _prev = objNull;
	private _accum = 0;
	private _guard = 0;
	while { count _run < _count && {_guard < 500} } do {
		_guard = _guard + 1;
		private _curPos = getPosATL _cur;
		// _heading is the bearing we arrived on -- the seed segment's own getDir seeds the very first step.
		private _heading = if (isNull _prev) then { getDir _cur } else { (getPosATL _prev) getDir _curPos };
		private _nexts = (roadsConnectedTo _cur) select { _x != _prev && {_x != _cur} };
		if (_nexts isEqualTo []) exitWith {};
		private _next = objNull;
		private _bestTurn = 999;
		{
			private _turn = 180 - abs (abs (_heading - (_curPos getDir (getPosATL _x))) - 180);
			if (_turn < _bestTurn) then { _bestTurn = _turn; _next = _x };
		} forEach _nexts;
		if ([getPosATL _next] call _fnc_inTown) exitWith {};
		_accum = _accum + (_curPos distance2D (getPosATL _next));
		_prev = _cur;
		_cur  = _next;
		if (_accum >= IED_MIN_SEP) then { _run pushBack _cur; _accum = 0 };
	};
	if (count _run > count _spots) then { _spots = _run };
	if (count _spots >= _count) exitWith {};
} forEach (_cands select [0, 8 min count _cands]);

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
		// Public so each client's hold-action condition and world icon read the pile; set on every pile so
		// live and decoy look alike, cleared on defuse or trip to drop both the action and the icon.
		_pile setVariable ["DUWS_ied_active", true, true];
		// Live pile: full 6 s defuse. Decoy: no charge, so instant (duration 0) -- the tell comes only once
		// the player has already committed. Not stance-gated; only the trip ignores a prone man.
		private _act = [
			_pile,
			localize "STR_DUWS_T_EVENT_IED_DEFUSE",
			"\a3\Ui_f\data\IGUI\Cfg\Actions\take_ca.paa",
			"\a3\Ui_f\data\IGUI\Cfg\Actions\take_ca.paa",
			"(_target getVariable ['DUWS_ied_active', false]) && {_target distance player < 4}",
			"(_target getVariable ['DUWS_ied_active', false])",
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

// Field centre = mean pile position. The proximity watch gates on this, not the seed town, because the stretch
// can run well off the town the seed search was centred on.
private _fieldCenter = [0, 0, 0];
{ _fieldCenter = _fieldCenter vectorAdd (getPosATL _x) } forEach _piles;
_fieldCenter = _fieldCenter vectorMultiply (1 / count _piles);

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

[_piles, _fieldCenter] spawn {
	params ["_piles", "_fieldCenter"];
	private _deadline = time + LIFETIME;
	// Runs until every live pile has resolved (defused or blown) or the field times out.
	while {
		time < _deadline
		&& { { (_x getVariable ["DUWS_ied_state", "decoy"]) == "live" } count _piles > 0 }
	} do {
		// No one near the field: nothing can trip, so skip the per-pile scan until a player returns.
		if ((allPlayers findIf { alive _x && { (_x distance2D _fieldCenter) < FIELD_WATCH } }) < 0) then {
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
