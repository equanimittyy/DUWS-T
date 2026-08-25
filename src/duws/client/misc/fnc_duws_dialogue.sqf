// Locality: every machine the call site addressed. Each site reaches this through remoteExec,
// so the fan-out is already done when the body runs -- nothing here or in the drain loop may
// re-broadcast, or N clients each send to N clients.
// [_speaker, _text, _channel] -- _channel "" means decide from the speaker.
//
// NET and VOICE are queued for fnc_duws_dialogue_drain, which owns the single subtitle slot;
// SUB-NET is sent to the chat box here, since that surface stacks and has no slot to contend
// for. Either way the body returns without waiting: ten sites reach it by call.

// Seconds SUB-NET spaces bunched lines by, so two threads keying up together do not dump at
// once and read as garbled cross-talk. One constant to tune if the net's cadence reads wrong.
#define SUBNET_GAP 2

params [["_speaker", ""], ["_text", ""], ["_channel", ""], ["_caller", ""]];

if (!hasInterface) exitWith {};

// Built on first use, not at init: this function is publicVariable'd from the server and a
// JIP client can be handed a line before any init hook of its own has run.
if (isNil "DUWS_netSpeakers") then {
    // NET is the prominent command net: Overlord alone, on the subtitle with a squelch. Its
    // briefs and results are the lines the player least wants to miss.
    DUWS_netSpeakers = ["STR_DUWS_T_OVERLORD"] apply { localize _x };

    // SUB-NET is every other radio callsign -- supports, air drops, the rescued squad, the
    // recon net -- routed to the bottom-left chat box: present but out of the subtitle's way,
    // so radio chatter never buries an in-room line or an Overlord brief. Keys, not literals,
    // so the table holds in every language (allseer and Scout collapse to one English string
    // and stay distinct in German; both are SUB-NET either way).
    DUWS_subnetSpeakers = [
        "STR_DUWS_T_allseer", "STR_DUWS_T_Scout", "STR_DUWS_T_Express",
        "STR_DUWS_T_Rein", "STR_DUWS_T_koipilot",
        "STR_DUWS_T_longbowpilot", "STR_DUWS_T_slingshot", "STR_DUWS_T_Cobra",
        "STR_DUWS_T_hound", "STR_DUWS_T_Signal", "STR_DUWS_T_Signal2",
        "STR_DUWS_T_DISGUISE_OPFOR_SPEAKER",
        // The two Pilot keys are absent on purpose: the intro and downed pilots are in the
        // room, not on the net.
        "STR_DUWS_T_chariot", "STR_DUWS_T_crane", "STR_DUWS_T_swordfish",
        // One callsign per air drop rather than one shared across all four: each body already
        // introduces its own, so a shared slot contradicted the line it was attached to.
        "STR_DUWS_T_chalk", "STR_DUWS_T_courier", "STR_DUWS_T_courier3", "STR_DUWS_T_ranger"
    ] apply { localize _x };

    // The SUB-NET speakers who are OPFOR, so the log tints them red instead of the BLUFOR blue
    // default. Only the disguise ruse speaks for the enemy today; the list is the seam to widen
    // if more enemy radio is ever added.
    DUWS_subnetOpforSpeakers = ["STR_DUWS_T_DISGUISE_OPFOR_SPEAKER"] apply { localize _x };
};

if (_channel isEqualTo "") then {
    _channel = [_speaker, DUWS_netSpeakers, DUWS_subnetSpeakers] call fnc_duws_dialogue_channel;
};

// The tone marks a radio transmission arriving, so both radio channels earn it; VOICE is in
// the room and does not. NET's plays from the drain when the line reaches the screen (it may
// sit behind others first); SUB-NET's plays below, when it prints.
private _squelch = _channel in ["NET", "SUB-NET"];

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
    // _caller names the player who requested this line, resolved at the call site (the support
    // fn) and passed in verbatim so every machine prints the same name. It cannot be resolved
    // here: this body runs on every client, where `player` is the local player, not the
    // requester. Lines with no requester -- mission chatter, the intro -- pass nothing and fall
    // back to the team senior, itself resolved identically on every client.
    //
    // The senior fallback is guarded for the same reason the speaker table above is built lazily:
    // the resolver arrives by publicVariable, and a JIP client can be handed a line before it
    // lands. An unnamed callsign beats an undefined-variable error taking the whole line with it.
    private _who = if (_caller isEqualTo "") then {
        if (isNil "fnc_duws_senior_name") then {"None"} else {call fnc_duws_senior_name}
    } else { _caller };
    _speaker = format ["%1 (%2)", _speaker, _who];
};

// SUB-NET goes to the bottom-left radio log (fnc_duws_subnet_log), not the subtitle queue: it
// stacks lines and persists, so there is no single slot to serialise. But lines that arrive
// bunched -- two threads keying up in the same beat -- would print at once and read as garbled
// cross-talk, so each claims the next free slot on a shared cursor and prints when it comes up.
// Bunched lines space out to SUBNET_GAP apart; a scripted exchange that already sleeps between
// its own lines finds the cursor long passed and prints with no added delay -- the gap only
// bites when the net is genuinely busy. The speaker is tinted by faction: blue for BLUFOR, red
// for the enemy, so the disguise ruse reads as hostile at a glance.
if (_channel isEqualTo "SUB-NET") exitWith {
    private _colour = ["6d9eff", "ff6b6b"] select (_speaker in DUWS_subnetOpforSpeakers);
    private _slot = time max (uiNamespace getVariable ["DUWS_subnetNextAt", 0]);
    uiNamespace setVariable ["DUWS_subnetNextAt", _slot + SUBNET_GAP];
    [_speaker, _text, _squelch, _colour, _slot - time] spawn {
        params ["_sp", "_tx", "_sq", "_col", "_wait"];
        if (_wait > 0) then { sleep _wait };
        if (_sq) then { playSound "DUWS_Radio_Start" };
        [_sp, _tx, _col] call fnc_duws_subnet_log;
    };
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
