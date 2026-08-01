// Town lookup, reputation, income and the civilian reaction weighting.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// Position to town index, -1 when the point sits outside every civilian radius. Open country,
// a civilians-off campaign and RAVAGE/WBK all land on -1, and every caller degrades on that
// rather than treating it as an error: a reputation charge is dropped, a reputation read comes
// back neutral.
fnc_civ_townAt = {
	if (!isServer) exitWith { -1 };
	params [["_pos", [0,0,0]]];
	private _locs = missionNamespace getVariable ["civ_locations", []];
	private _radii = missionNamespace getVariable ["civ_radii", []];
	private _found = -1;
	{
		if ((_pos distance2D (getPos _x)) < (_radii param [_forEachIndex, 0])) exitWith {
			_found = _forEachIndex;
		};
	} forEach _locs;
	_found
};

// A player within _radius of a position. Shared by the civilian-death charge and the building
// destruction charge rather than each carrying its own sweep, so the two cannot drift: presence
// is the proxy for the player having been involved and both must mean the same thing by it.
fnc_civ_playerNear = {
	if (!isServer) exitWith { false };
	params ["_pos", ["_radius", 200]];
	((call BIS_fnc_ListPlayers) findIf { (_x distance _pos) < _radius }) >= 0
};

// The reputation a town-local consumer acts on: that town's if it has one, neutral otherwise.
// Every civilian gate degrades this way rather than refusing to act, because civilians can be
// switched off and RAVAGE/WBK register no town reputation at all.
// Neutral, not a stored figure: reputation is territory, and there is nothing to be liked or
// hated by on ground no town owns. A caller that has to tell "neutral" from "not modelled"
// reads civ_town_rep directly, the way fnc_map_readout_query does.
fnc_civ_repAt = {
	if (!isServer) exitWith { 0 };
	params [["_townIndex", -1]];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex >= 0 && _townIndex < count _reps) then {
		_reps select _townIndex
	} else {
		0
	}
};

// What each garrison tier puts in a town, as tokens DUWS_fnc_zoneSpawnOne already understands --
// plus "buildings", which only tier IV raises and which no zone composition emits.
//
// Absolute, like the zone set: a row is the whole garrison for that tier, so what a tier IV town is
// reads off one line. A tier bought while the garrison stands raises DUWS_fnc_spawnDiff of the two
// rows, which is what keeps reinforcement an addition rather than a second garrison.
//
// A town's own set, deliberately smaller than any zone's, and not multiplied by its radius the way
// a zone's is. Static emplacements are what make a zone an objective and a town must not compete
// with one for the player's attention -- so a large town stays a garrison rather than becoming a
// zone that happens to have civilians in it, and IV reaches the zone benchmark by occupying
// buildings rather than by digging in.
// --DUWS-UNITCOMP BEGIN name="Town tiers" row="tier I..IV"--
DUWS_townSpawnTiers = [
	["patrol", "team"],
	["patrol", "team", "team", "car"],
	["patrol", "team", "team", "car", "armored"],
	["patrol", "team", "team", "car", "armored", "buildings"]
];
// --DUWS-UNITCOMP END--

// A town's garrison tier: 0 for ground OPFOR does not hold, 1 to 4 for ground it does. Reputation
// only ever writes tier 1 -- see fnc_civ_garrison -- and every step above it is bought by the
// OPFOR commander, so the tier is stored state rather than a figure derived from reputation.
// Neutral by default for the same reason fnc_civ_repAt is: ground no town owns has no garrison.
fnc_town_garrison_tierAt = {
	if (!isServer) exitWith { 0 };
	params [["_townIndex", -1]];
	private _tiers = missionNamespace getVariable ["DUWS_townGarrisonTier", []];
	if (_townIndex >= 0 && _townIndex < count _tiers) then {
		_tiers select _townIndex
	} else {
		0
	}
};

// The sole writer, and the OPFOR commander's purchase hook. Clamped rather than trusted: nothing
// upstream validates a tier, and a table lookup on one out of range is a fatal error rather than a
// weak garrison.
// A tier written here is what the town owes, not what is standing in it -- the garrison thread
// picks the change up on its own cycle, and only when a player is there to see it arrive.
fnc_town_garrison_setTier = {
	if (!isServer) exitWith {};
	params [["_townIndex", -1], ["_tier", 0], ["_reason", ""]];
	private _tiers = missionNamespace getVariable ["DUWS_townGarrisonTier", []];
	if (_townIndex < 0 || _townIndex >= count _tiers) exitWith {};
	private _new = ((round _tier) max 0) min (count DUWS_townSpawnTiers);
	private _old = _tiers select _townIndex;
	if (_new == _old) exitWith {};
	_tiers set [_townIndex, _new];
	["INFO", "CIV", format ["Town %1 garrison tier %2 -> %3 (%4)", _townIndex, _old, _new, _reason]] call fnc_log;
};

// How a town reacts to a request: [accept, bribe, refuse], summing to 1. Split out of the roll
// that consumes it so the curve is unit-testable -- the rest of the request path needs the
// engine, this needs nothing.
//
// Piecewise linear with a kink at zero, because accept climbs faster above neutral than below
// it. Bribe is the remainder, a symmetric tent peaking at neutral: a town that neither likes
// nor hates the player is where money talks loudest, and at both extremes standing decides
// instead of coins. Neither end is a wall -- a town at -20 still takes a bribe one time in ten,
// so ground the player has ruined is expensive rather than closed.
fnc_civ_reaction_weights = {
	params [["_rep", 0]];
	private _t = ((_rep / 20) max -1) min 1;
	private _fnc_accept = {
		if (_this <= 0) then { (1 + _this) / 3 } else { (1/3) + _this * (0.9 - 1/3) }
	};
	private _accept = _t call _fnc_accept;
	// Refuse is accept's exact mirror, so the curve cannot drift out of symmetry by being
	// written twice.
	private _refuse = (-_t) call _fnc_accept;
	[_accept, 1 - _accept - _refuse, _refuse]
};

