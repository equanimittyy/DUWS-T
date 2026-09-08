// Locality: client -- fills the depot dialog's Landing Pad list, the three garage lists, and the
// header readouts. Called by the opener (client/dialog/fnc_vehicle_depot_menu.sqf) and remoteExec'd
// back to the caller by each server store/retrieve/recycle so the menu reflects the committed change.
//
// Guarded on the stored display handle: a server-triggered refill can arrive after the player closed
// the dialog, and isNull on the handle detects that (the gotchas doc's UI-handle idiom). While the
// dialog is open it is the top dialog, so the bare-idc listbox commands land on it.
if (!hasInterface) exitWith {};
if (isNull (uiNamespace getVariable ["DUWS_depotMenu_disp", displayNull])) exitWith {};
private _trg = objectFromNetId (uiNamespace getVariable ["DUWS_depotMenu_ctx", ""]);
if (isNull _trg) exitWith {};

private _pad = (vehicles inAreaArray _trg) select { count crew _x == 0 };
private _caps = [] call DUWS_fnc_garageCaps;
private _used = [] call DUWS_fnc_garageUsed;
private _stored = missionNamespace getVariable ["DUWS_garage_stored", []];

// Clear and rebuild unscheduled so the lists never render empty for a frame -- the callers are all
// scheduled (opener spawned, refill follows a server round-trip), where the engine can suspend right
// after an lbClear. Same reason as client/dialog/fnc_support_list_fill.sqf.
isNil {
    // Landing pad: the empty pad vehicles, alphabetical; netId in lbData.
    lbClear 2011;
    {
        private _name = getText (configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
        private _i = lbAdd [2011, _name];
        lbSetData [2011, _i, netId _x];
    } forEach _pad;
    lbSort [2011, "ASC"];

    // Garage, one list per domain; lbData keeps the FLAT stored index so Retrieve is domain-agnostic.
    { lbClear _x; } forEach [2021, 2022, 2025];
    {
        _x params ["_cls"];
        private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
        private _hp = round ((1 - (_x select 4)) * 100);
        private _fuel = round ((_x select 5) * 100);
        // param, not select: a spec stored before ammo was tracked has no index 7. -1 marks an unarmed
        // hull (or an untracked spec), which drops the ammo readout.
        private _ammoFrac = _x param [7, -1];
        private _idc = switch ([_cls] call DUWS_fnc_vehDomain) do {
            case "air":  { 2022 };
            case "boat": { 2025 };
            default      { 2021 };
        };
        private _rowText = if (_ammoFrac < 0) then {
            format [localize "STR_DUWS_T_GARAGE_STORED_ROW_NOAMMO", _name, _hp, _fuel]
        } else {
            format [localize "STR_DUWS_T_GARAGE_STORED_ROW", _name, _hp, _fuel, round (_ammoFrac * 100)]
        };
        private _row = lbAdd [_idc, _rowText];
        lbSetData [_idc, _row, str _forEachIndex];
    } forEach _stored;
    { lbSort [_x, "ASC"]; } forEach [2021, 2022, 2025];

    // Header readouts. CP/AP refreshed here too: the host's own publicVariableEventHandler does not
    // fire for its own broadcast, so a server-side debit would not otherwise reach the host's boxes.
    ctrlSetText [1000, format ["%1", missionNamespace getVariable ["commandpointsblu1", "--"]]];
    ctrlSetText [1002, format ["%1", missionNamespace getVariable ["WARCOM_blufor_ap", "--"]]];
    ctrlSetText [2003, format [localize "STR_DUWS_T_GARAGE_POOL_LAND", _used select 0, _caps select 0]];
    ctrlSetText [2004, format [localize "STR_DUWS_T_GARAGE_POOL_AIR",  _used select 1, _caps select 1]];
    ctrlSetText [2005, format [localize "STR_DUWS_T_GARAGE_POOL_BOAT", _used select 2, _caps select 2]];
};
