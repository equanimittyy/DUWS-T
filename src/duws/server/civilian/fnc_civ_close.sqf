// Locality: server. The refused path: a refusal, a declined bribe, and one the player cannot pay
// all land here. The civilian was already spent by fnc_civ_request when the row was picked.
//
// Refusing costs the player a person, which is what stops the reaction curve being decorative. A
// roll that consumed nothing would let a player at -20 work down a fifty-strong town until one
// civilian said yes -- the same failure the heal action had before fnc_civ_healed replaced it.
if (!isServer) exitWith {};

// _speak false for a caller that has already spoken. A declined bribe answers itself, and the
// refusal line on top of it had the civilian say they knew nothing straight after naming a price
// for what they knew.
params ["_civilian", "_caller", ["_row", ""], ["_speak", true]];

if (isNull _civilian) exitWith {};

// Closed against every row, not just the one that was asked. The refusal is the person deciding
// they are done talking, so a second row would be the same answer with extra steps.
// The line is per row only for flavour -- all five mean the same thing.
private _line = switch (toUpper _row) do {
    case "RECRUIT": { "STR_DUWS_T_RECRUIT_FAIL_REP" };
    case "AID": { "STR_DUWS_T_ASK_AID_REFUSE" };
    case "TOOLKIT": { "STR_DUWS_T_ASK_TOOLKIT_REFUSE" };
    case "INFORMANT": { "STR_DUWS_T_INTEL_INFORMANT_ASK_MISS" };
    default { "STR_DUWS_T_stfu" };
};

if (_speak && {!isNull _caller}) then {
    [localize "STR_DUWS_T_civ", localize _line] remoteExec ["fnc_duws_dialogue", _caller];
};

// Back to whatever they were doing before being called over. The scroll entry going away is what
// tells the player this person is finished with them -- not a walk-off, which would move every
// local the player so much as spoke to and empty a hostile town on sight.
[_civilian] call fnc_civ_resume;
