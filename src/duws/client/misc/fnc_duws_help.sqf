// Locality: client -- inherited from client/client_init.sqf.
// Builds the single "DUWS-T Manual" subject in the map's Notes (diary) as one
// record (page) per top-level topic, each led by its heading banner. Sub-topics
// that don't warrant their own page fold into the owning page as inline
// sub-headers.
//
// Engine notes (docs/info/architecture/arma_engine_gotchas.md):
//  - The diary displays records newest-first, so the list is built top-down then
//    reversed before creation (the first row ends up on top).
//  - Record bodies are structured text, but colour comes from <font>, NOT <t>:
//    the diary ignores <t> (a parseText/ctrlSetStructuredText tag), so its
//    colour/size drop silently. <font color=...>, <br/> and <img .../> render;
//    <font size> is absolute px, not the <t> multiplier.
//  - Banner path uses format, not "...images\"+leaf: a backslash right before a
//    string's closing quote can be mis-read by the CfgFunctions preprocessor.

private _bnr = {
    format ["<img image='duws\shared\media\images\%1' width='350' height='40'/><br/><br/>", _this]
};
private _sec = {
    params ["_titleId", "_bodyId"];
    "<font color='#4da6ff'>" + (localize _titleId) + "</font><br/>" + (localize _bodyId)
};

// The supports list, generated from the catalogue (client/supports/fnc_supports_init.sqf) so a
// price change there is the only edit -- name, the shared cost bracket and a keyed description
// (STR_DUWS_T_sdesc_<key>) per row, permanent then squad. Reads the raw catalogue, not the menu's
// filtered view, so rows still locked at mission start are listed all the same.
private _supportRows = {
    params ["_kind", "_colour"];
    (([] call fnc_support_catalogue) select { (_x select 1) == _kind }) apply {
        _x params ["_key", "", "_cost", "", "_labelKey"];
        format ["<font color='%1'>%2</font>%3: %4",
            _colour, localize _labelKey,
            [_cost, _x param [7, 0]] call fnc_support_cost_bracket,
            localize (format ["STR_DUWS_T_sdesc_%1", _key])]
    } joinString "<br/><br/>"
};
// The catalogue and bracket functions are compiled on the server and broadcast; a JIP client can
// reach this init-time build before they arrive, so hold until both are defined.
waitUntil { !isNil "fnc_support_catalogue" && {!isNil "fnc_support_cost_bracket"} };
private _supportsList =
    "<font color='#4da6ff'>" + (localize "STR_DUWS_T_MAN_SUP_PERM") + "</font><br/>"
    + (["PERM", "#ff8000"] call _supportRows)
    + "<br/><br/>---<br/><br/><font color='#4da6ff'>" + (localize "STR_DUWS_T_MAN_SUP_CONS") + "</font><br/>"
    + (["CONS", "#4da6ff"] call _supportRows);

private _coverBody =
    "<img image='duws\shared\media\images\duws_t_man_cover.jpg' width='456' height='257'/><br/><br/>"
    + (localize "STR_DUWS_T_MAN_COVER_BODY");

private _howToBody = ("duws_t_man_how_to_play.jpg" call _bnr) + ([
    ["STR_DUWS_T_MAN_L_OBJECTIVE",    "STR_DUWS_T_MAN_B_OBJECTIVE"] call _sec,
    ["STR_DUWS_T_MAN_L_DEFEAT",       "STR_DUWS_T_MAN_B_DEFEAT"] call _sec,
    ["STR_DUWS_T_MAN_L_ZONES",        "STR_DUWS_T_HELP_ZONES_HINT"] call _sec,
    ["STR_DUWS_T_MAN_L_HOLDZONE",     "STR_DUWS_T_MAN_B_HOLDZONE"] call _sec,
    ["STR_DUWS_T_g4orlwp1",           "STR_DUWS_T_t6bei9tk"] call _sec,      // Request Menu
    ["STR_DUWS_T_auhmznp6",           "STR_DUWS_T_m267zqr7"] call _sec,      // Recruiting Operatives
    ["STR_DUWS_T_MAN_L_HC_SQUADS",    "STR_DUWS_T_MAN_B_HC_SQUADS"] call _sec,
    ["STR_DUWS_T_ulm497s5",           "STR_DUWS_T_16wnqdrz"] call _sec,      // Task Forces
    ["STR_DUWS_T_4yxb8s2k",           "STR_DUWS_T_4elv35h6"] call _sec,      // Establish a FOB
    ["STR_DUWS_T_MAN_L_FACTORIES",    "STR_DUWS_T_MAN_B_FACTORIES"] call _sec,
    ["STR_DUWS_T_arsenal",            "STR_DUWS_T_arsenal1"] call _sec,      // Arsenal System
    ["STR_DUWS_T_HELP_SUPPORTS",      "STR_DUWS_T_HELP_SUPPORTS_HINT"] call _sec, // Unlocking the Arsenal
    ["STR_DUWS_T_MAN_L_SIDEMISSIONS", "STR_DUWS_T_617kjc41"] call _sec,
    ["STR_DUWS_T_MAN_L_INTEL",        "STR_DUWS_T_MAN_B_INTEL"] call _sec,
    ["STR_DUWS_T_MAN_L_SEARCH",       "STR_DUWS_T_MAN_B_SEARCH"] call _sec,
    ["STR_DUWS_T_MAN_L_DISGUISE",     "STR_DUWS_T_MAN_B_DISGUISE"] call _sec
] joinString "<br/><br/>")
// The support catalogue closes the page under its own banner - the one strip that
// leads a list rather than a topic. The Supports blurb heads it, a rule splits that
// off, then the PERM/CONS list (its own text carries the split and the colours).
+ "<br/><br/>" + ("duws_t_man_supports_list.jpg" call _bnr)
+ (localize "STR_DUWS_T_3c1ygiga") + "<br/>---<br/><br/>"
+ _supportsList;

