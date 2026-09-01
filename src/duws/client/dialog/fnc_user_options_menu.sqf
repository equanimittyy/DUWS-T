// Locality: client. Per-player display/audio options, opened from the medical tent. Every setting
// lives in profileNamespace (the player's profile, not the campaign save), so each co-op client
// keeps its own choice and it survives death and reload with no server state. The three visibility
// toggles work by flag alone: the earplugs, disguise and view-distance actions read these same
// flags in their addAction conditions, so hiding one takes effect on the next frame with no re-add.
//
// Re-opens itself after each toggle so the row labels reflect the new state; fnc_open_action_menu
// closes before running a row's code, so the fresh dialog replaces rather than stacks.
if (!hasInterface) exitWith {};

// Music flag is stored inverted (true = muted), so read and show it as "music on".
private _musicOn = !(profileNamespace getVariable ["DUWS_T_muteMissionMusic", false]);
private _earOn   = profileNamespace getVariable ["DUWS_T_showEarplugs", true];
private _disgOn  = profileNamespace getVariable ["DUWS_T_showDisguise", true];
private _vdOn    = profileNamespace getVariable ["DUWS_T_showViewDist", true];

private _label = {
    params ["_nameKey", "_on"];
    format ["%1 %2: %3",
        localize "STR_DUWS_T_USEROPT_TOGGLE",
        localize _nameKey,
        localize (["STR_DUWS_T_USEROPT_OFF", "STR_DUWS_T_USEROPT_ON"] select _on)];
};

private _green = [0.082, 1, 0, 1];

[localize "STR_DUWS_T_USEROPT_TITLE", [
    [
        ["STR_DUWS_T_USEROPT_MUSIC", _musicOn] call _label,
        {
            private _muted = !(profileNamespace getVariable ["DUWS_T_muteMissionMusic", false]);
            profileNamespace setVariable ["DUWS_T_muteMissionMusic", _muted];
            saveProfileNamespace;
            hint format [localize "STR_DUWS_T_USEROPT_HINT",
                localize "STR_DUWS_T_USEROPT_MUSIC",
                localize (["STR_DUWS_T_USEROPT_OFF", "STR_DUWS_T_USEROPT_ON"] select (!_muted))];
            [] call fnc_user_options_menu;
        },
        [],
        _green
    ],
    [
        ["STR_DUWS_T_USEROPT_EARPLUGS", _earOn] call _label,
        {
            private _show = !(profileNamespace getVariable ["DUWS_T_showEarplugs", true]);
            profileNamespace setVariable ["DUWS_T_showEarplugs", _show];
            saveProfileNamespace;
            // Hiding the action with earplugs still in would strand the volume down with no way
            // back up, so lift them here (fnc_earplugs marks them in via soundVolume 0.15).
            if (!_show && soundVolume == 0.15) then { 1 fadeSound 1; };
            hint format [localize "STR_DUWS_T_USEROPT_HINT",
                localize "STR_DUWS_T_USEROPT_EARPLUGS",
                localize (["STR_DUWS_T_USEROPT_OFF", "STR_DUWS_T_USEROPT_ON"] select _show)];
            [] call fnc_user_options_menu;
        },
        [],
        _green
    ],
    [
        ["STR_DUWS_T_USEROPT_DISGUISE", _disgOn] call _label,
        {
            private _show = !(profileNamespace getVariable ["DUWS_T_showDisguise", true]);
            profileNamespace setVariable ["DUWS_T_showDisguise", _show];
            saveProfileNamespace;
            hint format [localize "STR_DUWS_T_USEROPT_HINT",
                localize "STR_DUWS_T_USEROPT_DISGUISE",
                localize (["STR_DUWS_T_USEROPT_OFF", "STR_DUWS_T_USEROPT_ON"] select _show)];
            [] call fnc_user_options_menu;
        },
        [],
        _green
    ],
    [
        ["STR_DUWS_T_USEROPT_VIEWDIST", _vdOn] call _label,
        {
            private _show = !(profileNamespace getVariable ["DUWS_T_showViewDist", true]);
            profileNamespace setVariable ["DUWS_T_showViewDist", _show];
            saveProfileNamespace;
            hint format [localize "STR_DUWS_T_USEROPT_HINT",
                localize "STR_DUWS_T_USEROPT_VIEWDIST",
                localize (["STR_DUWS_T_USEROPT_OFF", "STR_DUWS_T_USEROPT_ON"] select _show)];
            [] call fnc_user_options_menu;
        },
        [],
        _green
    ]
]] call fnc_open_action_menu;
