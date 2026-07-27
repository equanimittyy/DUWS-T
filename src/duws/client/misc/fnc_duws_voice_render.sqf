// Locality: client. Called by fnc_duws_dialogue for every VOICE line.
// [_speaker, _text] -- pushes one line onto a two-line queue and returns immediately.

// Returns immediately, always. Nine call sites reach the router through `call` rather than
// remoteExec, so suspending here would stall the calling script for the length of the line
// -- fnc_civ_healAction fires two of them either side of a sleep. Expiry is the ticker's
// job, below, never the caller's.

params [["_speaker", ""], ["_text", ""]];

if (!hasInterface || {_text isEqualTo ""}) exitWith {};

// A coordinate triple reaches this from fnc_fob_server, which builds its call with format
// and interpolates a position where the name belongs. Rendered as-is rather than hidden:
// that bug is pre-existing and should stay visible until it is fixed properly.
private _name = if (_speaker isEqualType "") then {_speaker} else {str _speaker};

// Long enough to read without holding the screen: a reply arriving under the floor would
// otherwise push its question off before anyone got through it.
private _life = ((count _text) * 0.07 + 2) max 4 min 12;

private _queue = uiNamespace getVariable ["DUWS_voice_queue", []];
_queue pushBack [_name, _text, diag_tickTime + _life];

// A third line bumps the oldest rather than queueing behind it. Dialogue narrates what the
// player is watching, so a held-back backlog arrives describing a firefight that has already
// ended; bumping still fixes the actual defect, because the line being answered is the one
// kept on screen.
if (count _queue > 2) then { _queue deleteAt 0 };
uiNamespace setVariable ["DUWS_voice_queue", _queue];

if (uiNamespace getVariable ["DUWS_voice_ticking", false]) exitWith {};
uiNamespace setVariable ["DUWS_voice_ticking", true];

[] spawn {
    scriptName "DUWS voice subtitle ticker";
    // A named layer of its own. The intro runs cutRsc, titleText and titleCut within seconds
    // of two pilot lines, and all of those take the default layer.
    private _layer = "DUWS_voice" call BIS_fnc_rscLayer;
    _layer cutRsc ["DUWS_VOICE", "PLAIN", 0, true];
    waitUntil {!isNull (uiNamespace getVariable ["DUWS_voice_display", displayNull])};
    private _ctrl = (uiNamespace getVariable "DUWS_voice_display") displayCtrl 1101;

    private _shown = "";
    while {true} do {
        private _queue = uiNamespace getVariable ["DUWS_voice_queue", []];
        _queue = _queue select {(_x select 2) > diag_tickTime};
        uiNamespace setVariable ["DUWS_voice_queue", _queue];
        if (_queue isEqualTo []) exitWith {};

        // The older line dims instead of vanishing, so a reply never erases the line it
        // answers -- the whole point of holding two.
        private _markup = "";
        {
            _x params ["_name", "_text"];
            private _alpha = ["B0", "FF"] select (_forEachIndex == (count _queue) - 1);
            private _prefix = if (_name isEqualTo "") then {""} else {format ["%1: ", _name]};
            _markup = _markup + format ["<t color='#FFFFFF%1'>%2%3</t><br/>",
                _alpha, _prefix, _text];
        } forEach _queue;

        // parseText, not ctrlSetText: a structured-text control stores a raw string verbatim
        // and renders the markup as literal on-screen characters, silently.
        if !(_markup isEqualTo _shown) then {
            _ctrl ctrlSetStructuredText (parseText _markup);
            _shown = _markup;
        };
        sleep 0.1;
    };

    _ctrl ctrlSetStructuredText (parseText "");
    _layer cutText ["", "PLAIN", 0.3];
    uiNamespace setVariable ["DUWS_voice_ticking", false];
};
