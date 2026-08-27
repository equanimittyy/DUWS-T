// Locality: server -- called via remoteExec [_center, 2] from the client-side air supports that script
// their own kill (the laser bomb and JDAM). Runs here because the OPFOR AI is server-owned: setDamage
// on the calling client only damages that client's own copy, so the strike would kill on the caller's
// screen and leave the enemy alive for everyone else. nearObjects runs server-side too, off the
// authoritative positions. Two rings: everything inside 20 m is wounded, everything inside 10 m killed.
params ["_center"];
private _hit = _center nearObjects 20;
{ _x setDamage 0.5 } forEach _hit;
{ _x setDamage 1 } forEach (_hit select { _x distance _center < 10 });
