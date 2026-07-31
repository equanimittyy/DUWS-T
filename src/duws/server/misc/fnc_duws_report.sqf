// Locality: server. Fans out through remoteExec itself, so it must not be reached from code that
// has already fanned out -- N machines would each report to N machines.
//
// One result on both surfaces at once. The dialogue queue holds a line behind whatever traffic is
// already in it, so a result the player held an action for can arrive late or scroll past unread;
// the hint carries it immediately while the spoken line keeps the voice.
//
// For results only, not for conversation. A civilian's half of a bribe is a line rather than a
// finding, and hinting every exchange would bury the ones that actually report something -- those
// sites stay on fnc_duws_dialogue directly.
//
// The hint is conditional because an audience of 0 is everyone, and a hint carries no speaker: a
// broadcast one reads as the mission addressing a player who did nothing. Spoken-only is the right
// shape there, and a caller that needs the whole team told reaches for a notification instead.
if (!isServer) exitWith {};

params ["_speaker", "_line", ["_audience", 0]];

[_speaker, _line] remoteExec ["fnc_duws_dialogue", _audience];
if (_audience isEqualType objNull) then { [_line] remoteExec ["hint", _audience] };
