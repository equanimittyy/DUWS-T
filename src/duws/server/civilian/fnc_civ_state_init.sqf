// Executed by the registry rather than stored as one function: this file defines several. Broadcasts stay
// in server_fnc_init.sqf beside the load, so the manifest remains the one place to see what reaches clients.

// -1 when outside every civilian radius (open country, civilians-off, RAVAGE/WBK); every caller
// degrades on that rather than treating it as an error -- a charge is dropped, a read comes back neutral.
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

// Distinct from fnc_civ_townAt: that answers "inside which town" off each town's own radius, while an
// event working from a town's approach wants the closest town within a flat threshold instead.
fnc_civ_townNear = {
	if (!isServer) exitWith { -1 };
	params [["_pos", [0,0,0]], ["_range", 800]];
	private _locs = missionNamespace getVariable ["civ_locations", []];
	private _best = -1;
	private _bestDist = _range;
	{
		private _d = _pos distance2D (getPos _x);
		if (_d < _bestDist) then { _bestDist = _d; _best = _forEachIndex; };
	} forEach _locs;
	_best
};

// Shared by the civilian-death and building-destruction charges rather than each carrying its own
// sweep, so presence-as-involvement can't drift between what the two consumers mean by it.
fnc_civ_playerNear = {
	if (!isServer) exitWith { false };
	params ["_pos", ["_radius", 200]];
	((call BIS_fnc_ListPlayers) findIf { (_x distance _pos) < _radius }) >= 0
};

// Neutral is territory, not a stored figure -- there is nothing to be liked or hated by on ground no
// town owns. A caller needing "neutral" from "not modelled" reads civ_town_rep directly, as fnc_map_readout_query does.
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

// Split out of the roll that consumes it so the curve is unit-testable without the engine. Neither end is
// a wall -- a town at -20 still takes a bribe one time in ten, so ruined ground is expensive, not closed.
fnc_civ_reaction_weights = {
	params [["_rep", 0]];
	private _t = ((_rep / 20) max -1) min 1;
	private _fnc_accept = {
		if (_this <= 0) then { (1 + _this) / 3 } else { (1/3) + _this * (0.9 - 1/3) }
	};
	private _accept = _t call _fnc_accept;
	// Mirrors _accept exactly so the curve can't drift out of symmetry by being written twice.
	private _refuse = (-_t) call _fnc_accept;
	[_accept, 1 - _accept - _refuse, _refuse]
};

// One table rather than a switch per consumer, so the request roll, serve and bribe answers can't drift
// apart on price; prices are placeholders, not measured. An unrecognised row returns negative, a fail-closed reject since rows only ever come off the wire.
fnc_civ_rowPrice = {
	params [["_row", ""]];
	switch (toUpper _row) do {
		case "INTEL": { 3 };
		case "AID": { 2 };
		case "TOOLKIT": { 2 };
		default { -1 };
	};
};

// The one reading of the two bands: markers and AP income both ask here rather than each
// spelling out its own thresholds.
fnc_civ_townOwner = {
	params [["_rep", 0]];
	if (_rep >= 10) exitWith { "BLU" };
	if (_rep <= -10) exitWith { "OPF" };
	""
};

// One table rather than a literal per paint site, so the two markers can't disagree on which side a town
// is on, and there's a neutral pair before any reputation array exists. Blue/red, not green -- the engine
// reads green as Independent, which this mission sets hostile to west; the icon is deeper than the washed-out ellipse so it stays readable without fighting a zone marker at zoom-out.
fnc_civ_townBand = {
	params [["_rep", 0]];
	switch ([_rep] call fnc_civ_townOwner) do {
		case "BLU": { ["#(0.45,0.62,1.0,1)", "#(0.15,0.38,0.95,1)"] };
		case "OPF": { ["#(1.0,0.45,0.45,1)", "#(0.85,0.1,0.1,1)"] };
		default { ["#(0.6,0.35,0.7,1)", "#(0.42,0.15,0.58,1)"] };
	}
};

// Derived here rather than at each consumer, so the map readout and the tick that actually pays can't
// disagree -- a readout promising AP the tick never credits would be worse than no readout.
fnc_civ_townIncome = {
	params [["_rep", 0], ["_ap", 0]];
	private _owner = [_rep] call fnc_civ_townOwner;
	if (_owner isEqualTo "") exitWith { [0, ""] };
	[_ap, _owner]
};

// The band is the sole writer of both colours, so nothing races this repaint. setMarkerColor takes an
// inline #(r,g,b,a) string as well as a CfgMarkerColors name; alpha is set explicitly since a marker
// created without one sits at 1. With no civ_town_rep (RAVAGE, WBK) both markers keep the neutral pair from creation, since no band will ever repaint them.
fnc_civ_townRender = {
	if (!isServer) exitWith {};
	params ["_townIndex"];
	private _reps = missionNamespace getVariable ["civ_town_rep", []];
	if (_townIndex < 0 || _townIndex >= count _reps) exitWith {};

	([_reps select _townIndex] call fnc_civ_townBand) params ["_areaColour", "_iconColour"];
	private _area = format ["civ_area_%1", _townIndex];
	_area setMarkerColor _areaColour;
	(format ["civ_icon_%1", _townIndex]) setMarkerColor _iconColour;
	// Alpha comes from the reveal flag, not the band: a hardcore town not yet found is repainted every time
	// its reputation moves, and a flat alpha here would put it on the map the first time a civilian was harmed.
	private _shown = (missionNamespace getVariable ["civ_visible", []]) param [_townIndex, true];
	_area setMarkerAlpha ([0, 0.3] select _shown);
};

// Matched to the panic calm-down (fnc_civ_panic CALM_DELAY) so the two civilian timers read the same.
#define HALT_LAPSE 60

fnc_civ_moveToPlayerServer = {
    params ["_unit", "_caller"];
    if (!isServer) exitWith {};
    if (isNull _unit || isNull _caller) exitWith {};

    // Broadcast: the call-over unlocks the interaction menu's condition on every machine that carries the
    // action; set here rather than client-side so a client can't open the menu on a local it never stopped.
    _unit setVariable ["DUWS_civ_stopped", true, true];

    // Back to front: deleteWaypoint shifts every later index down, so a forward pass would leave half the
    // waypoints to pull the civilian away mid-walk; `reverse` can't inline into the forEach since it reverses in place and returns Nothing.
    private _wps = waypoints (group _unit);
    reverse _wps;
    { deleteWaypoint _x } forEach _wps;
    _unit doMove (getPos _caller);
    _unit setBehaviour "AWARE";
    _unit setSpeedMode "NORMAL";
    sleep 5;
    doStop _unit;

    // Not permanent: a local left alone drifts back to routine and the call-over action, hidden by
    // DUWS_civ_stopped meanwhile, reappears for a re-hail. Flat from the call-over like the panic calm-down;
    // exchange, arrest, surrender and panic each own the civilian's next move, so this only lapses a halt that went nowhere, and the re-test guards against the flag flipping mid-sleep.
    [_unit] spawn {
        params ["_unit"];
        sleep HALT_LAPSE;
        if (
            alive _unit
            && {_unit getVariable ["DUWS_civ_stopped", false]}
            && {!(_unit getVariable ["DUWS_civ_panicked", false])}
            && {!(_unit getVariable ["DUWS_civ_closed", false])}
            && {!(_unit getVariable ["DUWS_civ_arrested", false])}
            && {!(_unit getVariable ["isSurrendered", false])}
        ) then {
            _unit setVariable ["DUWS_civ_stopped", false, true];
            [_unit] call fnc_civ_resume;
        };
    };
};
