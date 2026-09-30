// Locality: client -- wired to onLBSelChanged in shared/includes/operative_menu.hpp, which
// spells it fnc_LBselected, and run again on each roster broadcast while the menu is open.
_selected_index = lbCurSel 1500;

_selected_soldier = duws_operator_list select _selected_index;

// Skill values are stored 0-1; scale by 100 for the percent display.
_selected_soldier_aim = (_selected_soldier select 0)*100;
_selected_soldier_reflexes = (_selected_soldier select 1)*100;
_selected_soldier_spotting = (_selected_soldier select 2)*100;
_selected_soldier_courage = (_selected_soldier select 3)*100;
_selected_soldier_comms = (_selected_soldier select 4)*100;
_selected_soldier_reload = (_selected_soldier select 5)*100;
_selected_soldier_spendable_pts = (_selected_soldier select 13);


_selected_soldier_timeheal = _selected_soldier select 12;


_selected_soldier_role = _selected_soldier select 6;
_selected_soldier_status = _selected_soldier select 7;

 ctrlSetText [1006, format["%1",_selected_soldier_aim]];
 ctrlSetText [1007, format["%1",_selected_soldier_reflexes]];
 ctrlSetText [1008, format["%1",_selected_soldier_spotting]];
 ctrlSetText [1009, format["%1",_selected_soldier_courage]];
 ctrlSetText [1010, format["%1",_selected_soldier_comms]];
 ctrlSetText [1011, format["%1",_selected_soldier_reload]];
 
 ctrlSetText [1017, format["%1",_selected_soldier_spendable_pts]];

 ctrlSetText [1014, format["%1",_selected_soldier_role]];
 ctrlSetText [1013, format["%1",_selected_soldier_status]];
 ctrlSetText [1016, format["%1 seconds",_selected_soldier_timeheal]];
 

private _colorOf = { [[1, 1, 1, 1], [1, 0, 0, 1], [0, 1, 0, 1]] select (1 + (["Injured", "Operating"] find _this)) };
{ lbSetColor [1500, _forEachIndex, (_x select 7) call _colorOf] } forEach duws_operator_list;

switch (_selected_soldier_status) do
{
  case "Ready": {
	buttonSetAction [1601, "[lbCurSel 1500, player] remoteExecCall ['DUWS_fnc_operatorClaim', 2]"];
	ctrlSetText [1601, "DEPLOY (8 CP)"];
  };
  
  case "Injured": {
	buttonSetAction [1601, "hint ""This operative must be fully healed before deploying."""]; 
	ctrlSetText [1601, "CANNOT DEPLOY"];	
  };
  
  case "Operating": {
	buttonSetAction [1601, "hint ""This operative is already deployed."""]; 
	ctrlSetText [1601, "ALREADY DEPLOYED"];	
  };
  
  case "Healed": {
	buttonSetAction [1601, "[lbCurSel 1500, player] remoteExecCall ['DUWS_fnc_operatorClaim', 2]"]; 
	ctrlSetText [1601, "REDEPLOY (0 CP)"];	
  };  
};
((uiNamespace getVariable ["duws_operative_display", displayNull]) displayCtrl 1013) ctrlSetTextColor (_selected_soldier_status call _colorOf);
