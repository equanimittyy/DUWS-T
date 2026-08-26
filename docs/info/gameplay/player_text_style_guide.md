# Player-facing text style guide

Everything the player reads lives in `src/stringtable.xml`, grouped into `<Container>` blocks by
subsystem, under `STR_DUWS_T_*` keys (a handful of newer ones use a bare `STR_DUWS_*`); lookups are
case-insensitive, so a `localize` that differs in case from the `Key ID` still resolves. This guide
is how that text should read and which surface it belongs on.

**English is the source of truth.** Every key carries both `<Original>` and `<English>`, and Arma
falls back to `<Original>` when the active language has no tag. Edit the two in lockstep — changing
only `<English>` leaves the old wording live for anyone whose game language isn't listed on that key.

**The localised tags lag English on purpose.** The `<German>`, `<Spanish>` and `<Chinesesimp>` tags
were translated from the pre-rework text and have not been carried through the English prose passes.
They still hold retired callsigns (`Action Squad`, `Overlord 1-1`, `Viper 1-5`), the old
unnamed-department phrasing for Allseer, and pre-rework briefings whose timings and reward tags no
longer match the English. This is known divergence, not corruption: do not treat a
German/Spanish/Chinese tag that disagrees with `<English>` as a bug, and do not machine-translate the
gap closed. Retranslation is a pass of its own, because the briefings encode gameplay numbers a
translator has to check against the mission code rather than against the old text.

## Military-like language

The house voice is a professional military register: flat declaratives in the present tense,
procedure verbs (*locate, eliminate, displace, be advised, stand by, roger, over, out*), and no
theatrics. The `Support & Radio` container is the reference for radio framing. An exchange *opens*
on the address — speaker-first callsign (`Alpha 1-1, this is Overlord.` / `Swordfish 1-1 to Alpha
1-1, ...`), a team broadcast on `All units, ...` — because first contact has to establish who is
calling whom. The follow-ups on an established net drop it: the arty crew answers `Grid received.
Rounds on the way, 60 seconds.`, then later just `Splash.` and `Rounds complete. Fire mission out.`,
never `Redleg to Alpha 1-1, splash.` — the speaker label already carries the identity, so
re-addressing every line reads as stilted.

**Include:**

- **Service kill vocabulary, not shooter-game idiom.** A result reads *eliminated*, *neutralised*,
  *confirmed KIA*, *confirmed kill*, *disposed of*. Vary the verb across the elimination missions so
  four near-identical confirmations do not read as one template.
- **The concrete nouns the player plans against** — the place, the clock, the vehicle — named, not
  gestured at. The informant brief is the worked example: *an enemy informant is operating out of
  %1. Locate and eliminate him before he reaches %2 by vehicle. He is set to leave at %3 in a %4, and
  will displace early if a firefight breaks out.* — %1 the town, %2 the named escape zone, %3 the
  leave clock, %4 the vehicle class. A named place the player reads off the map beats an abstraction,
  and the fail line names where he got to. The three spec-based briefs (armour, HVT, snipers) name
  the place in code: `fnc_mission_run` finds the nearest named settlement (`nearestLocations`, a 5 km
  ring, a grid reference as fallback) and folds it into `%1`, so *marked near %1* prints *marked near
  Agglelesh*.
- **The register the speaker would use.** The command net (Overlord, Allseer) is clipped and
  procedural, and names the player's callsign on a result (*To Alpha 1-1, the informant has been
  disposed of. Good work.*). A civilian in the world speaks in character and imprecisely — a live
  bearing and range while the informant is in town (*about %1 m %2 of you*), only a bystander's guess
  once he has driven off (*Him? I think I just saw him leave town heading %1*). The system knows
  where he is; a local only saw which way he went.
- **Numbers spelled out in spoken lines, numerals in HUD text.**

**Avoid:**

- **Theatrics.** No exclamation marks, no words shouted mid-sentence (`Targeting FAILED`).
- **Shooter idiom for a kill** — never *take him down*, *tango down*, or *he's down*.
- **Narrating the software** — a line reports state, it does not say what the code is doing.
- **Em-dashes in player prose.** A parenthetical goes in commas, not dashes: *at %2, or sooner if
  shots are fired, in a %3*, not *leave at %1 — or sooner if shots are fired — in a %2*. A
  transmission is punctuated in clipped clauses, not literary asides.

The register and em-dash rules are applied as each subsystem's text is reworked, not swept across the
file at once, so older strings still carry the dash and the odd off-voice line: standing prose debt,
the same kind as the lagging localised tags, not a bug to fix in passing.

