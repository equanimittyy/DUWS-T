// Speaker -> surface, for fnc_duws_dialogue. NET is the explicit list and VOICE the
// default, so a callsign added later without a table entry lands on the loud surface where
// it is visible in the first minute of play, rather than disappearing into a chat box
// nobody is watching.
// Kept pure and out of the router because the router touches localize, chat and UI, none
// of which exist in the headless test VM -- this is the one part the lint cannot check.
params [["_speaker", ""], ["_netSpeakers", []]];
// fnc_fob_server builds its speaker with format and interpolates a position array.
// That is pre-existing; it must not reach `in` against a table of strings.
if !(_speaker isEqualType "") exitWith {"VOICE"};
if (_speaker in _netSpeakers) exitWith {"NET"};
"VOICE"
