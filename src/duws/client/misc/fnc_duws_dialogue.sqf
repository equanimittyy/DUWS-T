// Locality: every machine the call site addressed. Each site reaches this through remoteExec,
// so the fan-out is already done when the body runs -- nothing here or in the drain loop may
// re-broadcast, or N clients each send to N clients.
// [_speaker, _text, _channel] -- _channel "" means decide from the speaker.
//
// Nothing is drawn here. The line is queued and fnc_duws_dialogue_drain owns the screen: ten
// sites reach this through a synchronous call, so the body must return without waiting.

params [["_speaker", ""], ["_text", ""], ["_channel", ""]];

if (!hasInterface) exitWith {};

// Built on first use, not at init: this function is publicVariable'd from the server and a
// JIP client can be handed a line before any init hook of its own has run.
if (isNil "DUWS_netSpeakers") then {
    // Keys, not literals, so the table holds in every language. allseer and Scout collapse
    // to one string in English and stay distinct in German; both are NET either way.
    DUWS_netSpeakers = [
        "STR_DUWS_T_allseer", "STR_DUWS_T_Scout", "STR_DUWS_T_Express",
        "STR_DUWS_T_Rein", "STR_DUWS_T_koipilot",
        "STR_DUWS_T_longbowpilot", "STR_DUWS_T_slingshot", "STR_DUWS_T_Cobra",
        "STR_DUWS_T_hound", "STR_DUWS_T_Signal", "STR_DUWS_T_Signal2",
        "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER",
        // Supports the player calls and then listens to. The two Pilot keys are absent on
        // purpose: the intro and downed pilots are in the room, not on the net.
        "STR_DUWS_T_chariot", "STR_DUWS_T_crane", "STR_DUWS_T_swordfish",
        // One callsign per air drop rather than one shared across all four: each body already
        // introduces its own, so a shared slot contradicted the line it was attached to.
        "STR_DUWS_T_chalk", "STR_DUWS_T_courier", "STR_DUWS_T_courier3", "STR_DUWS_T_ranger"
    ] apply { localize _x };

    // VOICE speakers who are nonetheless on the radio. The squelch marks an incoming
    // transmission, not a category, so Overlord earns one and the player callsign does not
    // -- you do not hear your own key-up. Everyone else in VOICE is in the room with you.
    DUWS_voiceSquelchSpeakers = ["STR_DUWS_T_OVERLORD"] apply { localize _x };
};

if (_channel isEqualTo "") then {
    _channel = [_speaker, DUWS_netSpeakers] call fnc_duws_dialogue_channel;
};

// Decided here, played by the drain loop when the line actually reaches the screen: the tone
// marks a transmission arriving, and this line may sit behind others before it gets there.
private _squelch = (_channel isEqualTo "NET") || {_speaker in DUWS_voiceSquelchSpeakers};

// Callsign substitution belongs here rather than at the call site, and below the decision
// above: the table holds the stringtable's "Alpha 1-1", so a host who has renamed the team
// must not reach that decision already renamed. The speaker is guarded because
// fnc_fob_server interpolates a position array where the name belongs.
if (_speaker isEqualType "") then { _speaker = [_speaker] call fnc_cs; };
_text = [_text] call fnc_cs;

// The team callsign names whoever currently speaks for it: "Alpha 1-1 (steph)".
//
// The speaker label only, never the line text -- the callsign also turns up inside dialogue,
// where Overlord addresses the team, and "Alpha 1-1 (steph), move out" would read as part of
// the sentence rather than as a transmission header. _text went through fnc_cs on its own line
// above precisely so the two can be treated differently here.
if (_speaker isEqualTo ([localize "STR_DUWS_T_actionteam"] call fnc_cs)) then {
    // Guarded for the same reason the speaker table above is built lazily: the resolver arrives
    // by publicVariable, and a JIP client can be handed a line before it lands. An unnamed
    // callsign beats an undefined-variable error taking the whole line with it.
    private _who = if (isNil "fnc_duws_senior_name") then {"None"} else {call fnc_duws_senior_name};
    _speaker = format ["%1 (%2)", _speaker, _who];
};

// Two queues rather than one with a priority insert: the drain loop empties VOICE first, which
// is the same ordering with nothing but pushBack to get wrong. Anything that is not NET queues
// as VOICE, so a channel that ever arrives malformed lands on the surface the player watches.
// uiNamespace, not missionNamespace: pending lines are display state, and the mission namespace
// is serialized into save games -- a queue held there would replay on load.
private _queueVar = ["DUWS_dialogueQueueVoice", "DUWS_dialogueQueueNet"] select (_channel isEqualTo "NET");
private _queue = uiNamespace getVariable _queueVar;
if (isNil "_queue") then {
    _queue = [];
    uiNamespace setVariable [_queueVar, _queue];
};

// Appended in place rather than read-modify-written back: the drain loop edits the same array,
// and a get/set pair either side of its deleteAt would silently drop whichever line lost.
_queue pushBack [_speaker, _text, time, _squelch];
