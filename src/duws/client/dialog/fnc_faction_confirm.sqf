// Locality: client -- inherited from client/dialog/fnc_startup_faction_flow.sqf, which
// client_init.sqf gates on game_master, so this runs on the one machine driving setup.
//
// The faction confirmation screen: every role key both sides will field, side by side, with the
// classname resolution produced and a way to change or clear it before the campaign locks in.
//
// This is the first point in the flow where those classnames exist. Resolution is server-side and
// used to sit behind the commit; the request below is what pulls it forward. Asking the server
// rather than resolving here keeps one resolution: fnc_factionGen picks at random in places, so a
// local preview and a later server build would disagree and the player would confirm a roster the
// campaign never fields.
//
// The working table (duws_faction_table) is edited in place by the key editor and the clear
// prompt, then published whole at the bottom of this file when the player confirms.

duws_faction_confirm_back = false;
duws_faction_confirm_done = false;

// Dropped now rather than overwritten at the end: if this pass never reaches a confirm, the commit
// must fall back to what the server resolved, not to the table a previous pass locked in.
duws_faction_locked = [];
publicVariable "duws_faction_locked";

// Cleared per screen: the parse a key edit runs is per faction and expensive, and a faction's
// buckets do not change within one visit to this screen.
uiNamespace setVariable ["duws_faction_parse_cache", createHashMap];

// Asked for by number: a Back through the setup screens brings the player here again with a
// different pick, and waiting on the count rather than a flag is what stops this round reading the
// previous round's rows.
duws_faction_preview_request = duws_faction_preview_request + 1;
private _request = duws_faction_preview_request;
publicVariable "duws_faction_preview_request";

titleText [localize "STR_DUWS_T_faction_confirm_waiting", "PLAIN", 0.3];
waitUntil { sleep 0.2; duws_faction_preview_ready >= _request };
titleText ["", "PLAIN", 0.3];

// Snapshot of what resolution produced, one row per schema key. Read once here rather than off the
// globals per repaint, so an edit shows immediately without waiting on a server round trip.
duws_faction_table = ["blufor", "opfor"] apply {
    private _side = _x;
    [_side, ([_side] call fnc_faction_schema) apply {
        [_x select 0, missionNamespace getVariable [_x select 0, ""]]
    }]
};

if (!createDialog "startup_faction_confirm") exitWith {
    ["ERROR", "FACTION", "Faction confirmation screen failed to open; skipping to the environment menu."] call fnc_log;
};
waitUntil { dialog };
private _display = uiNamespace getVariable ["duws_faction_confirm_display", displayNull];

ctrlSetStructuredText [8603, parseText format ["<t size='0.85'>%1</t>", localize "STR_DUWS_T_faction_confirm_intro"]];
ctrlSetStructuredText [8604, parseText format ["<t size='1' align='center' font='PuristaMedium' color='#3380ff'>%1</t>", localize "STR_DUWS_T_faction_confirm_blufor"]];
ctrlSetStructuredText [8605, parseText format ["<t size='1' align='center' font='PuristaMedium' color='#ff3333'>%1</t>", localize "STR_DUWS_T_faction_confirm_opfor"]];
ctrlSetStructuredText [8607, parseText format ["<t size='0.7' color='#c0c0c0'>%1</t>", localize "STR_DUWS_T_faction_confirm_footer"]];

{ (_display displayCtrl _x) ctrlSetFont "PuristaMedium"; } forEach [8602, 8642, 8652];

[] call fnc_faction_prompt_hide;
[] call fnc_faction_confirm_rows;

waitUntil { sleep 0.1; duws_faction_confirm_back || duws_faction_confirm_done };

// Published before the screen closes so the commit has the table even if the player's next step is
// immediate. Back publishes nothing: the flow restarts and resolution runs again.
if (duws_faction_confirm_done) then {
    duws_faction_locked = duws_faction_table;
    publicVariable "duws_faction_locked";
};

closeDialog 0;
uiNamespace setVariable ["duws_faction_confirm_display", displayNull];
