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
            // The money/intel the player carries IS their balance, and the swap below would wipe it.
            // Stash it out and re-grant after, the same shape the arsenal enforcer uses. Stashed
            // before the pool deposit so cash never banks as captured gear (the deposit reads the live
            // loadout, and money is not friendly gear).
            private _moneyStash = call DUWS_fnc_money_stash;

            // The kit overwrites the whole loadout, so any foreign gear it displaces is banked to the
            // captured pool first -- hybrid only, since Full mode never draws the pool. The server
            // classifies the pre-swap loadout and keeps only what is not standard issue.
            if ((["DUWS_ArsenalMode", 0] call BIS_fnc_getParamValue) == 0) then {
                [getUnitLoadout player] remoteExec ["fnc_captured_pool_deposit_loadout", 2];
            };
            player setUnitLoadout _loadout;

            private _dropPairs = [_moneyStash] call DUWS_fnc_money_regrant;
            private _moneyDropped = 0;
            { if ((_x select 0) isEqualTo "Money_roll") then { _moneyDropped = _x select 1; }; } forEach _dropPairs;
            if (_moneyDropped > 0) then {
                hint format [localize "STR_DUWS_ARSENAL_MONEY_DROPPED", _moneyDropped];
            } else {
                hint format [localize "STR_DUWS_T_CHANGED_TO", _displayName];
            };
        },
        [_loadout, _displayName]
    ]
}] call fnc_open_action_menu;
