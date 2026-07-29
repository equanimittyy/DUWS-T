// Locality: server. Ends a civilian as a contact: a refusal, a declined bribe, and one the
// player cannot pay all land here.
//
// Closing costs the player a person, which is what stops the reaction curve being decorative. A
// roll that consumed nothing would let a player at -20 work down a fifty-strong town until one
// civilian said yes -- the same failure the heal action had before fnc_civ_healed replaced it.
if (!isServer) exitWith {};

params ["_civilian", "_caller", ["_row", ""]];

if (isNull _civilian) exitWith {};

// Broadcast: the menu greys its conversational rows from this, and the dialog is built on the
// client that opens it.
_civilian setVariable ["DUWS_civ_closed", true, true];

// Closed against every row, not just the one that was asked. The refusal is the person deciding
// they are done talking, so a second row would be the same answer with extra steps.
// The line is per row only for flavour -- all four mean the same thing.
private _line = switch (toUpper _row) do {
    case "RECRUIT": { "STR_DUWS_T_RECRUIT_FAIL_REP" };
    case "AID": { "STR_DUWS_T_ASK_AID_REFUSE" };
    case "TOOLKIT": { "STR_DUWS_T_ASK_TOOLKIT_REFUSE" };
    default { "STR_DUWS_T_stfu" };
};

if (!isNull _caller) then {
    [localize "STR_DUWS_T_civ", localize _line] remoteExec ["fnc_duws_dialogue", _caller];
};

// Back to whatever they were doing before being called over. The scroll entry going away is what
// tells the player this person is finished with them -- it used to be a walk-off as well, which
// also emptied a hostile town on sight, but it moved every local the player so much as spoke to.
[_civilian] call fnc_civ_resume;
