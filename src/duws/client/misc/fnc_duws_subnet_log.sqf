// Locality: client. One call per SUB-NET line, already faction-coloured and paced by
// fnc_duws_dialogue's cursor. This only appends the line; fnc_duws_subnet_render owns the redraw
// and the age-fade, so the two never fight over the control -- the pusher runs start-to-finish
// with no suspension, so its read-append-write cannot interleave with the loop's prune.
// [_speaker, _text, _colour] -- speaker/text localized and substituted; colour a bare 6-hex RGB
// (no leading #), so the render loop can prepend a per-line alpha byte.
params ["_speaker", "_text", "_colour"];
if (!hasInterface) exitWith {};

#define SUBNET_MAXLINES 5

private _lines = uiNamespace getVariable ["DUWS_subnetLines", []];
_lines pushBack [time, _speaker, _text, _colour];
if (count _lines > SUBNET_MAXLINES) then {
    _lines = _lines select [count _lines - SUBNET_MAXLINES, SUBNET_MAXLINES];
};
uiNamespace setVariable ["DUWS_subnetLines", _lines];
