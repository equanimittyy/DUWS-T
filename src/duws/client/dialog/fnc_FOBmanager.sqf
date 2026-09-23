// Locality: client -- a command-column button body in the request menu, so it runs on whoever opens the manager.

if (count Array_of_FOBname < 1) exitWith {hint localize "STR_DUWS_T_2q33n8h7"};

createDialog "fob_mng_dialog";
waitUntil {dialog};

// Row order is the array's: fnc_FOB_remove reads the selection back as an index into Array_of_FOBS.
{ lbAdd [2101, _x] } forEach Array_of_FOBname;
lbSetCurSel [2101, 0];
