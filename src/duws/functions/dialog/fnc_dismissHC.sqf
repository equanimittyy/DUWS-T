// Locality: client -- invoked from a dialog action (includes/squadmng.hpp:93).
for "_timer" from 10 to 1 step -1 do {
    hint format[localize "STR_DUWS_T_1bntq9ke",_timer];
    sleep 1;
};

_selectedGroup = hcSelected player;
if (count _selectedGroup<1) exitWith {hint localize "STR_DUWS_T_57syrjor"};
if (count _selectedGroup>1) exitWith {hint localize "STR_DUWS_T_dzkot1hm"};

_group = _selectedGroup select 0;

player hcRemoveGroup _group;   // 仅从高级指挥模块中移除

hint localize "STR_DUWS_T_gj4ue2bf";  // 提示操作成功