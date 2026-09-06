// Locality: server. Set every hit point to a uniform damage value. Use over setDamage when parts must be
// even -- setDamage cascades unevenly by config armour. Does not move getDammage; call setDamage for that.
params ["_veh", "_dmg"];
{
    _veh setHitPointDamage [_x, _dmg];
} forEach (getAllHitPointsDamage _veh param [0, []]);
