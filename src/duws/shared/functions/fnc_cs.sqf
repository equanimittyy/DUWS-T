// Player-callsign substitution for radio/subtitle dialogue. The stringtable bakes
// the default callsign "Alpha 1-1" into the English lines; this swaps it for the
// host-chosen duws_callsign at display time, so wrapping every localize is safe:
// it is a no-op when the callsign is unset, still the default, or the line has no
// callsign token. Only the literal "Alpha 1-1" is touched -- other callsigns
// (Overlord, Allseer, Dispatch) and non-English translations are left as-is, which
// is why localised callsigns intentionally lag the English one.
params [["_s", ""]];
if (isNil "duws_callsign") exitWith {_s};
if (duws_callsign isEqualTo "Alpha 1-1") exitWith {_s};
private _find = "Alpha 1-1";
private _flen = count _find;
private _n = count _s;
private _out = "";
private _i = 0;
while {_i < _n} do {
	if ((_s select [_i, _flen]) isEqualTo _find) then {
		_out = _out + duws_callsign;
		_i = _i + _flen;
	} else {
		_out = _out + (_s select [_i, 1]);
		_i = _i + 1;
	};
};
_out
