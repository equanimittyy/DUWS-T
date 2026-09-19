// Locality: server. A row is a section-header string or [label, value, detail?]; each also goes to the .rpt.
if (!isServer) exitWith {};

params ["_title", "_subtitle", "_rows", "_caller"];

private _markup = format ["<t size='1.3' color='#00ffff'>%1</t><br/><t size='0.85' color='#b0b0b0'>%2</t><br/>", _title, _subtitle];
{
	if (_x isEqualType "") then {
		diag_log format ["[%1 %2]", toUpper _x, _subtitle];
		_markup = _markup + format ["<br/><t color='#ffcc66'>%1</t><br/>", toUpper _x];
	} else {
		_x params ["_label", "_value", ["_detail", ""]];
		diag_log format ["  %1: %2  %3", _label, _value, _detail];
		_markup = _markup + format ["<t align='left'>%1</t><t align='right'>%2</t><br/>", _label, _value];
		if (_detail isNotEqualTo "") then {
			_markup = _markup + format ["<t align='left' size='0.8' color='#b0b0b0'>%1</t><br/>", _detail];
		};
	};
} forEach _rows;

// hint takes no duration; each re-issue restarts its fade. Stops on a newer readout, which it would paint over.
[_markup, {
	DUWS_debugLedgerHint = _this;
	hint parseText _this;
	for "_i" from 1 to 3 do {
		sleep 10;
		if (DUWS_debugLedgerHint isNotEqualTo _this) exitWith {};
		hintSilent parseText _this;
	};
}] remoteExec ["spawn", _caller];
