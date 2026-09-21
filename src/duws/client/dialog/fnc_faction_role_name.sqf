// Locality: client -- called by the faction confirmation screen and its key editor.
//
// A schema key as those screens name it: the blufor_/opfor_ prefix and _X suffix dropped (the screen
// already says which side, and the suffix carries nothing), then the role's localised name in
// brackets. English omits the bracket, because the key is already English.

params ["_key"];

private _role = (_key regexReplace ["^(blufor|opfor)_", ""]) regexReplace ["_X$", ""];
if (language == "English") exitWith { _role };
format ["%1 (%2)", _role, localize format ["STR_DUWS_T_faction_role_%1", toLower _role]]
