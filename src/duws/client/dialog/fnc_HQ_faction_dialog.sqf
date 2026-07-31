// Locality: client; the event-handler bodies below run on the machine that triggers them, not here (inherited from client/dialog/fnc_startup_faction_flow.sqf).

["INFO", "FACTION", format ["HQ Faction Dialog Init: %1", profileName]] call fnc_log;

waituntil {!(IsNull (findDisplay 46))};
_factionSelect = 0;
_display = (findDisplay 46) createDisplay "RscDisplayEmpty";
			
_HQtext = _display ctrlCreate ["RscText", 1234];
_HQtext ctrlSetPosition [0.2,-0.1,1,0.04];
_HQtext ctrlSetText localize "STR_DUWS_T_hlr39me1";
_HQtext ctrlCommit 0;

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

// Rebuilt whenever the game mode changes, which is why it is a block rather than a loop in place.
// The zombie mode fields zombies, and zombies exist only as detected factions -- a static faction
// file or a pasted one would put an army in the campaign that is supposed to have none -- so its
// OPFOR list is the two AutoDetect rows, both of which the picker and the roll narrow to zombies.
duws_fill_opfor_combo = {
	params ["_ctrl"];
	lbClear _ctrl;

	private _rows = Factions_Available_OPFOR_X;
	if (duws_gamemode isEqualTo "zombies") then {
		_rows = _rows select {(_x select 2) in ["AUTODETECT", "AUTODETECT_RANDOM"]};
		// The faction the untouched default names is no longer in the list, so the row the combo
		// opens on has to become the answer; otherwise only a click ever writes this.
		OPFOR_Faction_X = (_rows select 0) select 2;
	};

	{
		private _itemOPF = _ctrl lbAdd format ["%1", _x select 1];
		_ctrl lbSetData [_itemOPF, (_x select 2)];
		_ctrl lbSetColor [_itemOPF, [1,.2,.2,1]];
	} forEach _rows;

	_ctrl lbSetCurSel 0;
};

[_dropdownOPF] call duws_fill_opfor_combo;
_dropdownOPF ctrlAddEventHandler ["LBSelChanged",
{	
	params ["_control", "_selectedIndex"];
	OPFOR_Faction_X = (_control lbData (lbCurSel _control));
}];

//////////////////////////////////////

// Game mode. Sits above the faction dropdowns because it is answered first and the screens after
// it narrow to it -- the reverse is not available, this is the first screen of setup. Built after
// them because picking a mode refills the OPFOR list, so that control has to exist already.
// Each entry is [token, label key, description key]; the fill order is the order the handler
// indexes back into. What each mode still has to take over from the settings it replaces is in
// docs/game_modes_plan.md.
duws_gamemodes = [
	["duws", "STR_DUWS_T_gamemode_duws", "STR_DUWS_T_gamemode_duws_desc"],
	["guerilla", "STR_DUWS_T_gamemode_guerilla", "STR_DUWS_T_gamemode_guerilla_desc"],
	["zombies", "STR_DUWS_T_gamemode_zombies", "STR_DUWS_T_gamemode_zombies_desc"]
];
if (isNil "duws_gamemode") then { duws_gamemode = "duws"; };

// Does any loaded mod supply a zombie faction? Same enumeration the AutoDetect picker runs, done
// once here rather than per click, and read by the mode row below.
duws_zombie_factions_found = count ([true] call fnc_getAllFactionsClean) > 0;

_modeLabel = _display ctrlCreate ["RscText", 1005];
_modeLabel ctrlSetPosition [0.2, 0.02, 0.6, 0.04];
_modeLabel ctrlSetText localize "STR_DUWS_T_gamemode";
_modeLabel ctrlCommit 0;

_modeDesc = _display ctrlCreate ["RscText", 1006];
_modeDesc ctrlSetPosition [0.2, 0.105, 0.6, 0.04];
_modeDesc ctrlSetTextColor [1,1,1,0.75];
_modeDesc ctrlCommit 0;

_dropdownMode = _display ctrlCreate ["RscCombo", 1004];
_dropdownMode ctrlSetPosition [0.2, 0.06, 0.6, 0.04];
_dropdownMode ctrlCommit 0;

{
	_itemMode = _dropdownMode lbAdd localize (_x select 1);
	_dropdownMode lbSetData [_itemMode, (_x select 0)];
} forEach duws_gamemodes;

_dropdownMode ctrlAddEventHandler ["LBSelChanged",
{
	params ["_control", "_selectedIndex"];
	private _token = _control lbData _selectedIndex;
	private _display = ctrlParent _control;

	// With neither zombie mod loaded the mode has nothing to field: say which two it takes and
	// put the row back on DUWS, rather than start a campaign whose enemy pool is empty.
	if (_token isEqualTo "zombies" && {!duws_zombie_factions_found}) exitWith {
		hint localize "STR_DUWS_T_gamemode_zombies_missing";
		_control lbSetCurSel 0;
	};

	// The environment screen builds its civilian list per mode, so a snapshot taken under the old
	// mode no longer describes the list the player would come back to. Dropped the way a preset
	// drops it, leaving that screen to its own defaults.
	if !(_token isEqualTo duws_gamemode) then { duws_enviro_sel = nil; };

	duws_gamemode = _token;
	(_display displayCtrl 1006) ctrlSetText localize ((duws_gamemodes select _selectedIndex) select 2);
	[_display displayCtrl 1003] call duws_fill_opfor_combo;
}];

// Restores the pick when the environment screen's Back button re-enters this screen, and paints
// the description line for the first time -- lbSetCurSel raises the handler above either way.
_modeSel = duws_gamemodes findIf {(_x select 0) == duws_gamemode};
_dropdownMode lbSetCurSel (0 max _modeSel);

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

publicVariable "BLUFOR_Faction_X";
publicVariable "OPFOR_Faction_X";
publicVariable "duws_gamemode";
//publicVariable "hardcore_visibleZone_found";
//publicVariable "hardcore_mode_enable";




