// fnc_duws_help.sqf
// Builds the "DUWS_T Manual" section in the map's Notes (diary).

// Entries in display order, top first. The opaque STR_ IDs are stringtable
// hashes; the trailing label names each topic so this list stays editable
// without cross-referencing stringtable.xml. The Economy / Capturing Zones /
// About Arsenal entries were the old HQ quick-help topics, folded in here.
private _entries = [
    ["STR_DUWS_T_3feql12c",      "STR_DUWS_T_MANUAL_INDEX"],       // Manual index (shown first)
    ["STR_DUWS_T_0f4f5uo2",      "STR_DUWS_T_q4wns5y7"],           // About DUWS_T
    ["STR_DUWS_T_uzx258em",      "STR_DUWS_T_r3x8czon"],           // Command Points (CP)
    ["STR_DUWS_T_x4vt0je3",      "STR_DUWS_T_xs3zn5m2"],           // Army Power (AP)
    ["STR_DUWS_T_HELP_ECO",      "STR_DUWS_T_HELP_ECO_HINT"],      // Economy System
    ["STR_DUWS_T_HELP_ZONES",    "STR_DUWS_T_HELP_ZONES_HINT"],    // Capturing Zones
    ["STR_DUWS_T_o31d875x",      "STR_DUWS_T_3c1ygiga"],           // Supports
    ["STR_DUWS_T_zhiyuan",       "STR_DUWS_T_zhiyuan1"],           // Reworked Support Options (detail)
    ["STR_DUWS_T_arsenal",       "STR_DUWS_T_arsenal1"],           // Arsenal System
    ["STR_DUWS_T_HELP_SUPPORTS",  "STR_DUWS_T_HELP_SUPPORTS_HINT"], // About Arsenal (unlocking access)
    ["STR_DUWS_T_g4orlwp1",      "STR_DUWS_T_t6bei9tk"],           // Request Menu
    ["STR_DUWS_T_auhmznp6",      "STR_DUWS_T_m267zqr7"],           // Recruiting Operatives
    ["STR_DUWS_T_ryhnop2g",      "STR_DUWS_T_617kjc41"],           // Reworked Side Mission System
    ["STR_DUWS_T_4yxb8s2k",      "STR_DUWS_T_4elv35h6"],           // Establish a FOB
    ["STR_DUWS_T_ulm497s5",      "STR_DUWS_T_16wnqdrz"],           // Task Forces
    ["STR_DUWS_T_n4yjyv9x",      "STR_DUWS_T_m204wqqq"],           // Reworked Reputation System
    ["STR_DUWS_T_shijianguanli", "STR_DUWS_T_shijianguanli2"],     // Time Management System
    ["STR_DUWS_T_ojav7yf4",      "STR_DUWS_T_d38s8oac"],           // Hardcore Mode
    ["STR_DUWS_T_zimuxitong",    "STR_DUWS_T_zimuxitong2"],        // Subtitle System
    ["STR_DUWS_T_ty006zz4",      "STR_DUWS_T_8o0fomss"],           // Saving the game
    ["STR_DUWS_T_siwang",        "STR_DUWS_T_siwang2"],            // Death Penalty
    ["STR_DUWS_T_ljw9ndqz",      "STR_DUWS_T_nk0wa9zo"],           // MP notes
    ["STR_DUWS_T_7vfkrl61",      "STR_DUWS_T_zho04a1k"],           // Credits
    ["STR_DUWS_T_getwuiuy",      "STR_DUWS_T_6ku0lc19"]            // Feedback / bug report
];

player createDiarySubject ["help", localize "STR_DUWS_T_3feql12c"];

// Diary records display newest-first, so add them bottom-up: the first _entries
// row is created last and lands on top. Reordering the manual means reordering
// _entries, nothing else.
reverse _entries;
{
    _x params ["_title", "_body"];
    player createDiaryRecord ["help", [localize _title, localize _body]];
} forEach _entries;

// ========== Mode-specific help ==========
if (CIV_PRESENCE == "RAVAGE") then {
    player createDiarySubject ["ravage_help", localize "STR_DUWS_T_RAVAGE_HELP_TITLE"];
    player createDiaryRecord ["ravage_help", [localize "STR_DUWS_T_RAVAGE_HELP_SUB", localize "STR_DUWS_T_RAVAGE_HELP_DESC"]];
};

if (CIV_PRESENCE == "WBK") then {
    player createDiarySubject ["wbk_help", localize "STR_DUWS_T_WBK_HELP_TITLE"];
    player createDiaryRecord ["wbk_help", [localize "STR_DUWS_T_WBK_HELP_SUB", localize "STR_DUWS_T_WBK_HELP_DESC"]];
};
