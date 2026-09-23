// Locality: client -- invoked from a dialog action (shared/includes/renamesquad.hpp:40).
_editbox_squad_name = "blank";
_editbox_squad_name = ctrlText 1400;
closeDialog 0;

for "_timer" from 10 to 1 step -1 do {
    hint format[localize "STR_DUWS_T_1bntq9ke",_timer];
    sleep 1;
};

_selectedGroup = hcSelected player;
if (count _selectedGroup<1) exitWith {hint localize "STR_DUWS_T_57syrjor"};
if (count _selectedGroup>1) exitWith {hint localize "STR_DUWS_T_dzkot1hm"};

_group = _selectedGroup select 0;
_group setGroupId [format["%1",_editbox_squad_name]];
hint format[localize "STR_DUWS_T_twmowx0v",_editbox_squad_name];