// What a menu row costs if the reaction roll comes back bribe. One table rather than a switch in
// each consumer: the request roll, the serve and the bribe answer all have to agree on the price,
// and three copies would drift. The prices are anchored on the black market the player already
// reads (goggles 1, pistol and optic 5) and are placeholders for balancing, not measured figures.
//
// An unrecognised row returns a negative price. Callers must treat that as a reject: rows only
// ever come off the wire, so this is the fail-closed edge for a client sending one the menu
// never offered.
fnc_civ_rowPrice = {
	params [["_row", ""]];
	switch (toUpper _row) do {
		case "INTEL": { 3 };
		case "RECRUIT": { 2 };
		case "AID": { 2 };
		case "TOOLKIT": { 2 };
		default { -1 };
	};
};

// A town's band colours as [ellipse, icon], keyed on reputation. One table rather than a
// literal at each paint site: the two markers must never disagree about which side a town is
// on, and marker creation needs the neutral pair before any reputation array exists.
// Blue/red rather than green, because the engine reads green as Independent, which this
// mission sets hostile to west. The icon is the deeper of each pair -- the ellipse is washed
// out on purpose so it does not compete with a zone marker at map zoom-out, and an icon drawn
// at full alpha in that same wash is unreadable against Altis terrain.
fnc_civ_townBand = {
	params [["_rep", 0]];
	if (_rep >= 10) exitWith { ["#(0.45,0.62,1.0,1)", "#(0.15,0.38,0.95,1)"] };
	if (_rep <= -10) exitWith { ["#(1.0,0.45,0.45,1)", "#(0.85,0.1,0.1,1)"] };
	["#(0.6,0.35,0.7,1)", "#(0.42,0.15,0.58,1)"]
};

// What a town pays an economy tick, as [amount, side]. A town inside the neutral band pays
// nobody, so its worth is not its income. Derived here rather than at each consumer because
// the map readout and the tick that actually pays must not be able to disagree: a readout
// promising AP the tick never credits is worse than no readout.
fnc_civ_townIncome = {
	params [["_rep", 0], ["_ap", 0]];
	if (_rep >= 10) exitWith { [_ap, "BLU"] };
	if (_rep <= -10) exitWith { [_ap, "OPF"] };
	[0, ""]
};

// Repaints one town's ellipse and icon from civ_town_rep. The band is the only writer of both
// colours -- depopulation used to paint the ellipse black and that path is gone -- so nothing
// races this. setMarkerColor takes an inline #(r,g,b,a) string as well as a CfgMarkerColors
// class name; alpha is set explicitly because a marker created without it sits at 1.
// With no civ_town_rep (RAVAGE, WBK) both markers keep the neutral pair creation gave them,
// since no band will ever repaint them.
fnc_civ_townRender = {
	if (!isServer) exitWith {};
	params ["_townIndex"];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex < 0 || _townIndex >= count _reps) exitWith {};

	([_reps select _townIndex] call fnc_civ_townBand) params ["_areaColour", "_iconColour"];
	private _area = format ["civ_area_%1", _townIndex];
	_area setMarkerColor _areaColour;
	(format ["civ_icon_%1", _townIndex]) setMarkerColor _iconColour;
	// Alpha comes from the reveal flag, not from the band: a hardcore town the player has not
	// found yet is repainted every time its reputation moves, and a flat 0.3 here would put it
	// on the map the first time a civilian was harmed in it.
	private _shown = (missionNamespace getVariable ["civ_visible", []]) param [_townIndex, true];
	_area setMarkerAlpha ([0, 0.3] select _shown);
};

fnc_civ_moveToPlayerServer = {
    params ["_unit", "_caller"];
    if (!isServer) exitWith {};
    if (isNull _unit || isNull _caller) exitWith {};

    // Broadcast: the interaction menu's condition is evaluated on every machine that carries the
    // action, and the call-over is what unlocks it. Set here rather than in the client-side action
    // body so a client cannot open the menu on a local it never actually stopped.
    _unit setVariable ["DUWS_civ_stopped", true, true];

    // An idler is held in an ambient pose that owns their AI, so the doMove below is silently
    // ignored until the pose is released -- the civilian stands and smokes through being called.
    if (_unit getVariable ["civ_posed", false]) then {
        [_unit] call BIS_fnc_ambientAnim__terminate;
        _unit setVariable ["civ_posed", false];
    };

    // Back to front: deleteWaypoint shifts every later index down, so a forward pass over the
    // list deletes every other waypoint and leaves the rest to pull the civilian away mid-walk.
    // `reverse` cannot be inlined into the forEach -- it reverses in place and returns Nothing.
    private _wps = waypoints (group _unit);
    reverse _wps;
    { deleteWaypoint _x } forEach _wps;
    _unit doMove (getPos _caller);
    _unit setBehaviour "AWARE";
    _unit setSpeedMode "NORMAL";
    sleep 5;
    doStop _unit;
};
