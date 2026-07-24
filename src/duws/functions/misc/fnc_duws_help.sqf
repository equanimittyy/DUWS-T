// fnc_duws_help.sqf
// Builds the "DUWS-T Manual" in the map's Notes (diary), split into a few focused
// subjects (tabs) so each page stays short instead of one long list of records.
//
// Two engine constraints shape this file (see docs/arma_engine_gotchas.md):
//  - The diary displays newest-first, so both the subject list and each subject's
//    records are reversed before creation (the first entry ends up on top).
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

// Creates the tab and its records; records reversed so the list reads top-down.
private _fnc_subject = {
    params ["_id", "_title", "_records"];
    player createDiarySubject [_id, _title];
    reverse _records;
    { player createDiaryRecord [_id, _x] } forEach _records;
};

// Civilian System: overview plus both special modes, always listed so players know
// the Ravage/WBK modes exist even when they are not the active civilian setting.
private _civRecords = [
    [localize "STR_DUWS_T_MAN_CIV", localize "STR_DUWS_T_MAN_CIV_BODY"],
    [localize "STR_DUWS_T_RAVAGE_HELP_TITLE", localize "STR_DUWS_T_RAVAGE_HELP_DESC"],
    [localize "STR_DUWS_T_WBK_HELP_TITLE", localize "STR_DUWS_T_WBK_HELP_DESC"]
];

// Subjects in display order, top first. The diary prepends both records and
// subjects, so reverse before creating (same reason the records are reversed above).
private _subjects = [
    ["duws_about", localize "STR_DUWS_T_0f4f5uo2", [
        [localize "STR_DUWS_T_0f4f5uo2", localize "STR_DUWS_T_q4wns5y7"]             // About DUWS-T
    ]],
    ["duws_howto", localize "STR_DUWS_T_MAN_HOWTO", [
        [localize "STR_DUWS_T_MAN_ECONOMY", _economyBody],
        [localize "STR_DUWS_T_HELP_ZONES", localize "STR_DUWS_T_HELP_ZONES_HINT"],   // Capturing Zones
        [localize "STR_DUWS_T_ryhnop2g", localize "STR_DUWS_T_617kjc41"],            // Side Missions
        [localize "STR_DUWS_T_n4yjyv9x", localize "STR_DUWS_T_m204wqqq"]             // Reputation
    ]],
    ["duws_forces", localize "STR_DUWS_T_MAN_FORCES", [
        [localize "STR_DUWS_T_MAN_REQFORCES", _reqForcesBody],
        [localize "STR_DUWS_T_4yxb8s2k", localize "STR_DUWS_T_4elv35h6"],            // Establish a FOB
        [localize "STR_DUWS_T_MAN_SUPPARS", _suppArsBody],
        [localize "STR_DUWS_T_zhiyuan", localize "STR_DUWS_T_zhiyuan1"]              // Support Options (detailed)
    ]],
    ["duws_civ", localize "STR_DUWS_T_MAN_CIV", _civRecords],
    ["duws_config", localize "STR_DUWS_T_MAN_CONFIG", [
        [localize "STR_DUWS_T_shijianguanli", localize "STR_DUWS_T_shijianguanli2"], // Time Management
        [localize "STR_DUWS_T_ojav7yf4", localize "STR_DUWS_T_d38s8oac"],            // Hardcore Mode
        [localize "STR_DUWS_T_siwang", localize "STR_DUWS_T_siwang2"],               // Death Penalty
        [localize "STR_DUWS_T_zimuxitong", localize "STR_DUWS_T_zimuxitong2"],       // Subtitles
        [localize "STR_DUWS_T_ty006zz4", localize "STR_DUWS_T_8o0fomss"],            // Saving
        [localize "STR_DUWS_T_ljw9ndqz", localize "STR_DUWS_T_nk0wa9zo"]             // Multiplayer notes
    ]],
    ["duws_credits", localize "STR_DUWS_T_MAN_CREDITS", [
        [localize "STR_DUWS_T_7vfkrl61", localize "STR_DUWS_T_zho04a1k"],            // Credits
        [localize "STR_DUWS_T_getwuiuy", localize "STR_DUWS_T_6ku0lc19"]             // Feedback / bug report
    ]]
];
reverse _subjects;
{ _x call _fnc_subject } forEach _subjects;
