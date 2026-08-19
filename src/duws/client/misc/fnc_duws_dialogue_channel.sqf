// Speaker -> surface, for fnc_duws_dialogue. NET and SUB-NET are explicit lists; VOICE is the
// default, so a callsign added without a table entry lands on the loud subtitle where it is
// visible in the first minute of play, rather than on SUB-NET's bottom-left chat box -- the
// low-prominence surface, reserved for radio traffic that must not bury an in-room line or a brief.
// Kept pure and out of the router because the router touches localize, chat and UI, none
// of which exist in the headless test VM -- this is the one part the lint cannot check.
params [["_speaker", ""], ["_netSpeakers", []], ["_subnetSpeakers", []]];
// fnc_fob_server builds its speaker with format and interpolates a position array.
// That is pre-existing; it must not reach `in` against a table of strings.
if !(_speaker isEqualType "") exitWith {"VOICE"};
if (_speaker in _netSpeakers) exitWith {"NET"};
if (_speaker in _subnetSpeakers) exitWith {"SUB-NET"};
"VOICE"
