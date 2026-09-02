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
            // Scheduled thread: the settle below waits on the server's reply, and this fires from an
            // unscheduled UI button handler, where waitUntil is illegal.
            [_loadout, _displayName] spawn {
                params ["_loadout", "_displayName"];
                // The money/intel the player carries IS their balance, and setUnitLoadout would wipe it.
                // Stash it out and re-grant after, the same shape the arsenal enforcer uses. Stashed
                // before the settle so cash is out of both loadouts and never banks as captured gear.
                private _moneyStash = call DUWS_fnc_money_stash;

                private _old = getUnitLoadout player;
                player setUnitLoadout _loadout;

                // The swap is an arsenal edit from _old to the kit, so settle it exactly like the arsenal
                // close: the server nets close-open per class -- deposits gear the kit drops, draws gear
                // it adds (capped at stock), and replies the overdraw to strip off the equipped kit, so a
                // depleted pool yields a partial kit, never free gear. Full (mode 1) never touches the
                // pool. Same path as DUWS_fnc_arsenal_unstock.
                if ((["DUWS_ArsenalMode", 0] call BIS_fnc_getParamValue) != 1) then {
                    private _new = getUnitLoadout player;
                    duws_pool_seq = (missionNamespace getVariable ["duws_pool_seq", 0]) + 1;
                    private _replyVar = format ["duws_pool_reply_%1", duws_pool_seq];
                    [_old, _new, player, _replyVar] remoteExec ["fnc_captured_pool_settle", 2];
                    private _deadline = diag_tickTime + 5;
                    waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
                    private _excess = (missionNamespace getVariable [_replyVar, [false, []]]) select 1;
                    missionNamespace setVariable [_replyVar, nil];
                    { _x params ["_cls", "_ex"]; [_cls, _ex] call DUWS_fnc_strip_n; } forEach _excess;
                };

                private _dropPairs = [_moneyStash] call DUWS_fnc_money_regrant;
                private _moneyDropped = 0;
                { if ((_x select 0) isEqualTo "Money_roll") then { _moneyDropped = _x select 1; }; } forEach _dropPairs;
                if (_moneyDropped > 0) then {
                    hint format [localize "STR_DUWS_ARSENAL_MONEY_DROPPED", _moneyDropped];
                } else {
                    hint format [localize "STR_DUWS_T_CHANGED_TO", _displayName];
                };
            };
        },
        [_loadout, _displayName]
    ]
}] call fnc_open_action_menu;
