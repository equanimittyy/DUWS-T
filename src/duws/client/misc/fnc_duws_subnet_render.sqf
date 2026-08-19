// Locality: client. Spawned once from client_init; owns the SUB-NET radio-log overlay's redraw.
// fnc_duws_subnet_log only appends lines -- this ages them: each holds at full brightness for
// HOLD then fades (alpha 1 -> 0) over the remainder of LIFETIME and drops when spent, so older
// traffic reads progressively fainter after its hold window and a lull
// empties the box. A structured-text control has no per-line opacity, so the fade is baked into
// each line's colour as a leading ARGB alpha byte and the whole block is rebuilt every tick.
if (!hasInterface) exitWith {};

#define SUBNET_LIFETIME 15
#define SUBNET_HOLD 8
#define HEXDIGITS "0123456789abcdef"

private _lastEmpty = false;
while {true} do {
    private _disp = uiNamespace getVariable ["DUWS_subnetDisplay", displayNull];
    if (isNull _disp) then {
        sleep 0.3;
    } else {
        private _now = time;
        private _lines = uiNamespace getVariable ["DUWS_subnetLines", []];
        private _live = _lines select { (_now - (_x select 0)) < SUBNET_LIFETIME };
        if (count _live != count _lines) then {
            uiNamespace setVariable ["DUWS_subnetLines", _live];
        };

        if (_live isEqualTo []) then {
            // Clear once, then idle: nothing to fade until the next line arrives.
            if (!_lastEmpty) then {
                (_disp displayCtrl 8812) ctrlSetStructuredText parseText "";
                _lastEmpty = true;
            };
            sleep 0.3;
        } else {
            _lastEmpty = false;
            private _rich = "";
            {
                _x params ["_stamp", "_sp", "_tx", "_rgb"];
                // Hold at full brightness for SUBNET_HOLD, then fade over the remainder to 0 at LIFETIME.
                private _a = 1 - (((_now - _stamp) - SUBNET_HOLD) / (SUBNET_LIFETIME - SUBNET_HOLD));
                _a = 0 max _a min 1;
                private _byte = round (_a * 255);
                private _ah = (HEXDIGITS select [floor (_byte / 16), 1]) + (HEXDIGITS select [_byte mod 16, 1]);
                if (_rich != "") then { _rich = _rich + "<br/>"; };
                // Same alpha on speaker and text so a line fades as one unit.
                _rich = _rich + format ["<t color='#%1%2'>%3</t><t color='#%1ffffff'>: %4</t>", _ah, _rgb, _sp, _tx];
            } forEach _live;
            (_disp displayCtrl 8812) ctrlSetStructuredText parseText _rich;
            sleep 0.15;
        };
    };
};
