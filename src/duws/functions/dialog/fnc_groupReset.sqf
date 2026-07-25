// Locality: client -- passed as an addAction function value in
// misc/fnc_addHQOfficerActions.sqf, so it runs on whoever resets their group.
_grp = group player;
[player] join grpNull;
_ld = leader _grp;
[_ld] join grpNull;
player joinAsSilent [_grp,1];
_grp selectLeader player;
[_ld] joinSilent _grp;
