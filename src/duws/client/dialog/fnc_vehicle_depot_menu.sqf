// Locality: client -- the addAction body for the HQ depot's "Vehicle Depot" action, so it runs on
// whoever opens it. Creates the unified dialog, stashes the pad-trigger netId for the async rebuilds
// (a store/retrieve/recycle round-trips the server, which remoteExecs fnc_depot_menu_fill back),
// sets the static button labels once, and fills the Landing Pad and garage lists.
if (!hasInterface) exitWith {};
params ["_trg"];
if (isNull _trg) exitWith {};

disableSerialization;
private _display = createDialog ["vehicledepotmenu", false];
if (isNull _display) exitWith {};

// uiNamespace, not the mission namespace: a display handle does not serialize, and the mission
// namespace is written into save games. The handle lets the fill target this display explicitly and
// null-check it when a server-triggered refill arrives after the dialog was closed.
uiNamespace setVariable ["DUWS_depotMenu_disp", _display];
uiNamespace setVariable ["DUWS_depotMenu_ctx", netId _trg];
// No garage list is selected on open, so Retrieve refuses until one is clicked.
uiNamespace setVariable ["DUWS_depotMenu_activeGarage", -1];

ctrlSetText [1000, format ["%1", missionNamespace getVariable ["commandpointsblu1", "--"]]];
ctrlSetText [1002, format ["%1", missionNamespace getVariable ["WARCOM_blufor_ap", "--"]]];

ctrlSetText [2012, format ["%1 (2CP)", localize "STR_DUWS_T_repair_vehicle"]];
ctrlSetText [2013, localize "STR_DUWS_T_check_vehicle_status"];
ctrlSetText [2014, localize "STR_DUWS_T_vehicle_appearance"];
ctrlSetText [2015, format ["%1 (5CP)", localize "STR_DUWS_T_vehicle_pylons"]];
ctrlSetText [2023, localize "STR_DUWS_T_GARAGE_STORE_BTN"];
ctrlSetText [2024, localize "STR_DUWS_T_GARAGE_RETRIEVE_BTN"];
ctrlSetText [2032, localize "STR_DUWS_T_recycleaction"];

[] call fnc_depot_menu_fill;
