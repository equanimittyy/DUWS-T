// Locality: client. Spawned once from client_init, runs for the mission.
//
// The engine subtitle is a single slot -- a second line replaces the first mid-read. Supports
// are independent comm-menu items with no shared lock, so two of them talking over each other
// is ordinary play rather than abuse, and fnc_arty.sqf posts two lines in the same frame on
// its own. Holding one line at a time is this loop's whole job; fnc_duws_dialogue only queues.

if (!hasInterface) exitWith {};

while {true} do {
    private _voice = uiNamespace getVariable ["DUWS_dialogueQueueVoice", []];
    private _net = uiNamespace getVariable ["DUWS_dialogueQueueNet", []];

    if (_voice isEqualTo [] && {_net isEqualTo []}) then {
        sleep 0.25;
    } else {
        // VOICE drains first and entirely: it is someone in the room answering a player
        // action, and waiting behind an Overlord brief reads as the game ignoring the button
        // press. NET starving under a long face-to-face exchange is the intended trade --
        // those lines expire below rather than queue up and play back out of order.
        private _fromVoice = !(_voice isEqualTo []);
        private _entry = if (_fromVoice) then {_voice deleteAt 0} else {_net deleteAt 0};
        _entry params ["_speaker", "_text", "_stamp", "_squelch"];

        // A NET line held this long is dropped rather than shown late: an Overlord brief that
        // surfaces long after the moment it answered reads worse than silence. VOICE never
        // expires -- it answers something the player just did, so late still beats swallowed.
        if (_fromVoice || {time - _stamp < 8}) then {
            // The tone takes its own thread so it lands on a different frame from the
            // subtitle below. Playing it on the same frame froze the client during the
            // post-landing load spike, where this mission-PBO sound competes with unit
            // spawning and the arsenal config scan. Spacing below keeps two tones apart, so
            // no mutex is needed on top of the spawn.
            if (_squelch) then { [] spawn { playSound "DUWS_Radio_Start" } };

            [_speaker, _text] call BIS_fnc_showSubtitle;

            // Reading time, not an engine value: BIS_fnc_showSubtitle reports neither how long
            // it holds a line nor when it clears. Deliberately short of a slow read -- release
            // early and the next line replaces this one cleanly, release late and the screen
            // sits blank in between. One constant to tune if it reads wrong in play.
            sleep (((1.5 + 0.045 * (count _text)) max 2.5) min 7);
        };
    };
};
