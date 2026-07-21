_grp = group player;
[player] join grpNull;
_ld = leader _grp;
[_ld] join grpNull;
player joinAsSilent [_grp,1];
_grp selectLeader player;
[_ld] joinSilent _grp;
