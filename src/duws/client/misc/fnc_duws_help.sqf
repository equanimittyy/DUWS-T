// Locality: client -- inherited from client/client_init.sqf.
// fnc_duws_help.sqf
// Builds the single "DUWS-T Manual" subject in the map's Notes (diary) as one
// record (page) per top-level topic, each led by its heading banner. Sub-topics
// that don't warrant their own page fold into the owning page as inline <t>
// sub-headers.
//
// Engine notes (docs/info/arma_engine_gotchas.md):
//  - The diary displays records newest-first, so the list is built top-down then
//    reversed before creation (the first row ends up on top).
//  - Record bodies are structured text: <br/>, <t ...> and <img .../> render.
//  - Banner path uses format, not "...image\"+leaf: a backslash right before a
//    string's closing quote can be mis-read by the CfgFunctions preprocessor.

// Heading banner for a page: the topic strip, then a gap before the body.
private _bnr = {
    format ["<img image='image\%1' width='350' height='40'/><br/><br/>", _this]
};
// Sub-header + body, for topics folded into a page as one section.
private _sec = {
    params ["_titleId", "_bodyId"];
    "<t size='1.15' color='#4da6ff'>" + (localize _titleId) + "</t><br/>" + (localize _bodyId)
};

private _coverBody =
    "<img image='image\duws_t_man_cover.jpg' width='456' height='257'/><br/><br/>"
    + (localize "STR_DUWS_T_MAN_COVER_BODY");

private _howToBody = ("duws_t_man_how_to_play.jpg" call _bnr) + ([
    ["STR_DUWS_T_MAN_L_OBJECTIVE",    "STR_DUWS_T_MAN_B_OBJECTIVE"] call _sec,
    ["STR_DUWS_T_MAN_L_ZONES",        "STR_DUWS_T_HELP_ZONES_HINT"] call _sec,
    ["STR_DUWS_T_g4orlwp1",           "STR_DUWS_T_t6bei9tk"] call _sec,      // Request Menu
    ["STR_DUWS_T_auhmznp6",           "STR_DUWS_T_m267zqr7"] call _sec,      // Recruiting Operatives
    ["STR_DUWS_T_ulm497s5",           "STR_DUWS_T_16wnqdrz"] call _sec,      // Task Forces
    ["STR_DUWS_T_4yxb8s2k",           "STR_DUWS_T_4elv35h6"] call _sec,      // Establish a FOB
    ["STR_DUWS_T_arsenal",            "STR_DUWS_T_arsenal1"] call _sec,      // Arsenal System
    ["STR_DUWS_T_HELP_SUPPORTS",      "STR_DUWS_T_HELP_SUPPORTS_HINT"] call _sec, // Unlocking the Arsenal
    ["STR_DUWS_T_MAN_L_SIDEMISSIONS", "STR_DUWS_T_617kjc41"] call _sec,
    ["STR_DUWS_T_MAN_L_REPUTATION",   "STR_DUWS_T_m204wqqq"] call _sec
] joinString "<br/><br/>")
// The support catalogue closes the page under its own banner - the one strip that
// leads a list rather than a topic. The Supports blurb heads it, a rule splits that
// off, then the PERM/CONS list (its own text carries the split and the colours).
+ "<br/><br/>" + ("duws_t_man_supports_list.jpg" call _bnr)
+ (localize "STR_DUWS_T_3c1ygiga") + "<br/>---<br/><br/>"
+ (localize "STR_DUWS_T_supportguide1");

private _economyBody = ("duws_t_man_economy.jpg" call _bnr) + ([
    ["STR_DUWS_T_uzx258em", "STR_DUWS_T_r3x8czon"] call _sec,      // Command Points
    ["STR_DUWS_T_x4vt0je3", "STR_DUWS_T_xs3zn5m2"] call _sec,      // Army Power
    ["STR_DUWS_T_HELP_ECO", "STR_DUWS_T_HELP_ECO_HINT"] call _sec  // Economy
] joinString "<br/><br/>");

private _opcomBody = ("duws_t_man_opcom.jpg" call _bnr) + (localize "STR_DUWS_T_MAN_OPCOM_BODY");

private _civBody = ("duws_t_man_civilian.jpg" call _bnr) + (localize "STR_DUWS_T_MAN_CIV_BODY");

private _configBody = ("duws_t_man_config.jpg" call _bnr) + ([
    ["STR_DUWS_T_timemanagement", "STR_DUWS_T_timemanagement2"] call _sec,
    ["STR_DUWS_T_ojav7yf4",       "STR_DUWS_T_d38s8oac"] call _sec,          // Hardcore Mode
    ["STR_DUWS_T_deathpenalty",   "STR_DUWS_T_deathpenalty2"] call _sec,
    "<t size='1.15' color='#4da6ff'>" + (localize "STR_DUWS_T_subtitlesystem") + "</t><br/>"
        + ([localize "STR_DUWS_T_subtitlesystem2"] call fnc_cs),             // Subtitles (needs fnc_cs)
    ["STR_DUWS_T_ty006zz4",       "STR_DUWS_T_8o0fomss"] call _sec,          // Saving
    ["STR_DUWS_T_ljw9ndqz",       "STR_DUWS_T_nk0wa9zo"] call _sec,          // Multiplayer
    ["STR_DUWS_T_MAN_L_OTHERMAPS", "STR_DUWS_T_MAN_B_OTHERMAPS"] call _sec   // Playing on Other Maps
] joinString "<br/><br/>");

// Other Game Modes: Guerilla and WBK fold in here once fleshed out - no per-mode
// subheaders yet, just the page and its banner.
private _modesBody = ("duws_t_man_other_modes.jpg" call _bnr) + (localize "STR_DUWS_T_MAN_MODES_BODY");

private _aboutBody = ("duws_t_man_about.jpg" call _bnr) + ([
    ["STR_DUWS_T_0f4f5uo2", "STR_DUWS_T_q4wns5y7"] call _sec,      // About DUWS-T
    ["STR_DUWS_T_7vfkrl61", "STR_DUWS_T_zho04a1k"] call _sec,      // Credits
    ["STR_DUWS_T_getwuiuy", "STR_DUWS_T_6ku0lc19"] call _sec       // Feedback / bug report
] joinString "<br/><br/>");

// Records in display order, top first.
private _records = [
    [localize "STR_DUWS_T_3feql12c",        _coverBody],
    [localize "STR_DUWS_T_MAN_HOWTO",       _howToBody],
    [localize "STR_DUWS_T_MAN_ECONOMY",     _economyBody],
    [localize "STR_DUWS_T_MAN_OPCOM",       _opcomBody],
    [localize "STR_DUWS_T_MAN_CIV",         _civBody],
    [localize "STR_DUWS_T_MAN_CONFIG",      _configBody],
    [localize "STR_DUWS_T_MAN_MODES",       _modesBody],
    [localize "STR_DUWS_T_MAN_L_ABOUTCRED", _aboutBody]
];

player createDiarySubject ["duws_manual", localize "STR_DUWS_T_3feql12c"];
reverse _records;
{ player createDiaryRecord ["duws_manual", _x] } forEach _records;
