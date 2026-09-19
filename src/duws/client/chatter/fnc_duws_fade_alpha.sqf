// Locality: client. A structured-text control has no per-line opacity, so a line fades through its ARGB alpha byte.
params ["_age", "_hold", "_life"];
private _byte = round (255 * (0 max (1 - ((_age - _hold) / (_life - _hold))) min 1));
private _hex = "0123456789abcdef";
(_hex select [floor (_byte / 16), 1]) + (_hex select [_byte mod 16, 1])
