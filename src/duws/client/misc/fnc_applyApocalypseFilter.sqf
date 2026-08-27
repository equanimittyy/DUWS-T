// Locality: client -- the apocalypse post-process look. Registered from client_init and re-applied
// there on the apocalypse_mode public-variable handler (JIP or a mid-game toggle).
// clear any prior effect first, keyed by a unique ID
private _idCC = 15001;
private _idGrain = 15002;
private _idBlur = 15003;

ppEffectDestroy _idCC;
ppEffectDestroy _idGrain;
ppEffectDestroy _idBlur;

// colour correction: strong end-of-world tint
private _cc = ppEffectCreate ["ColorCorrections", _idCC];
_cc ppEffectEnable true;
_cc ppEffectAdjust [
    0.7,        // brightness down
    1.2,        // high contrast
    0.0,        // offset
    [0,0,0,0],  // start blend
    [1.0,0.5,0.2,0.9], // strong orange-red tint (A=0.9 = high intensity)
    [0.9,0.9,0.9,0.0]  // heavily desaturated (near monochrome, slight tint kept)
];
_cc ppEffectCommit 0;

// slight edge blur to fake a vignette; dynamic blur instead of chromatic aberration
private _blur = ppEffectCreate ["DynamicBlur", _idBlur];
_blur ppEffectEnable true;
_blur ppEffectAdjust [0.02];
_blur ppEffectCommit 0;

["INFO", "SUPPORT", "Aggressive filters applied."] call fnc_log;
