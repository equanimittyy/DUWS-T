// Locality: client -- inherited from init/client_init.sqf.
// fnc_duws_help.sqf
// Builds the single "DUWS-T Manual" subject in the map's Notes (diary) as a numbered
// outline: category headers (1., 2., ...) and their sub-topics (1.1, 1.2, ...), with
// a blank divider record between categories.
//
// Engine notes (docs/arma_engine_gotchas.md):
//  - The diary displays records newest-first, so the list is built top-down then
//    reversed before creation (the first row ends up on top).
//  - Record bodies are structured text: <br/> and <t ...> render, so records that
//    fold several topics separate them with inline <t> sub-headers.

// Sub-header + body, for records that merge several stringtable topics into one page.
private _sec = {
    params ["_titleId", "_bodyId"];
    "<t size='1.15' color='#e5b100'>" + (localize _titleId) + "</t><br/>" + (localize _bodyId)
};

private _economyBody = [
    ["STR_DUWS_T_uzx258em", "STR_DUWS_T_r3x8czon"] call _sec,          // Command Points
    ["STR_DUWS_T_x4vt0je3", "STR_DUWS_T_xs3zn5m2"] call _sec,          // Army Power
    ["STR_DUWS_T_HELP_ECO", "STR_DUWS_T_HELP_ECO_HINT"] call _sec      // Economy
] joinString "<br/><br/>";

private _reqForcesBody = [
    ["STR_DUWS_T_g4orlwp1", "STR_DUWS_T_t6bei9tk"] call _sec,          // Request Menu
    ["STR_DUWS_T_auhmznp6", "STR_DUWS_T_m267zqr7"] call _sec,          // Recruiting Operatives
    ["STR_DUWS_T_ulm497s5", "STR_DUWS_T_16wnqdrz"] call _sec           // Task Forces
] joinString "<br/><br/>";

private _suppArsBody = [
    ["STR_DUWS_T_o31d875x", "STR_DUWS_T_3c1ygiga"] call _sec,          // Supports
    ["STR_DUWS_T_arsenal", "STR_DUWS_T_arsenal1"] call _sec,           // Arsenal System
    ["STR_DUWS_T_HELP_SUPPORTS", "STR_DUWS_T_HELP_SUPPORTS_HINT"] call _sec  // Unlocking the Arsenal
] joinString "<br/><br/>";

// Outline row: ["<n>", labelId, body] -> ["<n> <localized label>", body].
private _rec = {
    params ["_num", "_labelId", "_body"];
    [_num + " " + (localize _labelId), _body]
};
private _divider = ["", ""];

// Records in display order, top first.
private _records = [
    ["1.",  "STR_DUWS_T_MAN_HOWTO",           ""] call _rec,
    ["1.1", "STR_DUWS_T_MAN_L_OBJECTIVE",     localize "STR_DUWS_T_MAN_B_OBJECTIVE"] call _rec,
    ["1.2", "STR_DUWS_T_MAN_ECONOMY",         _economyBody] call _rec,
    ["1.3", "STR_DUWS_T_MAN_L_ZONES",         localize "STR_DUWS_T_HELP_ZONES_HINT"] call _rec,
    ["1.4", "STR_DUWS_T_MAN_REQFORCES",       _reqForcesBody] call _rec,
    ["1.5", "STR_DUWS_T_4yxb8s2k",            localize "STR_DUWS_T_4elv35h6"] call _rec,       // Establish a FOB
    ["1.6", "STR_DUWS_T_MAN_SUPPARS",         _suppArsBody] call _rec,
    ["1.7", "STR_DUWS_T_MAN_L_SUPPDETAIL",    localize "STR_DUWS_T_zhiyuan1"] call _rec,
    ["1.8", "STR_DUWS_T_MAN_L_SIDEMISSIONS",  localize "STR_DUWS_T_617kjc41"] call _rec,
    ["1.9", "STR_DUWS_T_MAN_L_REPUTATION",    localize "STR_DUWS_T_m204wqqq"] call _rec,
    _divider,
    ["2.",  "STR_DUWS_T_MAN_CIV",             ""] call _rec,
    ["2.1", "STR_DUWS_T_MAN_L_OVERVIEW",      localize "STR_DUWS_T_MAN_CIV_BODY"] call _rec,
    ["2.2", "STR_DUWS_T_RAVAGE_HELP_TITLE",   localize "STR_DUWS_T_RAVAGE_HELP_DESC"] call _rec,
    ["2.3", "STR_DUWS_T_WBK_HELP_TITLE",      localize "STR_DUWS_T_WBK_HELP_DESC"] call _rec,
    _divider,
    ["3.",  "STR_DUWS_T_MAN_CONFIG",          ""] call _rec,
    ["3.1", "STR_DUWS_T_shijianguanli",       localize "STR_DUWS_T_shijianguanli2"] call _rec, // Time Management
    ["3.2", "STR_DUWS_T_ojav7yf4",            localize "STR_DUWS_T_d38s8oac"] call _rec,        // Hardcore Mode
    ["3.3", "STR_DUWS_T_siwang",              localize "STR_DUWS_T_siwang2"] call _rec,         // Death Penalty
    ["3.4", "STR_DUWS_T_zimuxitong",          ([localize "STR_DUWS_T_zimuxitong2"] call fnc_cs)] call _rec,     // Subtitles
    ["3.5", "STR_DUWS_T_ty006zz4",            localize "STR_DUWS_T_8o0fomss"] call _rec,         // Saving
    ["3.6", "STR_DUWS_T_ljw9ndqz",            localize "STR_DUWS_T_nk0wa9zo"] call _rec,         // Multiplayer
    _divider,
    ["4.",  "STR_DUWS_T_MAN_L_ABOUTCRED",     ""] call _rec,
    ["4.1", "STR_DUWS_T_0f4f5uo2",            localize "STR_DUWS_T_q4wns5y7"] call _rec,          // About DUWS-T
    ["4.2", "STR_DUWS_T_7vfkrl61",            localize "STR_DUWS_T_zho04a1k"] call _rec,          // Credits
    ["4.3", "STR_DUWS_T_getwuiuy",            localize "STR_DUWS_T_6ku0lc19"] call _rec           // Feedback / bug report
];

player createDiarySubject ["duws_manual", localize "STR_DUWS_T_3feql12c"];
reverse _records;
{ player createDiaryRecord ["duws_manual", _x] } forEach _records;
