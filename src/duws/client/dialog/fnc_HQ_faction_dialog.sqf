// Locality: client; the event-handler bodies below run on the machine that triggers them, not here (inherited from dialog/fnc_startup_faction_flow.sqf).

diag_log format ["HQ Faction Dialog Init: %1", profileName];

///////////////////////////////////////////
// Create the FACTION Dialog
///////////////////////////////////////////

waituntil {!(IsNull (findDisplay 46))};
_factionSelect = 0;
_display = (findDisplay 46) createDisplay "RscDisplayEmpty";
			
_HQtext = _display ctrlCreate ["RscText", 1234];
_HQtext ctrlSetPosition [0.2,-0.1,1,0.04];
_HQtext ctrlSetText localize "STR_DUWS_T_hlr39me1";
_HQtext ctrlCommit 0;
			
//_HQtext2 = _display ctrlCreate ["RscText", 1235];
//_HQtext2 ctrlSetPosition [0.45,.1,1,0.04];
//_HQtext2 ctrlSetText "Mission Type";
//_HQtext2 ctrlCommit 0;

_dropdownBLU = _display ctrlCreate ["RscCombo", 1001];
_dropdownBLU ctrlSetPosition [-0.25, .15, .5, 0.04];
_dropdownBLU ctrlCommit 0;

{
	_itemBLU = _dropdownBLU lbAdd format ["%1", _x select 1];
	_dropdownBLU lbSetData [_itemBLU, (_x select 2)];
	_dropdownBLU lbSetColor [_itemBLU, [.2,.5,1,1]];
} forEach Factions_Available_BLUFOR_X;

_dropdownBLU lbSetCurSel 0;
_dropdownBLU ctrlAddEventHandler ["LBSelChanged",
{
	params ["_control", "_selectedIndex"];
	BLUFOR_Faction_X = (_control lbData (lbCurSel _control));
}];

//////////////////////////////////////

_dropdownOPF = _display ctrlCreate ["RscCombo", 1003];
_dropdownOPF ctrlSetPosition [0.75, .15, .5, 0.04];
_dropdownOPF ctrlCommit 0;

{
	_itemOPF = _dropdownOPF lbAdd format ["%1", _x select 1];
	_dropdownOPF lbSetData [_itemOPF, (_x select 2)];
	_dropdownOPF lbSetColor [_itemOPF, [1,.2,.2,1]];
} forEach Factions_Available_OPFOR_X;

_dropdownOPF lbSetCurSel 0;
_dropdownOPF ctrlAddEventHandler ["LBSelChanged",
{	
	params ["_control", "_selectedIndex"];
	OPFOR_Faction_X = (_control lbData (lbCurSel _control));
}];
	
////////////////////////////////////////////////
//  Start the HQ DIALOG
////////////////////////////////////////////////

_handle = createDialog "startup_hq_placement_dialog";
waitUntil {dialog};

random_placement = false;

waitUntil {random_placement || player_is_choosing_hqpos};

_display closeDisplay 1;
closeDialog 0;

if (player_is_choosing_hqpos) then {
	titleCut ["", "BLACK IN", 5];  // so you can see the map
	waitUntil {chosen_hq_placement};
};
	
// debug
//player globalChat format ["hq_manually_placed: %1", hq_manually_placed];
//player globalChat format ["player_is_choosing_hqpos: %1", player_is_choosing_hqpos];

// Close the Faction dialog
//_display closeDisplay 1;
//closeDialog 0;
//titleCut ["", "BLACK IN", 5];
//waitUntil {chosen_hq_placement};

publicVariable "BLUFOR_Faction_X";
publicVariable "OPFOR_Faction_X";
//publicVariable "hardcore_visibleZone_found";
//publicVariable "hardcore_mode_enable";




