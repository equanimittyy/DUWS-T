// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp).
  createDialog "operativemaingui";
  waitUntil {dialog};
 
{ lbAdd [1500, _x select 8] } forEach duws_operator_list;
// Fires onLBSelChanged, whose handler paints each row by its status.
lbSetCurSel [1500, 0];



