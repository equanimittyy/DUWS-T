// Locality: client -- opens a dialog, so it runs on whoever triggered it.
// Shared by the HQ supply crate action and the killhouse terminals. The loadout list is
// scanned and broadcast by the server; a second copy of this menu would drift from it.
if (!hasInterface) exitWith {};

private _loadouts = missionNamespace getVariable ["blufor_quickChange_loadouts_scanned", []];
if (_loadouts isEqualTo []) exitWith { hint localize "STR_DUWS_T_QUICK_KITS_NONE"; };

[localize "STR_DUWS_T_QUICK_KITS", _loadouts apply {
    _x params ["_className", "_displayName", "_loadout"];
    [
        format [localize "STR_DUWS_T_CHANGE_TO", _displayName],
        {
            params ["_loadout", "_displayName"];
            player setUnitLoadout _loadout;
            hint format [localize "STR_DUWS_T_CHANGED_TO", _displayName];
        },
        [_loadout, _displayName]
    ]
}] call fnc_open_action_menu;
