for "_timer" from 10 to 1 step -1 do {
    hint format[localize "STR_DUWS_T_1bntq9ke",_timer];
    sleep 1;
};

private _selectedGroup = hcSelected player;
if (count _selectedGroup<1) exitWith {hint localize "STR_DUWS_T_57syrjor"};
if (count _selectedGroup>1) exitWith {hint localize "STR_DUWS_T_dzkot1hm"};

private _group = _selectedGroup select 0;
if ((units _group) findIf { isPlayer _x } >= 0) exitWith {hint localize "STR_DUWS_T_TASKFORCE_HAS_PLAYER"};
player hcRemoveGroup _group;
hintSilent "";
[_group] remoteExec ["fnc_taskforce_create", 2];
