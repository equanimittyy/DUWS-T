// Reads the disguise flags, not captive: captive also covers the inbound High Command aircraft and captive
// mission units, which OPCOM must keep seeing. A vehicle counts only when everyone aboard is disguised.
params ["_obj"];
private _men = if (_obj isKindOf "CAManBase") then { [_obj] } else { crew _obj };
_men isNotEqualTo [] && {(_men findIf {
    !(_x getVariable ["DUWS_disguised", false] || {_x getVariable ["DUWS_enemyDisguised", false]})
}) < 0}
