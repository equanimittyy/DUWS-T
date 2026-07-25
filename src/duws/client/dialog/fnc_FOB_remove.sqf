// Locality: client -- invoked from a dialog action (shared/includes/fobmanager.hpp:59).

//// CREATE THE ARRAY OF FOBS w/ POSITION
_array_of_fobs_list = [];  // init the array of fobs

// DISPLAY LIST BEGIN
_index = -1;
_listREMOV = [];
{
    _array_of_fobs_list = _array_of_fobs_list + [[getpos _x]]; // add the FOB (pos) into a nested array

    _index = _index + 1;
    _array_of_fobs_list_selected = _array_of_fobs_list select _index; // select the current array inside _array_of_fobs_list

    _actual_fobname = Array_of_FOBname select _index;
    _array_of_fobs_list_selected = _array_of_fobs_list_selected + [_actual_fobname];

    _listREMOV = _listREMOV + [_array_of_fobs_list_selected];
} forEach Array_of_FOBS;

_index = lbCurSel 2101;

diag_log format ["_listREMOV: %1", _listREMOV];
diag_log format ["_index: %1", _index];

_selected_fob = _listREMOV select _index;
_selected_fob_pos = _selected_fob select 0;
_selected_fob_name = _selected_fob select 1;

closedialog 0;

private _result = [localize "STR_DUWS_T_z54ibhvi", format [localize "STR_DUWS_T_dnbpdk0f", _selected_fob_name], true, true] call BIS_fnc_guiMessage;
if (_result) then {
	[_selected_fob,_selected_fob_pos,_selected_fob_name] remoteExec ["fnc_FOB_cleanup", 2, false];
};	

