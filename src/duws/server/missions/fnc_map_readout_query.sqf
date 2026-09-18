// Locality: server. Answers one map click from the board's View Map action: which zone or civilian
// town, if any, sits under the clicked position. The lookup cannot live on the client -- civ_locations,
// civ_radii, the per-town population variables, civ_town_rep and every zone's garrison state are all
// server-only and none of them is broadcast -- so the click travels here and the readout travels back.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
if (isNull _caller) exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
private _visible = missionNamespace getVariable ["civ_visible", []];

// Nearest centre wins, across both kinds. Zone circles and town discs overlap by design -- a
// contested town on enemy ground is the point -- so a click inside both has to resolve to one of
// them, and the middle the player clicked nearer is the one they were pointing at.
//
// An unrevealed town or zone answers as empty ground. Anything else would make the map a free sweep
// for what hardcore's reveal machinery exists to keep hidden until it is found. A missing radius
// reads as 0 so an array that ever falls short of its list misses rather than matching everything.
private _pick = [];
private _best = 1e11;

{
	private _d = _pos distance2D (getPos _x);
	if ((_visible param [_forEachIndex, true])
		&& {_d < (_radii param [_forEachIndex, 0])} && {_d < _best}) then {
		_pick = ["TOWN", _forEachIndex];
		_best = _d;
	};
} forEach _locations;

// Radius comes from zone_meta_array and the name and revealed flag from zone_namePOS_pairs, matched
// on position rather than by index: fnc_createzone appends to both, but a spawned build can be
// suspended between the two appends, so concurrent zone builds are not guaranteed to line the two
// arrays up.
{
	_x params ["", "_zPos", "_zSize"];
	private _d = _pos distance2D _zPos;
	if (_d < _zSize && {_d < _best}) then {
		private _i = zone_namePOS_pairs findIf {((_x select 1) distance2D _zPos) < 1};
		if (_i > -1 && {(zone_namePOS_pairs select _i) select 2}) then {
			_pick = ["ZONE", (zone_namePOS_pairs select _i) select 0, _zPos];
			_best = _d;
		};
	};
} forEach zone_meta_array;

if (_pick isEqualTo []) exitWith { [] remoteExec ["fnc_map_readout_draw", _caller]; };

if ((_pick select 0) isEqualTo "ZONE") exitWith {
	_pick params ["", "_name", "_zPos"];
	private _key = [_zPos] call fnc_zone_key;
	// Matched on distance rather than `in`, like every other read of these lists: a stored zone
	// position and the one a capture trigger filed differ in z, and the capture path's has been
	// through a formatted statement string.
	private _held = (WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zPos) < 1}) >= 0;

	// Twenty segments, one per five per cent of the garrison's full potential, floored to the nearest, so a
	// bar shows only once its five per cent is actually held and a full garrison reads solid. The ledger loses a
	// token the moment its group is wiped, so one figure serves a streamed-in zone and a stowed one alike.
	private _seg = floor (([_key] call fnc_zone_strength) * 20);

	// What the ground is worth taking rather than how much of it is left -- which is what the bar under it says.
	private _tier = [_key] call fnc_zone_tier;
	private _kind = missionNamespace getVariable [format ["DUWS_zoneKind_%1", _key], ""];
	// The same window a town reports as MOBILISING: OPFOR own the ground and their men are not on it yet.
	// A zone the player holds is never mobilising, whatever the flag says -- BLUFOR inherit no
	// garrison at all when they take one, so there is nothing there to be on its way.
	private _hold = if (!_held && {missionNamespace getVariable [format ["DUWS_zoneMobilising_%1", _key], false]})
		then { "MOBILISING" } else { "" };
	["ZONE", [_name, _kind, _held, _seg, _tier, _hold]] remoteExec ["fnc_map_readout_draw", _caller];
};

private _hit = _pick select 1;
private _name = text (_locations select _hit);
if (_name isEqualTo "") then { _name = format ["Unnamed%1", _hit] };
private _pop = missionNamespace getVariable [format ["civ_pop_%1", _hit], 0];

// Read straight out of the array rather than through fnc_civ_repAt, which falls back to the
// campaign-wide figure: printing that under a town's name would report a number the town does
// not have. RAVAGE and WBK register no town reputation at all, and the flag is what lets the
// readout say so instead of showing a fabricated 0.
private _reps = missionNamespace getVariable ["civ_town_rep", []];
private _hasRep = _hit < count _reps;
private _rep = if (_hasRep) then { _reps select _hit } else { 0 };
// Raw worth, not throttled or rounded per town: the tick sums every banded town's worth and rounds
// the total once (server/warcom/fnc_zonesundercontrol.sqf), so a per-town round here would disagree
// -- a small town would read 0 while the tick, summing first, still pays it. Worth is the stable
// per-town fact; the throttle is a campaign-total effect and shows in the pool figures.
private _ap = (missionNamespace getVariable ["civ_town_ap", []]) param [_hit, 0];
([_rep, _ap] call fnc_civ_townIncome) params ["_income", "_side"];

// Worth travels alongside the income, not instead of it. They are the same number for a town that
// has picked a side, but a neutral one earns nothing while still being worth something to turn,
// and the readout has to be able to say both without re-deriving the tick's figure client-side.
//
// The tier is what the town owes, which is not always what is standing in it: a town nobody has
// walked into yet reads its purchased tier with no men on the ground. That is the honest answer for
// a map read before travelling -- the readout is describing what the player will meet, not what is
// loaded. A town still holding says so instead, below.
private _tier = [_hit] call fnc_town_garrison_tierAt;
// A mobilising town reports that instead of a tier. The tier is real underneath -- the town is enemy
// ground either way -- but printing a numeral would say a garrison is standing, and there is none yet.
private _hold = ["", "MOBILISING"] select (([_hit] call fnc_town_garrison_holdAt) > 0);

// The same twenty-segment five-per-cent scale a zone reports on, floored. A town has no equivalent of a
// deployed zone's live count -- the roster lives inside the garrison thread and is never published -- so
// this is the ledger projection, standing garrison or not.
private _seg = floor (([_hit] call fnc_town_garrison_strengthAt) * 20);
_seg = (_seg max 0) min 20;
["TOWN", [_name, _pop, _hasRep, _rep, _income, _side, _ap, _tier, _hold, _seg]] remoteExec ["fnc_map_readout_draw", _caller];
