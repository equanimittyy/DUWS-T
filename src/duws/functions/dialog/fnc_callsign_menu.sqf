_handle = createDialog "startup_dialog3";
waitUntil {dialog};

// Prefill with the current callsign: the default on first entry, or whatever was
// typed on an earlier visit that was left via Back (fnc_callsign_back keeps it).
private _cs = if (isNil "duws_callsign") then {"Alpha 1-1"} else {duws_callsign};
ctrlSetText [1400, _cs];

// Hardcore hides the zones, so hand-placing them defeats the mode: force random by
// disabling START-M. Its greyed look is the button's colorBackgroundDisabled in
// callsign_menu.hpp -- a disabled RscButton paints that slot and ignores the enabled one.
if (!isNil "hardcore_mode_enable" && {hardcore_mode_enable}) then {
    ctrlEnable [1601, false];
};
