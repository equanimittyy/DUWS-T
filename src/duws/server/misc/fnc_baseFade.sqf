// Locality: server. Blacks out the screens of players standing where a base is about to appear or
// disappear, so the pop-in reads as a cut rather than as a glitch. The same fade the rest mechanic
// uses on its own jump in time.
//
// Two calls, and the second must be handed the list the first returned:
//     private _faded = ["OUT", getPos _thing] call fnc_baseFade;   // returns who it faded
//     ...build or tear down...
//     ["IN", _faded] call fnc_baseFade;
//
// Handing back the list rather than re-scanning is the whole reason it returns one. Fading in
// whoever is nearby *now* would leave a player who walked out of the radius mid-build staring at a
// black screen for the rest of the campaign, and would fade in someone who only just arrived.
if (!isServer) exitWith {[]};

params ["_mode", ["_arg", []], ["_radius", 100]];

if (toUpper _mode isEqualTo "IN") exitWith {
	{ [["", "BLACK IN", 1.5]] remoteExec ["titleCut", _x] } forEach (_arg select {!isNull _x});
	[]
};

// Aimed only at players close enough to witness the change: a blackout for someone a kilometre
// away has no cause they can see.
private _faded = (call BIS_fnc_ListPlayers) select {_x distance _arg < _radius};
if (count _faded == 0) exitWith {[]};

{ [["", "BLACK OUT", 1.5]] remoteExec ["titleCut", _x] } forEach _faded;
// Held until every screen is actually black. The caller must not start building before that, which
// is why the wait is here rather than left to each of them to remember.
sleep 1.7;

_faded
