// The map-click capture lock and its background handler.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// A listener with no mode behind it, live whenever no mode holds the slot. The player-marker
// system needs the clicked position permanently, and before this it lost the slot to the first
// support call of the mission and never got it back.
fnc_mapclick_background = {
	params [["_handler", ""]];
	uiNamespace setVariable ["DUWS_mapclick_bg", _handler];
	if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isEqualTo "") then {
		onMapSingleClick _handler;
	};
};

// Takes the slot for a named mode, refusing if a different one already holds it -- which is the
// point: a collision becomes a message the player reads instead of a feature that dies quietly.
// Re-claiming as the current holder succeeds, because multi-stage modes (the helicopter taxi
// takes three points) swap handlers between stages.
// An optional third element is passed to the binary form of the command, which sets _this in
// the handler. Not defaulted to []: the unary form leaves the click itself in _this, and every
// site that reads its position out of `params ["_pos"]` would break if that were blanked.
fnc_mapclick_claim = {
	params [["_owner", ""], ["_handler", ""]];
	private _held = uiNamespace getVariable ["DUWS_mapclick_owner", ""];
	if (_held isNotEqualTo "" && {_held isNotEqualTo _owner}) exitWith {
		// The comm menu opens over the map, so a support called while another mode holds the
		// slot has to be refused on whichever surface is in front of the player: the hint box
		// renders behind the map.
		// if/then rather than a nested exitWith, which would exit this block and make the
		// refusal's return value depend on which branch ran.
		private _msg = localize "STR_DUWS_T_mapclick_busy";
		if (visibleMap) then {
			// Appended to the holder's banner rather than replacing it. The holder's instruction
			// is still live and the player still has to act on it, so overwriting it would trade
			// a silent theft for a lost prompt. Restored once the notice has been read.
			private _prev = missionNamespace getVariable ["DUWS_map_prompt_shown", ""];
			private _combined = _msg;
			if (_prev isNotEqualTo "") then {
				_combined = format ["%1<br/><t color='#ff6666'>%2</t>", _prev, _msg];
			};
			[_combined] call fnc_map_prompt;
			[_prev, _held, _combined] spawn {
				params ["_prev", "_holder", "_combined"];
				sleep 4;
				// Both guards matter: the holder may have finished (restoring would resurrect a
				// dead instruction) or redrawn its banner (restoring would undo the newer text).
				if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isEqualTo _holder
					&& {(missionNamespace getVariable ["DUWS_map_prompt_shown", ""]) isEqualTo _combined}) then {
					[_prev] call fnc_map_prompt;
				};
			};
		} else {
			hint _msg;
		};
		false
	};
	uiNamespace setVariable ["DUWS_mapclick_owner", _owner];
	if (count _this > 2) then { (_this select 2) onMapSingleClick _handler } else { onMapSingleClick _handler };
	true
};

// Hands the slot back to the background listener. A release from anyone but the holder is a
// no-op: several modes clear themselves from inside their own handler and again on the way out,
// and that second clear must not disarm whoever claimed in between.
fnc_mapclick_release = {
	params [["_owner", ""]];
	if ((uiNamespace getVariable ["DUWS_mapclick_owner", ""]) isNotEqualTo _owner) exitWith { false };
	uiNamespace setVariable ["DUWS_mapclick_owner", ""];
	onMapSingleClick (uiNamespace getVariable ["DUWS_mapclick_bg", ""]);
	// The banner shares the slot's lifetime: a mode that no longer owns the click must not be
	// left telling the player to click. Multi-stage modes redraw after each re-claim. No-op once
	// the map has closed, since the control lives on that display.
	[""] call fnc_map_prompt;
	true
};
