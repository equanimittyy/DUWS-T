// Locality: all machines; both actions it adds run on the machine that triggers them, not here.
/*
    Adds a civilian's two scroll actions in one broadcast.

    Kept as a single remoteExec so the unit itself can serve as the JIP id: the engine drops a
    queued message when the object it is keyed to is deleted, where an auto-generated id (the
    `true` flag) outlives the civilian and leaves one entry per unit in the queue forever. Two
    messages cannot share one id without the second replacing the first, so the pair has to
    travel together.
*/
params ["_unit"];
if (isNull _unit) exitWith {};

[_unit] call fnc_civ_menuAction;
[_unit] call fnc_civ_stopCommand;
