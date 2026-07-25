// Locality: client -- passed as an addAction function value in
// client/misc/fnc_addHQOfficerActions.sqf and shared/functions/fnc_FOBactions.sqf, so it runs on
// whoever opens the dialog.
_handle = createDialog "squad_mng_dialog";
waitUntil {sleep 0.1;dialog};

