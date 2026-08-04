// Locality: client; the event-handler bodies below run on the machine that triggers them, not here (inherited from client/dialog/fnc_startup_faction_flow.sqf).

["INFO", "FACTION", format ["HQ Faction Dialog Init: %1", profileName]] call fnc_log;

waituntil {!(IsNull (findDisplay 46))};
_display = (findDisplay 46) createDisplay "RscDisplayEmpty";

// One green box with everything tucked inside it, which is the shape every other setup screen
// carries (shared/includes/campaign_menu.hpp): a filled panel, a titled frame just inside it, and
// each answer in a labelled frame of its own. This screen used to be a full-bleed band split by two
// white rules, which read as controls dropped on the map rather than as the first screen of the
// setup sequence.
//
// One box, painted by two surfaces. The HQ placement buttons are a dialog of their own
// (shared/includes/hq_placement.hpp) because a control this display creates cannot be styled like a
// menu button, and this display draws over that dialog -- so the panel below stops just short of
// the strip the dialog paints, and the two greens meet edge to edge rather than overlapping. The
// frame spans both and draws over the join, being transparent inside.
//
// Created before anything that sits on it: ctrlCreate order is draw order, so a panel made later
// covers its own contents.
_backdrop = _display ctrlCreate ["RscText", 1007];
_backdrop ctrlSetPosition [0.075, 0.032, 0.85, 0.476];
_backdrop ctrlSetBackgroundColor [0.2, 0.4, 0.2, 1];
_backdrop ctrlCommit 0;

_boxframe = _display ctrlCreate ["RscFrame", 1008];
_boxframe ctrlSetPosition [0.0875, 0.052, 0.825, 0.684];
_boxframe ctrlSetText localize "STR_DUWS_T_faction_screen_title";
_boxframe ctrlCommit 0;

// Standing advice rather than a caption, and structured text rather than plain: at 95 characters
// it is wider than the box and a plain control cuts the tail off instead of wrapping. The height
// holds two lines at this size; raising the size without raising it too clips the second line.
_HQtext = _display ctrlCreate ["RscStructuredText", 1234];
_HQtext ctrlSetPosition [0.1, 0.088, 0.8, 0.076];
_HQtext ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t>", localize "STR_DUWS_T_hlr39me1"];
_HQtext ctrlCommit 0;

// The last of the three questions, so the two sit under the mode row. One row: same width, same
// baseline, split down the middle, each in the frame that names its side.
_frameBLU = _display ctrlCreate ["RscFrame", 1010];
_frameBLU ctrlSetPosition [0.1, 0.322, 0.3925, 0.1];
_frameBLU ctrlSetText localize "STR_DUWS_T_rqdziaei";
_frameBLU ctrlCommit 0;

_dropdownBLU = _display ctrlCreate ["RscCombo", 1001];
_dropdownBLU ctrlSetPosition [0.1125, 0.362, 0.3675, 0.04];
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
	BLUFOR_FactionFile_X = (_control lbData (lbCurSel _control));
}];

//////////////////////////////////////

_frameOPF = _display ctrlCreate ["RscFrame", 1011];
_frameOPF ctrlSetPosition [0.5075, 0.322, 0.3925, 0.1];
_frameOPF ctrlSetText localize "STR_DUWS_T_1m1bl9nd";
_frameOPF ctrlCommit 0;

_dropdownOPF = _display ctrlCreate ["RscCombo", 1003];
_dropdownOPF ctrlSetPosition [0.52, 0.362, 0.3675, 0.04];
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
		OPFOR_FactionFile_X = (_rows select 0) select 2;
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
	OPFOR_FactionFile_X = (_control lbData (lbCurSel _control));
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

// The frame carries the caption, so there is no separate label control. Its own box above the
// faction row keeps the order of the screen readable: the mode is answered first and narrows what
// the factions may be.
_frameMode = _display ctrlCreate ["RscFrame", 1005];
_frameMode ctrlSetPosition [0.1, 0.17, 0.8, 0.14];
_frameMode ctrlSetText localize "STR_DUWS_T_gamemode";
_frameMode ctrlCommit 0;

_dropdownMode = _display ctrlCreate ["RscCombo", 1004];
_dropdownMode ctrlSetPosition [0.1125, 0.206, 0.775, 0.04];
_dropdownMode ctrlCommit 0;

// Structured for the reason the advice line is: the longest mode description is 145 characters and
// wants two lines of the box rather than one line with its end cut off.
_modeDesc = _display ctrlCreate ["RscStructuredText", 1006];
_modeDesc ctrlSetPosition [0.1125, 0.254, 0.775, 0.052];
_modeDesc ctrlCommit 0;

// The last question, and the one that ends the screen. Under a rule and a plain caption rather than
// in a frame: three frames answering three questions and a fourth around the way out read as a
// fourth question. The buttons themselves are the dialog's, below. Cleared before it opens, because
// a click is live the moment they exist.
random_placement = false;

_rule = _display ctrlCreate ["RscText", 1009];
_rule ctrlSetPosition [0.1, 0.432, 0.8, 0.0025];
_rule ctrlSetBackgroundColor [1, 1, 1, 0.25];
_rule ctrlCommit 0;

// Structured for its centring rather than its wrapping: RscText draws left and SQF has no
// ctrlSetStyle, so a plain control cannot be centred after the fact. The alignment is in the markup
// and not left to the class, for the reason the pin below states.
_placeText = _display ctrlCreate ["RscStructuredText", 1012];
_placeText ctrlSetPosition [0.1, 0.470, 0.8, 0.034];
_placeText ctrlSetStructuredText parseText format ["<t align='center' size='0.8'>%1</t>",
	localize "STR_DUWS_T_7tr969mm"];
_placeText ctrlCommit 0;

// ctrlCreate resolves a class name against the display's own config before the mission's, and this
// display is RscDisplayEmpty -- a configFile display, so every control above is the engine's base
// class rather than shared/includes/defines.hpp's. Only what a setter exists for can be restated,
// which is why the two placement buttons are declared in a dialog instead: a button's hover, focus,
// shadow, border, press offsets and click sounds all come off the class and none of them have one.
{
	_x ctrlSetFont "PuristaMedium";
	_x ctrlSetFontHeight 0.03;
	_x ctrlCommit 0;
} forEach [_boxframe, _frameMode, _frameBLU, _frameOPF];

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
	(_display displayCtrl 1006) ctrlSetStructuredText parseText format ["<t size='0.66' color='#c0c0c0'>%1</t>",
		localize ((duws_gamemodes select _selectedIndex) select 2)];
	[_display displayCtrl 1003] call duws_fill_opfor_combo;
}];

// Restores the pick when the environment screen's Back button re-enters this screen, and paints
// the description line for the first time -- lbSetCurSel raises the handler above either way.
_modeSel = duws_gamemodes findIf {(_x select 0) == duws_gamemode};
_dropdownMode lbSetCurSel (0 max _modeSel);

// The placement buttons, and the cursor that makes this whole screen clickable.
createDialog "startup_hq_placement_dialog";
waitUntil {dialog};

waitUntil {random_placement || player_is_choosing_hqpos};

_display closeDisplay 1;
closeDialog 0;

if (player_is_choosing_hqpos) then {
	titleCut ["", "BLACK IN", 5];  // so you can see the map
	waitUntil {chosen_hq_placement};
};

publicVariable "BLUFOR_FactionFile_X";
publicVariable "OPFOR_FactionFile_X";
publicVariable "duws_gamemode";
//publicVariable "hardcore_visibleZone_found";
//publicVariable "hardcore_mode_enable";




