// Locality: client -- the Debug Views page's OPCOM AI overlay toggle. Re-checked against game_master because
// the function is broadcast to every client.
if (!hasInterface) exitWith {};
if (!((vehiclevarname player) in game_master)) exitWith {};

#define AI_RECENT_HOLD 8
#define AI_RECENT_LIFETIME 15

if (missionNamespace getVariable ["DUWS_dbgOpcomAiOn", false]) exitWith {
    DUWS_dbgOpcomAiOn = false;
    ("DUWS_OpcomAiLog" call BIS_fnc_rscLayer) cutText ["", "PLAIN"];
    hint "OPCOM AI: overlay off.";
};

DUWS_dbgOpcomAiOn = true;
DUWS_dbgOpcomAiHeader = "OPCOM AI";
DUWS_dbgOpcomAiRows = [];
DUWS_dbgOpcomAiLimits = [];
DUWS_dbgOpcomAiRecent = [];
DUWS_dbgOpcomAiSeq = 0;
("DUWS_OpcomAiLog" call BIS_fnc_rscLayer) cutRsc ["DUWS_OpcomAiLog", "PLAIN", 0, false];
// Generation token: a quick off/on can leave the old loop mid-sleep, and only the newest may run.
private _gen = (missionNamespace getVariable ["DUWS_dbgOpcomAiGen", 0]) + 1;
DUWS_dbgOpcomAiGen = _gen;
[_gen] spawn {
    params ["_gen"];
    private _pollAt = 0;
    while {DUWS_dbgOpcomAiOn && {DUWS_dbgOpcomAiGen == _gen}} do {
        // 5 s mirrors OPCOM_TICK_PERIOD, a server-only global that is nil here.
        if (time >= _pollAt) then {
            [player, DUWS_dbgOpcomAiSeq] remoteExec ["fnc_debug_opcom_ai", 2];
            _pollAt = time + 5;
        };
        private _disp = uiNamespace getVariable ["DUWS_opcomAiDisplay", displayNull];
        if (!isNull _disp) then {
            private _now = time;
            private _lines = [format ["<t color='#ffaa00'>%1</t>", DUWS_dbgOpcomAiHeader], "<t color='#ffaa00'>--- Limits ---</t>"];
            {
                private _items = _x apply {
                    if (_x isEqualType "") then { _x } else {
                        _x params ["_label", "_n", "_cap"];
                        format ["<t color='%1'>%2 %3/%4</t>", ["#ffffff", "#ff5555"] select (_n >= _cap), _label, _n, _cap]
                    }
                };
                _lines pushBack format ["<t color='#ffffff'>%1</t>", _items joinString "   "];
            } forEach DUWS_dbgOpcomAiLimits;
            _lines pushBack "<t color='#ffaa00'>--- Orders ---</t>";
            private _rows = [DUWS_dbgOpcomAiRows, ["No persistent orders."]] select (DUWS_dbgOpcomAiRows isEqualTo []);
            { _lines pushBack format ["<t color='#ffffff'>%1</t>", _x] } forEach _rows;
            _lines pushBack "<t color='#ffaa00'>--- Log ---</t>";
            {
                _x params ["_stamp", "_text"];
                if ((_now - _stamp) < AI_RECENT_LIFETIME) then {
                    _lines pushBack format ["<t color='#%1aaaaaa'>%2</t>", [_now - _stamp, AI_RECENT_HOLD, AI_RECENT_LIFETIME] call fnc_duws_fade_alpha, _text];
                };
            } forEach DUWS_dbgOpcomAiRecent;
            (_disp displayCtrl 8813) ctrlSetStructuredText parseText (_lines joinString "<br/>");
        };
        sleep 0.2;
    };
};
hint "OPCOM AI: overlay on.";