private _economyBody = ("duws_t_man_economy.jpg" call _bnr) + ([
    ["STR_DUWS_T_uzx258em", "STR_DUWS_T_r3x8czon"] call _sec,      // Command Points
    ["STR_DUWS_T_x4vt0je3", "STR_DUWS_T_xs3zn5m2"] call _sec,      // Army Power
    ["STR_DUWS_T_HELP_ECO", "STR_DUWS_T_HELP_ECO_HINT"] call _sec,
    ["STR_DUWS_T_MAN_L_VENDORS", "STR_DUWS_T_MAN_B_VENDORS"] call _sec
] joinString "<br/><br/>");

private _opcomBody = ("duws_t_man_opcom.jpg" call _bnr) + (localize "STR_DUWS_T_MAN_OPCOM_BODY") + "<br/><br/>" + ([
    ["STR_DUWS_T_MAN_L_TARGETING",     "STR_DUWS_T_MAN_B_TARGETING"] call _sec,
    ["STR_DUWS_T_MAN_L_BUDGET",        "STR_DUWS_T_MAN_B_BUDGET"] call _sec,
    ["STR_DUWS_T_MAN_L_GARRISONS",     "STR_DUWS_T_MAN_B_GARRISONS"] call _sec,
    ["STR_DUWS_T_MAN_L_COUNTERATTACK", "STR_DUWS_T_MAN_B_COUNTERATTACK"] call _sec,
    ["STR_DUWS_T_MAN_L_HARDPOINTS",    "STR_DUWS_T_MAN_B_HARDPOINTS"] call _sec,
    ["STR_DUWS_T_MAN_L_MINEFIELDS",    "STR_DUWS_T_MAN_B_MINEFIELDS"] call _sec,
    ["STR_DUWS_T_MAN_L_INFLUENCE",     "STR_DUWS_T_MAN_B_INFLUENCE"] call _sec,
    ["STR_DUWS_T_MAN_L_TIERS",         "STR_DUWS_T_MAN_B_TIERS"] call _sec
] joinString "<br/><br/>");

private _civBody = ("duws_t_man_civilian.jpg" call _bnr) + (localize "STR_DUWS_T_MAN_CIV_BODY") + "<br/><br/>" + ([
    ["STR_DUWS_T_MAN_L_CIVTALK",     "STR_DUWS_T_MAN_B_CIVTALK"] call _sec,
    ["STR_DUWS_T_MAN_L_REPUTATION",  "STR_DUWS_T_m204wqqq"] call _sec,
    ["STR_DUWS_T_MAN_L_CIVJOBS",     "STR_DUWS_T_MAN_B_CIVJOBS"] call _sec,
    ["STR_DUWS_T_MAN_L_HOSTILETOWN", "STR_DUWS_T_MAN_B_HOSTILETOWN"] call _sec
] joinString "<br/><br/>");

private _configBody = ("duws_t_man_config.jpg" call _bnr) + ([
    ["STR_DUWS_T_timemanagement", "STR_DUWS_T_timemanagement2"] call _sec,
    ["STR_DUWS_T_ojav7yf4",       "STR_DUWS_T_d38s8oac"] call _sec,          // Hardcore Mode
    ["STR_DUWS_T_deathpenalty",   "STR_DUWS_T_deathpenalty2"] call _sec,
    ["STR_DUWS_T_MAN_L_CAMPAIGNSETUP", "STR_DUWS_T_MAN_B_CAMPAIGNSETUP"] call _sec,
    "<font color='#4da6ff'>" + (localize "STR_DUWS_T_subtitlesystem") + "</font><br/>"
        + ([localize "STR_DUWS_T_subtitlesystem2"] call fnc_cs),             // Subtitles (needs fnc_cs)
    ["STR_DUWS_T_ty006zz4",       "STR_DUWS_T_8o0fomss"] call _sec,          // Saving
    ["STR_DUWS_T_ljw9ndqz",       "STR_DUWS_T_nk0wa9zo"] call _sec,          // Multiplayer
    ["STR_DUWS_T_MAN_L_OTHERMAPS", "STR_DUWS_T_MAN_B_OTHERMAPS"] call _sec
] joinString "<br/><br/>");

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
