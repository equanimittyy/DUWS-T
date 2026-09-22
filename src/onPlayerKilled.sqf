
// The body search action goes with the body. An addAction is not removed by its owner dying, and
// the engine keeps evaluating the conditions of actions on any object near a player, so a corpse
// left carrying this one polls a seven-clause condition for the rest of the campaign -- once per
// death, forever. onPlayerRespawn adds a fresh one to the new body.
private _searchId = player getVariable ["DUWS_intel_search_actionId", -1];
if (_searchId >= 0) then { [player, _searchId] call BIS_fnc_holdActionRemove };

player setVariable["Saved_Face", face player];
player setVariable["Saved_Speaker", speaker player];
