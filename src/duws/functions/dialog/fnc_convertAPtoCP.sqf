// Locality: client -- invoked from a dialog action.
if (WARCOM_blufor_ap < 15) exitWith {hint localize "STR_DUWS_T_nysmk8sa";};

[10] remoteExec ["fnc_cp_adjust", 2];
["BLU", -15] remoteExec ["fnc_ap_adjust", 2];

ctrlSetText [1000, format["%1",commandpointsblu1]];
// The spend lands on the server, so the local copy still holds the pre-spend value
// here, and no AP publicVariableEventHandler exists to repaint 1002 when the
// broadcast arrives. Show the expected total; the broadcast reconciles it.
ctrlSetText [1002, format["%1",WARCOM_blufor_ap - 15]];

hint localize "STR_DUWS_T_vvmvw9ia";
