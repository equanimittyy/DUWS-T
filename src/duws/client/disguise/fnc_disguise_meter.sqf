// Locality: client; the server's disguise monitor remoteExecs it on each tick the meter is above the
// floor, and once more at the floor, after which the box fades on its own.
// hintSilent, not hint, because this repeats twice a second and hint clicks every time.
params ["_meter", "_floor"];

private _bar = {
    params ["_n", "_colour"];
    private _s = "";
    for "_i" from 1 to _n do { _s = _s + "|" };
    format ["<t color='%1'>%2</t>", _colour, _s]
};
private _floorSeg = round (_floor / 5);
private _meterSeg = (round (_meter / 5)) max _floorSeg;
hintSilent parseText format [
    "<t align='center'>%1</t><br/><t align='center' size='1.6'>%2%3%4</t>",
    localize "STR_DUWS_T_DISGUISE_METER",
    [_floorSeg, "#b0b0b0"] call _bar,
    [_meterSeg - _floorSeg, "#ff4040"] call _bar,
    [20 - _meterSeg, "#404040"] call _bar
];
