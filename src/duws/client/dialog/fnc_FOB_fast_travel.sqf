// Locality: client -- invoked from a dialog action (shared/includes/fobmanager.hpp:79).
if (!enable_fast_travel) exitWith {hint localize "STR_DUWS_T_gogv37ur"};

//// CREATE THE ARRAY OF FOBS w/ POSITION
_array_of_fobs_list = [];  // init the array of fobs
_list = [];

_index = -1;
{
    _array_of_fobs_list = _array_of_fobs_list + [[getpos _x]]; // add the FOB (pos) into a nested array

    _index = _index + 1;
    _array_of_fobs_list_selected = _array_of_fobs_list select _index; // select the current array inside _array_of_fobs_list

    _actual_fobname = Array_of_FOBname select _index;
    _array_of_fobs_list_selected = _array_of_fobs_list_selected + [_actual_fobname];

    _list = _list + [_array_of_fobs_list_selected];
} forEach Array_of_FOBS;

//// CREATE THE ARRAY OF FOBS w/ POSITION -- END
// add the base
_hqpos = PosOfBLUHQ;
_list = _list + [[_hqpos,"Main base"]];
_index = lbCurSel 2100;

_selected_fob = _list select _index;
_selected_fob_pos = _selected_fob select 0;
_selected_fob_name = _selected_fob select 1;

closedialog 0;

// Fade the traveller through it, the way the rest mechanic covers its own jump in time: arriving
// somewhere else on the map mid-stride reads as a glitch. Only this player is faded -- nobody at
// either end of the trip has a reason to lose their screen.
titleCut ["", "BLACK OUT", 1.5];
sleep 1.7;

private _dest = [(_selected_fob_pos select 0) + 3, (_selected_fob_pos select 1)];
player setpos _dest;

// The squad travels with its leader, or fast travel splits it across the map. AI subordinates are
// carried; a player subordinate is deliberately not, because being teleported by someone else's
// menu click is not something a player should discover mid-firefight -- they take the trip
// themselves. No player can be under another player's command yet, so that filter drops nobody
// today; it is written here because this is where it has to be when they can.
private _followers = (units group player) select {_x != player && {alive _x} && {!isPlayer _x}};
{
	// Ringed rather than stacked on the leader: setPos'd units sharing one spot end up inside one
	// another, which the engine resolves by shoving them apart -- the same reason the intro's
	// rope-in fans its stick. The radius is fixed, so a bigger squad simply rings tighter.
	private _angle = 360 * _forEachIndex / (count _followers);
	_x setPos [(_dest select 0) + (sin _angle) * 5, (_dest select 1) + (cos _angle) * 5];
} forEach _followers;

titleCut ["", "BLACK IN", 1.5];

hint localize "STR_DUWS_T_s4i32jjh";