**Writing the player callsign.** The squad callsign is host-settable (`duws_callsign`, default
`Alpha 1-1`), and `fnc_cs` rewrites the literal string `Alpha 1-1` at display time. Any hint, card or
task key whose text contains `Alpha 1-1` must be localised through `([localize "STR_..."] call
fnc_cs)` — a bare `localize` prints the default callsign no matter what the host chose. Fixed
callsigns (`Overlord`, `Allseer`, `Dispatch`) are never wrapped. Dialogue is the exception:
`fnc_duws_dialogue` runs `fnc_cs` itself on both the speaker and the text, so a dialogue call site
passes the raw `localize`d key unwrapped (see [§NET, SUB-NET and VOICE](#net-sub-net-and-voice)).
Substitution matches the English literal only — a second reason the localised tags cannot be aligned
key-for-key.

## NET, SUB-NET and VOICE

`fnc_duws_dialogue` is the only path that gives a line a *speaker* — a persona, not the system's own
voice. The call is `[_speaker, _text, _channel]` with both strings already `localize`d and `_channel`
normally `""`, which lets the speaker pick the channel. `fnc_duws_dialogue_channel` routes off two
explicit speaker lists in `fnc_duws_dialogue`.

| Channel | Who | Surface | Why |
|---|---|---|---|
| **NET** | Overlord alone | engine subtitle, with a squelch tone | the command net — the briefs and results the player least wants to miss |
| **SUB-NET** | every other radio callsign (Allseer, the supports, the air drops, the rescued squad) | a bottom-left radio log (`fnc_duws_subnet_log`, RscTitles `DUWS_SubnetLog`) | radio chatter present without burying an in-room line or an Overlord brief |
| **VOICE** | everyone in the room with the player, and the default | engine subtitle | the loud visible surface — a new speaker on no list lands here |

**The speaker decides, and a voice is a real element in the fiction.** Overlord and Allseer on the
net, a support callsign the player called, an intro or downed pilot, a civilian in the world — each
is demonstrably on the net or in the room when its line plays. A one-off callsign wired to nothing
the player can see or call is not a voice; a brief and its result come from an established element,
not a name minted for the occasion. The player's own callsign is on no list — VOICE by default —
because you do not hear your own key-up.

**SUB-NET is its own overlay, not `systemChat`**, because the engine chat cannot tint a speaker.
`fnc_duws_subnet_render` redraws it on a tick and fades each line over a ten-second life, so the box
thins out during a lull rather than sitting frozen; the speaker is coloured by faction (blue BLUFOR,
red enemy, so the disguise ruse reads hostile at a glance).

**One subtitle slot, VOICE first.** The engine subtitle is a single line — a second replaces the
first mid-read — so `fnc_duws_dialogue_drain` holds one at a time, and only NET and VOICE reach it
(SUB-NET stacks in the log and needs no slot). VOICE drains first and entirely: it answers something
the player just did, and waiting behind an Overlord brief reads as a dropped button press, so it
never expires. NET is dropped once it has waited over 8 s, because an Overlord line queued behind a
long in-room exchange reads worse late than silent. SUB-NET has no drain, but a shared cursor spaces
*bunched* lines a couple of seconds apart, so two threads keying up in the same beat do not read as
garbled cross-talk; an exchange that already sleeps between its own lines prints with no added delay.

**Address the hearers; never re-broadcast.** Every call site reaches the function through
`remoteExec` — `0` for the whole team (a mission brief), a single client for a one-player answer (the
ask-reveal goes only to `_caller`). The body then runs on each machine already addressed and must not
broadcast again, or N clients each send to N. The function is `publicVariable`'d in `server_fnc_init`,
and the speaker tables build lazily on first use because a JIP client can be handed a line before its
own init has run.

## Notification card, dialogue, and the hint box

Three surfaces put text on screen and they are not interchangeable. Dialogue is the voiced channel
([above](#net-sub-net-and-voice)); the other two are the system's own voice, with no persona. **Pick
one, and never fire the same event on two.**

| Surface | Command | Use it for | Length |
|---|---|---|---|
| Dialogue | `fnc_duws_dialogue` | anything a persona could say — a fire mission called, a transport inbound or on station, an aircraft shot down, a drop delivered, a fire mission complete | subtitle or radio log |
| Hint box | `hint` | a gameplay directive or a refusal answering one player — an instruction to act on, a price, a gate; anything with no speaker | wraps, no limit |
| Notification card | `BIS_fnc_showNotification` | team news: a change of state the whole team is told about | ~60 characters, hard clip |

**The hint box is mostly a gameplay surface — keep it that way.** It exists for text that bears on
what the player does next, and little else belongs there. That is two things: gameplay directives —
the things the player reads in order to act (designating with the laser, clicking the map to set a
route, picking a valid lift target, keeping clear of enemy ground, the access key for a called-in
element) — and the refusals, prices and gate messages the request menu answers with, which gate an
action and have no speaker. Everything else has a better home: a line a callsign would plausibly
speak is voiced through `fnc_duws_dialogue`, not printed as a hint, and news the whole team needs is
a card. Flavour, chatter and results that no one is there to say do not go in the hint box at all.
Decide by whether the message is something to act on (hint) or something that happened and someone
could say (radio).

**A card is team news.** Reach for it when the audience is the whole team, whether or not they were
the one who triggered it; if the audience is one player, it is a hint or a radio line by the rule
above. Its ceiling is a hard ~60 characters that clips mid-sentence with no error
([`arma_engine_gotchas.md`](../architecture/arma_engine_gotchas.md#a-cfgnotifications-description-is-clipped-not-wrapped-past-roughly-60-characters)),
so keep it to a headline. A card's direction is carried by its colour class, not its wording — blue
for something gained, red for something lost or a critical the player must act on, white for neutral
information, cyan for economy — so the sentence itself does not have to shout the good or bad news.

**One event, one surface.** A hint doubling a voiced radio line, or a card doubling a hint, buys
nothing: the card clips at ~60 characters where the hint had no limit, and the radio already said it.
The single standing exception is kill income (`CPaddedattrition`, `server/server_init.sqf`), which by
audience is a per-player hint but wears the cyan economy card, because CP arriving is what the card
vocabulary already means and kill income is the one income that would otherwise look different; it
fires on the economy tick rather than on an action, so it is neither frequent enough to read as noise
nor small enough to want burying.

**Hint prose is system prose.** A hint reports state. It does not narrate the software (`The system
is finding…`, `Please wait…`), it does not exclaim, and it does not speak — callsign framing and
procedure words belong to dialogue, never to the hint box. A support that cannot fly says *Heavy
transport could not reach your position*, not *Mule 1-1 failed to reach your position*.

**Terminal punctuation is decided by the surface, not the sentence.** Prose surfaces are punctuated
as prose; the two surfaces that exist to be glanced at are kept bare.

| Surface | Terminal period | Because |
|---|---|---|
| Hint box | yes | it is prose the player reads, and it wraps |
| Dialogue and subtitles | yes | spoken lines, punctuated as speech |
| Mission descriptions, briefings, task text | yes | prose, read at length |
| A3 notification card | no | a headline, kept clean |
| Map marker text | no | a label on the map, kept free of clutter |

A sentence break *inside* a string is untouched — a card reads `Last Mobile HQ destroyed. Name
another in %1 min`, keeping the break and dropping the tail. A label takes no period on any surface,
because it is not a sentence: a side-mission name (`Clear Area`), a menu heading (`Mission
Selector`), a card's title field, and a line ending on a substituted value (`Squad renamed to:` plus
the name).

## The support-call cadence

Every player-called support voices the same exchange. A new one follows these beats rather than
inventing its own, from the moment the player commits the target (the map-click, or the request
confirmed):

| Beat | Speaker | Channel | When |
|---|---|---|---|
| Request | player callsign (`STR_DUWS_T_actionteam`) | VOICE | the instant the target is committed |
| Copy | Overlord | NET | same frame, back-to-back with the request |
| *(beat)* | — | — | `sleep 8`, then the callsign keys up |
| Inbound / tasking | the support's own callsign | SUB-NET | asset spawned and moving in |
| On station, splash, delivered, complete | that same callsign | SUB-NET | as it works; its own lines, spaced by their own sleeps |
| Lost before it delivers | Overlord | NET | the callsign is dead and cannot speak its own loss |

Canonical implementers, each opening `actionteam` → `OVERLORD` → `sleep 8` → callsign: the
fire-support family (arty, mortar, JDAM, cluster, napalm, laser) in
`client/supports/fnc_arty.sqf:67-79`; the drops in `fnc_ammobox.sqf` (supply, Courier 1-1),
`fnc_paradrop.sqf` (Chalk 2-1) and `fnc_veh_drop.sqf` (Courier 2-1); UAV recon split across
`client/supports/fnc_mapclickuav.sqf` and `server/supports/fnc_uav_scanner.sqf`.

Three things make it read right, and are the parts to get right in a new one:

- **Request and copy key up together; the callsign answers after the beat.** Both go out in the
  frame the player commits — waiting on the server, or on the asset spawning, reads as a dropped
  button press. The `sleep 8` sits *after* the copy, before the callsign's first transmission, so
  the support answers a beat later rather than on top of Overlord.
- **One role per channel.** The request is VOICE (the player's own team, in the room); Overlord's
  copy and any failure line are NET; every support callsign is SUB-NET. The three surfaces do not
  contend, so request, copy and inbound call can share a frame without one burying another
  ([§NET, SUB-NET and VOICE](#net-sub-net-and-voice)).
- **A loss is Overlord's to report.** When the asset dies before it delivers, the line is
  Overlord's on NET, not the callsign's — the callsign is gone. Only the failure moves to Overlord;
  arrival, work and completion stay the callsign's own.

The request passes the requester's name so every machine prints the same header: `name player` where
the opening runs client-side (the drops, arty), `name _caller` where it runs on the server (UAV). See
[§Military-like language](#military-like-language) for the callsign-substitution rule this rides on.
