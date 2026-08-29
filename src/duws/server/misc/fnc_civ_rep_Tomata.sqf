// Locality: server -- inherited from server/misc/fnc_civ_handler.sqf.
// Event handlers can run outside a suspendable context; re-spawn onto one before sleeping.
if (!canSuspend) exitWith {
    _this spawn fnc_civ_rep_Tomata;
};

_unit   = _this select 0;
_killer = _this select 1;
_instigator = _this select 2;

if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {};

// Presence is the whole gate: no random roll in front of it, since a player shooting civilians
// deliberately and seeing nothing happen most of the time reads as a broken system, not leniency.
// Same 200 m the building charge uses: both mean one thing by "player involved".
if !([getPos _unit] call fnc_civ_playerNear) exitWith {};

// The writer announces the change and owns the clamp, so nothing is
// printed here: the caller cannot know what will actually be applied.
if (side _killer == WEST || side _instigator == WEST) then {
    [_unit getVariable ["civ_locIndex", -1], -1, "civilian_harmed"] call fnc_town_rep_adjust;
};