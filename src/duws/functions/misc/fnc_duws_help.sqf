// fnc_duws_help.sqf
// 原帮助系统保持不变，新增模式专属帮助

// 原帮助条目（保持不变）
_index = player createDiarySubject ["help", localize "STR_DUWS_T_3feql12c"]; 
player createDiaryRecord ["help", [localize "STR_DUWS_T_getwuiuy", localize "STR_DUWS_T_6ku0lc19"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_7vfkrl61", localize "STR_DUWS_T_zho04a1k"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_zimuxitong", localize "STR_DUWS_T_zimuxitong2"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_auhmznp6", localize "STR_DUWS_T_m267zqr7"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_ty006zz4", localize "STR_DUWS_T_8o0fomss"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_ojav7yf4", localize "STR_DUWS_T_d38s8oac"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_ulm497s5", localize "STR_DUWS_T_16wnqdrz"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_4yxb8s2k", localize "STR_DUWS_T_4elv35h6"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_siwang", localize "STR_DUWS_T_siwang2"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_ryhnop2g", localize "STR_DUWS_T_617kjc41"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_zhiyuan", localize "STR_DUWS_T_zhiyuan1"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_o31d875x", localize "STR_DUWS_T_3c1ygiga"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_g4orlwp1", localize "STR_DUWS_T_t6bei9tk"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_shijianguanli", localize "STR_DUWS_T_shijianguanli2"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_arsenal", localize "STR_DUWS_T_arsenal1"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_n4yjyv9x", localize "STR_DUWS_T_m204wqqq"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_x4vt0je3", localize "STR_DUWS_T_xs3zn5m2"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_uzx258em", localize "STR_DUWS_T_r3x8czon"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_0f4f5uo2", localize "STR_DUWS_T_q4wns5y7"]];
player createDiaryRecord ["help", [localize "STR_DUWS_T_ljw9ndqz", localize "STR_DUWS_T_nk0wa9zo"]];

// ========== 模式专属帮助信息 ==========
if (CIV_PRESENCE == "RAVAGE") then {
    // 添加丧尸模式专属主题和记录
    _index_ravage = player createDiarySubject ["ravage_help", localize "STR_DUWS_T_RAVAGE_HELP_TITLE"];
    player createDiaryRecord ["ravage_help", [localize "STR_DUWS_T_RAVAGE_HELP_SUB", localize "STR_DUWS_T_RAVAGE_HELP_DESC"]];
};

if (CIV_PRESENCE == "WBK") then {
    // 添加 WBK 模式专属主题和记录
    _index_wbk = player createDiarySubject ["wbk_help", localize "STR_DUWS_T_WBK_HELP_TITLE"];
    player createDiaryRecord ["wbk_help", [localize "STR_DUWS_T_WBK_HELP_SUB", localize "STR_DUWS_T_WBK_HELP_DESC"]];
};
