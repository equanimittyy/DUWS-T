// Locality: client. -> [the full row, the collapsed name, the collapsed bar and time] for one capture, so the capture
// bar and the flag's report print the same lines. _now is the meter, 0 to 1.
params ["_name", "_side", "_now", "_hold", "_blockers"];
private _opfor = _side isEqualTo east;
// The test keys are worded for BLUFOR attacking; an OPFOR row reads each one's OPFOR twin.
private _tag = ["", "_OPFOR"] select _opfor;
private _draining = count _blockers > 0;
private _segs = "||||||||||||||||||||||||||||||||||||||||";
private _n = round (_now * count _segs);
private _secs = ceil ((1 - _now) * _hold);
private _bar = format ["<t color='%1'>%2</t><t color='#404040'>%3</t>",
    ["#33b8cc", "#e60000"] select _opfor, _segs select [0, _n], _segs select [0, count _segs - _n]];
private _head = if (_draining) then { format [localize ("STR_DUWS_T_ZONE_CAPTURE_HALTED" + _tag), _name] } else {
    format [localize ("STR_DUWS_T_ZONE_CAPTURE_COUNTDOWN" + _tag), _name, _secs]
};
[
    ([_head, _bar] + (_blockers apply { "- " + localize (_x + _tag) })) joinString "<br/>",
    [_name, format [localize "STR_DUWS_T_ZONE_CAPTURE_SHORT_OPFOR", _name]] select _opfor,
    _bar + " " + (if (_draining) then { localize "STR_DUWS_T_ZONE_CAPTURE_SHORT_HALTED" } else {
        format [localize "STR_DUWS_T_ZONE_CAPTURE_SHORT_SECS", _secs] })
]
