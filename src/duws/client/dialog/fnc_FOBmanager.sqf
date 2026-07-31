// Locality: client -- a command-column button body in the request menu, so it runs on whoever opens the manager.


if (count Array_of_FOBname < 1) exitWith {hint localize "STR_DUWS_T_2q33n8h7"};

_handle = createDialog "fob_mng_dialog";
waitUntil {dialog};

// FAST TRAVEL LIST BEGIN - -
// CREATE THE ARRAY OF FOBS w/ POSITION
_array_of_fobs_list = [];  // init the array of fobs
_listFT = [];
_index = -1;
{
    _array_of_fobs_list = _array_of_fobs_list + [[getpos _x]]; // add the FOB (pos) into a nested array

    _index = _index + 1;
    _array_of_fobs_list_selected = _array_of_fobs_list select _index; // select the current array inside _array_of_fobs_list

    _actual_fobname = Array_of_FOBname select _index;
    _array_of_fobs_list_selected = _array_of_fobs_list_selected + [_actual_fobname];

    _listFT = _listFT + [_array_of_fobs_list_selected];
} forEach Array_of_FOBS;

// add the base
_hqpos = PosOfBLUHQ;
_listFT = _listFT + [[_hqpos,"Main Base"]];

if (enable_fast_travel) then {  
    // FOB FT
    {
        _fobname = _x select 1;
        _index = lbAdd [2100, _fobname];
    } forEach _listFT;
    lbSetCurSel [2100, 0];
}
else
{
    _index = lbAdd [2100, "FT Disabled"];
    lbSetCurSel [2100, 0];
};
// FAST TRAVEL LIST END - -

// REINFORCE LIST BEGIN
// CREATE THE ARRAY OF FOBS w/ POSITION
_index = -1;
_listREMOV = [];
_array_of_fobs_list = [];  // init the array of fobs

{
    _array_of_fobs_list = _array_of_fobs_list + [[getpos _x]]; // add the FOB (pos) into a nested array

    _index = _index + 1;
    _array_of_fobs_list_selected = _array_of_fobs_list select _index; // select the current array inside _array_of_fobs_list

    _actual_fobname = Array_of_FOBname select _index;
    _array_of_fobs_list_selected = _array_of_fobs_list_selected + [_actual_fobname];

    _listREMOV = _listREMOV + [_array_of_fobs_list_selected];
} forEach Array_of_FOBS;
   
{
    _fobname = _x select 1;
    _index = lbAdd [2101, _fobname];
} forEach _listREMOV;
lbSetCurSel [2101, 0];


