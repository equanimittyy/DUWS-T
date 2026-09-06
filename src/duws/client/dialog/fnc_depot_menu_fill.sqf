// Locality: client -- fills the depot dialog's three panels, the header readouts and the tier
// ladder. Called by the opener (client/dialog/fnc_vehicle_depot_menu.sqf) and remoteExec'd back to
// the caller by each server store/retrieve/buy/recycle so the menu reflects the committed change.
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
private _nextRow = [] call DUWS_fnc_garageNextTier;
private _nextKey = if (_nextRow isEqualTo []) then { "" } else { _nextRow select 0 };
uiNamespace setVariable ["DUWS_depot_nextTier", _nextKey];

// Clear and rebuild unscheduled so the lists never render empty for a frame -- the callers are all
// scheduled (opener spawned, refill follows a server round-trip), where the engine can suspend right
// after an lbClear. Same reason as client/dialog/fnc_support_list_fill.sqf.
isNil {
    // Modification and Recycle both list the empty pad vehicles; identity (netId) rides in lbData.
    lbClear 2011;
    lbClear 2031;
    {
        private _name = getText (configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
        private _nid = netId _x;
        private _mi = lbAdd [2011, _name];
        lbSetData [2011, _mi, _nid];
        private _reward = [_x] call DUWS_fnc_vehicleRecycleReward;
        private _ri = lbAdd [2031, format ["%1 (%2 CP)", _name, _reward]];
        lbSetData [2031, _ri, _nid];
    } forEach _pad;

    // Stored vehicles, lbData = stored index; a short state summary rides in the label.
    lbClear 2021;
    {
        private _cls = _x select 0;
        private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
        private _hp = round ((1 - (_x select 4)) * 100);
        private _fuel = round ((_x select 5) * 100);
        private _si = lbAdd [2021, format [localize "STR_DUWS_T_GARAGE_STORED_ROW", _name, _hp, _fuel]];
        lbSetData [2021, _si, str _forEachIndex];
    } forEach (missionNamespace getVariable ["DUWS_garage_stored", []]);

    // Capacity ladder. Colour carries state: green owned, orange the affordable next level, grey an
    // AP-rung-locked level (tier-tagged), white a reachable level still behind an unbought one.
    lbClear 2022;
    {
        _x params ["_key", "_l", "_a", "_b", "_cp", "_ap", "_apTier", "_flag", "_labelKey"];
        if (_flag != "") then {
            private _owned = missionNamespace getVariable [_flag, false];
            private _rungOk = ["BLU", _apTier] call DUWS_fnc_ap_unlocked;
            private _label = format ["%1: %2/%3/%4", localize _labelKey, _l, _a, _b];
            private _colour = [1, 1, 1, 1];
            if (_owned) then {
                _colour = [0, 1, 0, 1];
            } else {
                _label = _label + ([_cp, _ap] call fnc_support_cost_bracket);
                if (!_rungOk) then {
                    _label = _label + " " + format [localize "STR_DUWS_T_tier_tag", [_apTier] call DUWS_fnc_tierName];
                    _colour = [0.5, 0.5, 0.5, 1];
                } else {
                    if (_key == _nextKey) then { _colour = [1, 0.502, 0, 1]; };
                };
            };
            private _li = lbAdd [2022, _label];
            lbSetData [2022, _li, _key];
            lbSetColor [2022, _li, _colour];
        };
    } forEach DUWS_garage_tiers;

    // Header readouts. CP/AP refreshed here too: the host's own publicVariableEventHandler does not
    // fire for its own broadcast, so a server-side debit would not otherwise reach the host's boxes.
    ctrlSetText [1000, format ["%1", missionNamespace getVariable ["commandpointsblu1", "--"]]];
    ctrlSetText [1002, format ["%1", missionNamespace getVariable ["WARCOM_blufor_ap", "--"]]];
    ctrlSetText [2003, format [localize "STR_DUWS_T_GARAGE_POOL_LAND", _used select 0, _caps select 0]];
    ctrlSetText [2004, format [localize "STR_DUWS_T_GARAGE_POOL_AIR",  _used select 1, _caps select 1]];
    ctrlSetText [2005, format [localize "STR_DUWS_T_GARAGE_POOL_BOAT", _used select 2, _caps select 2]];

    // Buy button names the next level's live price, or reads as maxed once all four are owned.
    private _buyLabel = localize "STR_DUWS_T_GARAGE_MAXED";
    if !(_nextRow isEqualTo []) then {
        _nextRow params ["", "", "", "", "_ncp", "_nap"];
        _buyLabel = (localize "STR_DUWS_T_GARAGE_BUY_BTN") + ([_ncp, _nap] call fnc_support_cost_bracket);
    };
    ctrlSetText [2025, _buyLabel];
};
