// Locality: every machine the call site addressed. Each site reaches this through
// remoteExec, so the fan-out is already done when the body runs -- every surface picked
// below must be a local call, or N clients each re-broadcast to N clients.
// [_speaker, _text, _channel] -- _channel "" means decide from the speaker.

params [["_speaker", ""], ["_text", ""], ["_channel", ""]];

if (!hasInterface) exitWith {};

// Built on first use, not at init: this function is publicVariable'd from the server and a
// JIP client can be handed a line before any init hook of its own has run.
if (isNil "DUWS_netSpeakers") then {
    // Keys, not literals, so the table holds in every language. allseer and Scout collapse
    // to one string in English and stay distinct in German; both are NET either way.
    DUWS_netSpeakers = [
        "STR_DUWS_T_allseer", "STR_DUWS_T_Scout", "STR_DUWS_T_Express",
        "STR_DUWS_T_Viper", "STR_DUWS_T_Rein", "STR_DUWS_T_koipilot",
        "STR_DUWS_T_changgongpilot", "STR_DUWS_T_slingshot", "STR_DUWS_T_Cobra",
        "STR_DUWS_T_hound", "STR_DUWS_T_Signal", "STR_DUWS_T_Signal2",
        "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER",
        // Supports the player calls and then listens to. The two Pilot keys are absent on
        // purpose: the intro and downed pilots are in the room, not on the net.
        "STR_DUWS_T_chariot", "STR_DUWS_T_crane", "STR_DUWS_T_stork",
        "STR_DUWS_T_swordfish"
    ] apply { localize _x };

    // VOICE speakers who are nonetheless on the radio. The squelch marks an incoming
    // transmission, not a category, so Overlord earns one and the player callsign does not
    // -- you do not hear your own key-up. Everyone else in VOICE is in the room with you.
    DUWS_voiceSquelchSpeakers = ["STR_DUWS_T_OVERLORD"] apply { localize _x };
};

if (_channel isEqualTo "") then {
    _channel = [_speaker, DUWS_netSpeakers] call fnc_duws_dialogue_channel;
};

// Local, like every other surface here: the tone is per-listener, and remoteExec would play
// it once per client per line. Decided before substitution so it reads the roster name.
if (_channel isEqualTo "NET" || {_speaker in DUWS_voiceSquelchSpeakers}) then {
    playSound "DUWS_Radio_Start";
};

// Callsign substitution belongs here rather than at the call site, and below the decision
// above: the table holds the stringtable's "Alpha 1-1", so a host who has renamed the team
// must not reach that decision already renamed. The speaker is guarded because
// fnc_fob_server interpolates a position array where the name belongs.
if (_speaker isEqualType "") then { _speaker = [_speaker] call fnc_cs; };
_text = [_text] call fnc_cs;

if (_channel isEqualTo "NET") exitWith {
    // Local, never remoteExec: see the locality note at the top. The [side, identity] form
    // is what puts the speaker in the sender slot so the engine renders "Speaker: line".
    [west, _speaker] sideChat _text;
};

// The engine's own subtitle. A two-line queue drawn into a custom RscTitles was tried and
// reverted: it read worse than this does, and the routing above is what the change was for.
// The one sanctioned call -- the retired-name lint bans it everywhere else.
[_speaker, _text] call BIS_fnc_showSubtitle;
