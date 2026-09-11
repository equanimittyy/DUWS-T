// Locality: server. The accepted tip. One of two helps, chosen at random while both are available:
//   - rule out a decoy: cross one still-live decoy's map marker off, narrowing the field.
//   - a vague bearing: an 8-point compass from the asking player toward the real safehouse, no distance,
//     so walking and re-asking cross-references but the bearing alone never hands over the house.
// Ruling-out has no floor: a patient crowd can cross off every decoy and leave the real house standing alone.
if (!isServer) exitWith {};
params ["_civilian", "_caller"];
if (isNull _caller) exitWith {};

private _real = missionNamespace getVariable ["DUWS_safehouse_real", objNull];
if (isNull _real) exitWith {};
private _decoys = (missionNamespace getVariable ["DUWS_safehouse_decoys", []]) select { !isNull _x };
private _uncleared = _decoys select { !(_x getVariable ["DUWS_safehouse_cleared", false]) };

private _canCross = !(_uncleared isEqualTo []);

// Both help types are a successful ask, so the local always acknowledges out loud; the specific help
// lands in the hint box. A ruled-out house flips its own map marker from "?" to a crossed-off glyph -- no line of its own.
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RAID_SAFEHOUSE_ASK_HIT"] remoteExec ["fnc_duws_dialogue", _caller];

if (_canCross && {random 1 < 0.7}) exitWith {
    private _d = selectRandom _uncleared;
    _d setVariable ["DUWS_safehouse_cleared", true, true];
    private _mk = _d getVariable ["DUWS_safehouse_marker", ""];
    if !(_mk isEqualTo "") then { _mk setMarkerType "Contact_pencilTask1" };
    [localize "STR_DUWS_T_RAID_SAFEHOUSE_ASK_RULEDOUT"] remoteExec ["hint", _caller];
};

private _dir = _caller getDir _real;
private _pts = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
private _compass = _pts select (floor (((_dir + 22.5) mod 360) / 45));
[format [localize "STR_DUWS_T_RAID_SAFEHOUSE_ASK_BEARING", _compass]] remoteExec ["hint", _caller];
