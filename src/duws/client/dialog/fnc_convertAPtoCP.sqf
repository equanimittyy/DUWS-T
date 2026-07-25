// Locality: client -- invoked from a dialog action.
// The AP debit is the half that must be authoritative: this is the mission's only path
// that turns one pool into another, so two clients converting the same 15 AP would each
// be credited 10 CP while the floor absorbed the second debit -- CP from nothing.
if !(["AP", 15] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_nysmk8sa";};

[10, "ap_to_cp_conversion"] remoteExec ["fnc_cp_adjust", 2];

ctrlSetText [1000, format["%1",commandpointsblu1]];
// Read the pool rather than subtracting: fnc_pool_spend only returns once the server has
// applied and broadcast the debit, so the local copy is the post-spend value by now.
// There is no AP publicVariableEventHandler to correct 1002 if that ever slips.
ctrlSetText [1002, format["%1",WARCOM_blufor_ap]];

hint localize "STR_DUWS_T_vvmvw9ia";
