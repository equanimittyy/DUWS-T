// Locality: all machines; the addAction body below runs on the machine that triggers it, not
// here (fnc_civ_arrest remoteExecs this to target 0 once a civilian has surrendered).
//
// The second half of an arrest, and deliberately still a scroll action rather than a menu row:
// it works at 3 m on a civilian standing still with their hands up, and the interaction menu --
// which opens at arrest range and hides on isSurrendered -- would have to close, wait out the
// animation and reopen to offer it.
params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    format ["<t color='#ffaa00'>%1</t>", localize "STR_DUWS_T_LOOT"],
    {
        params ["_target", "_caller", "_actionId"];
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT1"] remoteExec ["fnc_duws_dialogue", _caller];

        // Removed first: the roll below sleeps, and a second click inside that window would run
        // the whole table again.
        _target removeAction _actionId;

        private _roll = random 1;
        private _items = [];
        private _hintMsg = "";
        sleep 3;

        if (_roll < 0.10) then {
            // Intel and electronics drop a random subset rather than the whole pool, so two
            // searches of the same tier are not the same haul.
            private _intelPool = ["Item_Files", "Item_Wallet_traitor", "Item_FlashDisk"];
            private _dropCount = 1 + floor random (count _intelPool);
            for "_i" from 1 to _dropCount do {
                _items pushBack (selectRandom _intelPool);
            };
            [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT2"] remoteExec ["fnc_duws_dialogue", 0];
            _hintMsg = localize "STR_DUWS_T_LOOT_INTEL";
        } else {
            if (_roll < 0.30) then {
                // Weighted by repetition, not by a second roll: a plain phone is twice as likely
                // as a smartphone because it appears twice.
                private _elecPool = ["Item_SmartPhone", "Item_MobilePhone", "Item_MobilePhone"];
                private _dropCount = 1 + floor random (count _elecPool);
                for "_i" from 1 to _dropCount do {
                    _items pushBack (selectRandom _elecPool);
                };
                [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT3"] remoteExec ["fnc_duws_dialogue", 0];
                _hintMsg = localize "STR_DUWS_T_LOOT_ELECTRONICS";
            } else {
                if (_roll < 0.60) then {
                    _items = ["Item_Money_roll", "Item_Money_roll", "Item_Money_roll", "Item_Money_roll","Item_Money_roll", "Item_Money_roll", "Item_Money_roll", "Item_Money_roll"];
                    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT4"] remoteExec ["fnc_duws_dialogue", 0];
                    _hintMsg = localize "STR_DUWS_T_LOOT_MONEY2";
                } else {
                    if (_roll < 0.85) then {
                        _items = ["Item_Money_roll","Item_Money_roll"];
                        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT5"] remoteExec ["fnc_duws_dialogue", 0];
                        _hintMsg = localize "STR_DUWS_T_LOOT_MONEY1";
                    } else {
                        _items = [];
                        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT6"] remoteExec ["fnc_duws_dialogue", 0];
                        _hintMsg = localize "STR_DUWS_T_LOOT_NOTHING";
                    };
                };
            };
        };

        if (count _items > 0) then {
            [_items, getPosATL _target] spawn {
                params ["_items", "_basePosATL"];
                {
                    private _obj = createVehicle [_x, [0,0,0], [], 0, "CAN_COLLIDE"];
                    private _angle = random 360;
                    private _dist = random 1;
                    private _spawnPos = _basePosATL getPos [_dist, _angle];
                    _spawnPos set [2, (_basePosATL select 2) + 0.05];
                    _obj setPos _spawnPos;
                    _obj setDir random 360;
                    _obj enableSimulation true;
                    [_obj] spawn { sleep 60; deleteVehicle (_this select 0); };
                } forEach _items;
            };
        };

        hint _hintMsg;

        [_target, _caller] remoteExec ["fnc_civ_search_armed", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3 && {_target getVariable ['isSurrendered', false]}"
];

_unit setVariable ["civ_searchActionID", _actionID];
