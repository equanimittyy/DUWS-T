// Locality: client -- inherited from client/dialog/fnc_startup_faction_flow.sqf, which
// client_init.sqf gates on game_master, so this runs on the one machine driving setup.
//
// The faction confirmation screen: every role key both sides will field, side by side, with the
// classname resolution produced and a way to change or clear it before the campaign locks in.
//
// This is the first point in the flow where those classnames exist. Resolution is server-side,
// pulled ahead of the commit by the request below. Asking the server rather than resolving here
// keeps one resolution: fnc_factionGen picks at random in places, so a local preview and a later
// server build would disagree and the player would confirm a roster the campaign never fields.
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

// Pulsed rather than posted once: titleText fades itself out after a few seconds, and a resolution
// slower than that -- which is every heavy mod set -- left the player on an empty black screen with
// nothing to tell setup working from setup hung. A breathing line reads as a system still working
// where a static one reads as a screen that has stopped.
// titleFadeOut is what dissolves the card: titleText's speed argument times the card being posted
// and never the one already up, so posting "" to darken it would snap it off mid-pulse instead.
private _waiting = localize "STR_DUWS_T_faction_confirm_waiting";
private _pulse = [_waiting] spawn {
    params ["_text"];
    while {true} do {
        titleText [_text, "PLAIN", 1];
        sleep 2.2;      // the fade in, plus a beat held up to be read
        titleFadeOut 1.2;
        sleep 1.8;      // the fade out, plus a beat of dark to pulse against
    };
};

// The pulse runs beside the wait rather than inside it: a cycle's worth of sleeps in here would
// hold the screen shut for up to four seconds after resolution already answered.
waitUntil { sleep 0.1; duws_faction_preview_ready >= _request };
terminate _pulse;

// Solid from here. The steps below are short, and one more dark beat across them would read as the
// screen dropping out exactly as it was about to open. Speed 0 because whatever the pulse was
// mid-way through, the line should be up now.
titleText [_waiting, "PLAIN", 0];

// Snapshot of what resolution produced, one row per schema key. Read once here rather than off the
// globals per repaint, so an edit shows immediately without waiting on a server round trip.
// From the pool broadcast rather than the role globals: a global carries only the representative, and
// the screen shows the whole pool a spawn draws from. Falls back to the global for a key the broadcast
// never carried -- a pool-less role, or a resolution round that predates it.
private _previewPools = createHashMapFromArray (missionNamespace getVariable ["DUWS_factionPreviewPools", []]);
duws_faction_table = ["blufor", "opfor"] apply {
    private _side = _x;
    [_side, ([_side] call fnc_faction_schema) apply {
        private _k = _x select 0;
        [_k, _previewPools getOrDefault [_k, missionNamespace getVariable [_k, ""]]]
    }]
};

// Row colour lookup, keyed by role: 0 white (the faction's own first choice), 1 yellow (a lower
// rung or a borrow it still fills), 2 red (a vanilla stand-in, or a role it does not field). An edit
// drops the key to white -- a class the player picked is no longer a fallback.
duws_faction_tiers = createHashMap;
{ duws_faction_tiers set [_x select 0, _x select 1]; } forEach (missionNamespace getVariable ["DUWS_factionTiers", []]);

// The line stays up across the table build and the dialog opening, and is cleared only once the
// screen it was announcing is actually on -- clearing it at the end of the wait above put a gap of
// blank screen exactly where the player was already wondering whether anything was happening.
if (!createDialog "startup_faction_confirm") exitWith {
    titleFadeOut 0.3;
    ["ERROR", "FACTION", "Faction confirmation screen failed to open; skipping to the environment menu."] call fnc_log;
};
waitUntil { dialog };
titleFadeOut 0.3;
private _display = uiNamespace getVariable ["duws_faction_confirm_display", displayNull];

(_display displayCtrl 8603) ctrlSetStructuredText parseText format ["<t size='0.85'>%1</t>", localize "STR_DUWS_T_faction_confirm_intro"];
(_display displayCtrl 8604) ctrlSetStructuredText parseText format ["<t size='1' align='center' font='PuristaMedium' color='#3380ff'>%1</t>", localize "STR_DUWS_T_faction_confirm_blufor"];
(_display displayCtrl 8605) ctrlSetStructuredText parseText format ["<t size='1' align='center' font='PuristaMedium' color='#ff3333'>%1</t>", localize "STR_DUWS_T_faction_confirm_opfor"];
(_display displayCtrl 8607) ctrlSetStructuredText parseText format ["<t size='0.7' color='#c0c0c0'>%1</t>", localize "STR_DUWS_T_faction_confirm_footer"];

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
