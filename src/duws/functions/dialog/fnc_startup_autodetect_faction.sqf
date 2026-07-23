// Runs the interactive AutoDetect faction picker(s) during setup, so the popup
// appears while the player is still on the setup screens rather than after START.
// It only captures the choice into selectedFaction_BLU / selectedFaction_OPF; the
// heavy per-side data-gen (fnc_factionGen) stays deferred to the final commit,
// where the server runs it gated on createzone_server. Broadcasting the picks lets
// that deferred server-side gen read them without reopening a dialog.
//
// Called from fnc_startup_faction_flow, so the environment screen's Back button
// re-enters here and the player can re-pick. Reads the live dropdown values, which
// stay "AUTODETECT" until the deferred faction init remaps them at commit.
//
// One dialog is reused across the BLUFOR then OPFOR rounds (fnc_factionSelector's
// keep-open mechanism): the last round to show is the "final" one that closes it,
// so a lone BLUFOR or OPFOR pick still tears the dialog down. AUTODETECT_RANDOM
// self-picks, so it needs no prompt.

private _needBLU = (BLUFOR_Faction_X == "AUTODETECT");
private _needOPF = (OPFOR_Faction_X == "AUTODETECT");

if (_needBLU) then {
    ["Select Blufor Faction", !_needOPF] call fnc_factionSelector;
    selectedFaction_BLU = selectedFaction;
    publicVariable "selectedFaction_BLU";
};

if (_needOPF) then {
    ["Select Opfor Faction", true] call fnc_factionSelector;
    selectedFaction_OPF = selectedFaction;
    publicVariable "selectedFaction_OPF";
};
