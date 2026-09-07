// Locality: each client -- the thread remoteExecs it (JIP, keyed on the house) so a shot fired on any
// machine registers the breach. A server-only HitPart would miss every round a client fires.
//
// The breach trigger: a HitPart on the locked safehouse. First hit fires once (the flag + self-removal
// keep a burst from spamming the server), then routes to fnc_raid_safehouse_breach on the server, which
// owns the unlock and the guard flip / rep penalty.
params ["_house"];
if (isNull _house) exitWith {};

_house addEventHandler ["HitPart", {
    private _hit = _this select 0;
    private _target = _hit select 0;
    private _shooter = _hit select 1;
    if (_target getVariable ["DUWS_safehouse_localHit", false]) exitWith {};
    _target setVariable ["DUWS_safehouse_localHit", true];
    _target removeEventHandler ["HitPart", _thisEventHandler];
    [_target, _shooter] remoteExec ["fnc_raid_safehouse_breach", 2];
}];
