// Locality: client -- the confirmation screen's own machine (fnc_faction_confirm.sqf).
//
// The confirmation screen's two prompts. They are overlay controls on that dialog rather than
// dialogs of their own: a second dialog stacked over it would leave the row buttons behind the
// prompt still live to the mouse. Raising one hides the other, greys the screen's own controls and
// drops a sheet over the table, so the only live controls are the prompt's two buttons.

#define CLEAR_CTRLS   [8640, 8641, 8642, 8643, 8644, 8645]
#define LOCK_CTRLS    [8650, 8651, 8652, 8653, 8654, 8655]
#define SCREEN_CTRLS  [8606, 8610, 8611]

fnc_faction_prompt_hide = {
    { ctrlShow [_x, false]; } forEach (CLEAR_CTRLS + LOCK_CTRLS);
    { ctrlEnable [_x, true]; } forEach SCREEN_CTRLS;
};

// Which key the clear prompt is about. Held here rather than passed through the button's action
// because a config-declared action has no arguments.
duws_faction_clear_key = "";

fnc_faction_prompt_clear = {
    params ["_key"];
    duws_faction_clear_key = _key;

    private _display = uiNamespace getVariable ["duws_faction_confirm_display", displayNull];
    (_display displayCtrl 8643) ctrlSetStructuredText parseText format ["<t size='0.8'>%1</t>", localize "STR_DUWS_T_faction_clear_text"];
    { ctrlEnable [_x, false]; } forEach SCREEN_CTRLS;
    { ctrlShow [_x, true]; } forEach CLEAR_CTRLS;
};

fnc_faction_key_clear = {
    private _key = duws_faction_clear_key;

    {
        private _rows = _x select 1;
        private _i = _rows findIf { (_x select 0) isEqualTo _key };
        if (_i >= 0) exitWith { _rows set [_i, [_key, ""]]; };
    } forEach duws_faction_table;

    [_key] call fnc_faction_row_paint;
    [] call fnc_faction_prompt_hide;
};

// Raised by CONTINUE. The warning line is appended only when a key is actually empty, so the
// prompt does not cry wolf on a complete pair of factions.
fnc_faction_prompt_lock = {
    private _missing = 0;
    private _standin = 0;
    private _tiers = missionNamespace getVariable ["duws_faction_tiers", createHashMap];
    {
        {
            private _key = _x select 0;
            private _v = _x select 1;
            private _pool = if (_v isEqualType []) then {_v} else {[_v]};
            if ((_pool select { _x isEqualType "" && {_x != ""} }) isEqualTo []) then {
                _missing = _missing + 1;
            } else {
                if ((_tiers getOrDefault [_key, 0]) == 2) then { _standin = _standin + 1; };
            };
        } forEach (_x select 1);
    } forEach duws_faction_table;

    private _body = format ["<t size='0.8'>%1</t>", localize "STR_DUWS_T_faction_lock_text"];
    if (_missing > 0) then {
        _body = _body + format ["<br/><br/><t size='0.75' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_lock_warn"];
    };
    // A present-but-vanilla stand-in is a gap the campaign papers over, worth its own line so the
    // player is not left reading a red row as an outright missing one.
    if (_standin > 0) then {
        _body = _body + format ["<br/><br/><t size='0.75' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_lock_warn_standin"];
    };

    private _display = uiNamespace getVariable ["duws_faction_confirm_display", displayNull];
    (_display displayCtrl 8653) ctrlSetStructuredText parseText _body;
    { ctrlEnable [_x, false]; } forEach SCREEN_CTRLS;
    { ctrlShow [_x, true]; } forEach LOCK_CTRLS;
};
