# Player-facing text style guide

Everything the player reads lives in `src/stringtable.xml`, grouped into `<Container>` blocks by
subsystem, under `STR_DUWS_T_*` keys (a handful of newer ones use a bare `STR_DUWS_*`); lookups are
case-insensitive, so a `localize` that differs in case from the `Key ID` still resolves. This guide
is how that text should read, which surface it belongs on, and how the scroll-menu entries that carry
much of it are styled.

**English is the source of truth.** Every key carries both `<Original>` and `<English>`, and Arma
falls back to `<Original>` when the active language has no tag. Edit the two in lockstep — changing
only `<English>` leaves the old wording live for anyone whose game language isn't listed on that key.

**Every language tag tracks English.** When an `<English>` line changes, every language tag on that
key changes with it in the same edit, under the rules below; a key without language tags needs
nothing. Retranslating a whole language is a pass of its own
([localisation plan](../../plans/localisation_catchup_plan.md)), because the briefings encode
gameplay numbers a translator has to check against the current English rather than against old
text. The `<Spanish>` and the few `<Chinese>` (Traditional) tags still hold pre-rework text —
retired callsigns (`Action Squad`, `Overlord 1-1`, `Viper 1-5`) and briefings whose timings and
reward tags no longer match — until their pass.

**What a translation keeps from English.** A translation pass fills only the language tags: it never
changes `<Original>`, `<English>` or the set of `Key ID`s. Callsigns (`Alpha 1-1`, `Overlord`,
`Allseer`) and the `BLUFOR`/`OPFOR` labels stay in English inside every language tag. For
`Alpha 1-1` this is a code constraint, not only a style choice: `fnc_cs` replaces that literal only,
so a translated callsign ignores the host's `duws_callsign`. Each translation keeps every `%n`
placeholder of its English line; the order can change, because `format` substitutes by index. A key
whose text stays English (a callsign, a bare number) gets no language tag, so it falls back to
`<Original>` and follows later English edits.

**Per-language conventions.** An edit to a language tag repeats that language's row. For a term the
table does not fix, reuse the rendering other keys already give the same English word, and quote a
UI label in prose exactly as its own key reads. FOB, CP, AP, HC and CAS stay Latin acronyms in every
language.

| Tag | Address | Quotes | Punctuation and numbers | Fixed terms |
|---|---|---|---|---|
| `<Chinesesimp>` | 你 | “…” | Full-width punctuation; 。 only where the English ends with a period; a half-width space between a Chinese character and an adjacent Latin word, number or placeholder, none next to full-width punctuation | vehicle 载具, HQ 总部 |
| `<German>` | du; Overlord to the squad: ihr | „…“ | Decimal comma; `%1 m`; a count or unknown-gender placeholder goes after a colon (`Zerstört: %1`); an English em dash becomes ` – ` | vehicle Fahrzeug, HQ stays HQ, task force Task Force, mortar Mörser |
| `<Polish>` | ty; Overlord to the squad: plural imperatives | „…” | Decimal comma; `%1 m`; a count or unknown-gender placeholder goes after a colon (`Zniszczono: %1`); no gendered past tense aimed at the player, masculine where it cannot be avoided | vehicle pojazd, HQ stays HQ, town miejscowość, hardpoint punkt oporu |

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
- **An exchange is a conversation, not a form to fill in.** Each line answers the one before it, and a
  closing line answers the brief that opened the exchange — it names the concrete outcome *this*
  mission produced, not a confirmation that would fit any target. `supplytruckwin` lands the specific
  payoff (*truck's secure at base, good work. Enemy stores are being logged into your arsenal now*),
  `towerclose` names the effect (*the radio tower is down and enemy comms with it*), and a close can
  answer the copy's own words — a squad that radioed *moving to clear them out* is told the camp is
  *cleared*. A swappable *target confirmed destroyed, good work* reads as a stamped template because
  it is one. The test: read the brief, the copy and the close back as one radio exchange; if the close
  would sit unchanged under a different mission's brief, it is too generic to earn its place.
- **A specific line for a win and for a distinctive loss; the shared notice for a plain timeout.** A win
  earns its own close (above). A *distinctive* loss — one with its own event, the prize destroyed, the
  hostage killed, the target driven off — earns a line that names that event. A plain deadline expiry
  does not: it routes to the one shared notice (`fnc_mission_timeout_notice`, `STR_DUWS_T_mission_deadline_fail`),
  never a per-mission timeout string. Two reasons. One, maintainability: one line across every default
  mission, not a near-duplicate *we're out of time* per thread. Two, a timeout line must not assert world
  state. The clock running out does not mean the objective is gone, untouched, recovered or relocated —
  the player may still destroy or finish it after the deadline — so a bespoke *the cache remains intact*
  can be flatly false by the time it is read. The shared notice states only what the deadline proves: the
  time ran out. Reserve `_failLine` (and a custom fail branch's spoken line) for the distinctive loss; let
  the timeout fall through to the notice.
- **The concrete nouns the player plans against** — the place, the clock, the vehicle — named, not
  gestured at. The informant brief is the worked example: *an enemy informant is operating out of
  %1. Locate and eliminate him before he reaches %2 by vehicle. He is set to leave at %3 in a %4, and
  will displace early if a firefight breaks out.* — %1 the town, %2 the named escape zone, %3 the
  leave clock, %4 the vehicle class. A named place the player reads off the map beats an abstraction,
  and the fail line names where he got to. The three spec-based briefs (armour, HVT, snipers) name
  the place in code: `fnc_place_name` finds the nearest named settlement (`nearestLocations`, a 5 km
  ring, a grid reference as fallback) and folds it into `%1`, so *marked near %1* prints *marked near
  Agglelesh*.
- **The register the speaker would use.** Overlord is command: clipped and procedural, it tasks the
  player, confirms a result and names the player's callsign (*To Alpha 1-1, the informant has been
  disposed of. Good work.*). Allseer is the ISR feed, not a commander — it reports what
  it sees and may recommend a course of action *to Overlord*, but it addresses command, not the
  player, and never tasks or orders the player itself; the tasking that reaches the player is
  Overlord's. A civilian in the world speaks in character and imprecisely — a live
  bearing and range while the informant is in town (*about %1 m %2 of you*), only a bystander's guess
  once he has driven off (*Him? I think I just saw him leave town heading %1*). The system knows
  where he is; a local only saw which way he went.
- **Numbers spelled out in spoken lines, numerals in HUD text.**

**Avoid:**

- **Theatrics.** No exclamation marks, no words shouted mid-sentence (`Targeting FAILED`).
- **Shooter idiom for a kill** — never *take him down*, *tango down*, or *he's down*.
- **A bare appended callsign as self-identification** — `Alpha 1-1, Overlord. ...`. The speaker
  label already carries who is talking, so a callsign tacked on with only a comma reads as a label,
  not speech. Self-identification is either worded (`Alpha 1-1, this is Overlord`, or `Overlord to
  Alpha 1-1`) or dropped, and a result addresses the hearer instead (`To Alpha 1-1, ...`).
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
| **SUB-NET** | every other radio callsign (Allseer, the supports, the air drops, the rescued squad, the task forces, whose drawn names pass `"SUB-NET"` explicitly) | a bottom-left radio log (`fnc_duws_subnet_log`, RscTitles `DUWS_SubnetLog`) | radio chatter present without burying an in-room line or an Overlord brief |
| **VOICE** | everyone in the room with the player, and the default | engine subtitle | the loud visible surface — a new speaker on no list lands here |

**The speaker decides, and a voice is a real element in the fiction.** Overlord and Allseer on the
net, a support callsign the player called, an intro or downed pilot, a civilian in the world — each
is demonstrably on the net or in the room when its line plays. Overlord and Allseer are not
interchangeable: Overlord is the command voice that tasks the player and calls results, while Allseer
is the ISR feed — it reports contacts and can recommend action *to Overlord*, but it talks to
command, not the player, and never tasks or orders the player directly. A one-off callsign wired to nothing
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
There are two standing exceptions. Kill income (`CPaddedattrition`, `server/server_init.sqf`) is by
audience a per-player hint but wears the cyan economy card, because CP arriving is what the card
vocabulary already means and kill income is the one income that would otherwise look different; it
fires on the economy tick rather than on an action, so it is neither frequent enough to read as noise
nor small enough to want burying. Incoming OPCOM artillery (`DUWS_fnc_opcom_fireWarn`,
`server/warcom/opcom/appraisal/fnc_opcom_fire.sqf`) is voiced by Allseer and also carded red
(`critical`), because a barrage kills whoever stays and a radio line can scroll past under other
chatter.

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
because it is not a sentence: a side-mission name (`Destroy Radar`), a menu heading (`Mission
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

Fire support carries an extra ordering rule. The `Splash.` impact call fires as the first round
lands, and the fire-mission-out sign-off follows it (`Rounds complete.` for tube and mortar,
`Ordnance delivered. Fire mission out.` for the air-delivered types) — splash first, sign-off after,
never the reverse. A tube or mortar salvo walks over several seconds, which spaces the two on its
own; a single air-delivered round (JDAM, cluster, napalm, laser) lands all at once, so its sign-off
is held a few seconds longer (`client/supports/fnc_arty.sqf`) or it would tread on the splash.

The request passes the requester's name so every machine prints the same header: `name player` where
the opening runs client-side (the drops, arty), `name _caller` where it runs on the server (UAV). See
[§Military-like language](#military-like-language) for the callsign-substitution rule this rides on.

## Three mechanisms produce a scroll entry

| Mechanism | Produces | Used for |
| --- | --- | --- |
| `addAction` | An instant scroll entry | Almost everything |
| `BIS_fnc_holdActionAdd` | A hold-to-complete entry with an icon and progress ring | Searching bodies and containers, the disguise panel |
| `fnc_open_action_menu` | A dialog listbox opened *by* one scroll entry | Collapsing a cluster of related entries into a single scroll row |

`src/duws/client/dialog/fnc_open_action_menu.sqf` is the escape hatch from scroll-menu sprawl:
Vehicle Recycling, Vehicle Customization, Killhouse Controls, Quick Kits and the debug menu each
occupy one scroll row and expand into a list. Rows in that listbox are *not* action-menu entries.

The request menu's COMMAND AND CONTROL column is the same idea one level up: everything a player has
to ask command for is a button in the dialog Requests already opens, so the HQ structure carries one
scroll entry instead of the twelve it once did. The dividing line is **who needs it and how fast** —
an arsenal, a HALO jump, quick kits, an AI rearm and the killhouse teleports stay on the scroll
wheel and on the prop they belong to, because a player reaches for those without asking
anyone. Squad and FOB management, operative recruitment, intel analysis, the garbage cleanup (Game
Master only) and the redeploy are buttons, built by `fnc_command_fill` in that order: what costs
nothing above what does, and the analysis directly under the operatives whose take it converts.

Rest and the squad-leader reset went the other way and are scroll entries again, on the HQ medical
tent (`fnc_medtent_actions`) and on the FOB object. Both are things a player walks somewhere to do
rather than things they ask command for, and resting treats who is standing at that site.

## Buckets

Every entry belongs to a bucket, and the bucket decides both how the title looks and where the entry
sits in the scroll list. `src/duws/shared/includes/action_style.hpp` defines one macro per bucket;
call sites pass a stringtable key and never write markup themselves.

| Bucket | Hex | Priority | Means |
| --- | --- | --- | --- |
| `ACT_PRIMARY_MENU` | `#15ff00` | 100 | Command: directs your forces or your base. Uppercased by the macro |
| `ACT_SECONDARY_MENU` | `#0d9900` | 90 | Services and situational entries — the command hue one tier down |
| `ACT_EQUIP` | `#ff8000` | 80 | Gives or swaps gear |
| `ACT_MOVE` | `#00b7ff` | 70 | Relocates you, or commits a vehicle to a destination |
| `ACT_AID` | `#00b7ff` | 60 | Heals or rearms |
| `ACT_CIVILIAN_INTERACTION` | `#00b7ff` | 50 | Acts on a civilian |
| `ACT_UTIL` | `#00b7ff` | 20 | Local effect only: toggles, readouts, dev tools |
| `ACT_COMMIT` | `#ff1111` | 10 | Spends CP or commits a shared asset; not freely undone |
| *(none)* | plain | 40 | The rescue-pilot set |
| *(none)* | plain | 30 | Hold-to-search entries, identified by icon instead |

**Colour lives in the header, not in `stringtable.xml`.** A value carrying its own `<t>` markup
freezes that markup into every translation — the variants drift apart, one entry once shipping
coloured in German and plain in English — and a listbox row renders the tags literally rather than
applying them. Keys stay plain text so the bucket alone decides appearance.

**Four buckets deliberately share one blue.** Navigational, medical, social and informational
entries read as one ambient family against the loud consequence colours. They stay four named macros
so priority keys off the bucket, and splitting a blue back out later is a one-line header edit.

**`ACT_COMMIT` sits lowest on purpose.** Priority orders the scroll list, and a mis-scrolled spend
costs more than a buried entry does.

**A bare `&`, `<` or `>` in a title breaks the entry.** Titles are wrapped in `<t>` markup, so an
unescaped ampersand ends the structured-text parse and swallows the rest of the entry. Use `/` or a
different word — `Rest / Heal`, `Mission Control`.

**The buckets stop at the scroll wheel.** They once had `ACT_ROW_*` twins for the BASE listbox, which
died with it: a button is already legible as a button, and the five row hues only ever re-encoded a
scroll priority that a fixed column has no use for. The command column still orders itself the way
the scroll list does — management first, the spend last.

## Call-site conventions

**Slot arity is uniform.** `addAction`'s array is positional — `[title, script, arguments, priority,
showWindow, hideOnUse, shortcut, condition, radius, …]`. Every DUWS call passes eight elements, or
nine where `radius` is used (the rescue-pilot set). The `arguments` slot is `[]` when there are none;
a shorter array silently inherits engine defaults, which is how Open Chute went without a condition
and the Mobile HQ entries without a priority.

**One broadcast path.** Actions attached from the server go out as
`remoteExec ["addAction", [0,-2] select isDedicated, <object>]`. The target skips a dedicated server,
which has no interface to draw a scroll menu on. The third argument is the owning object rather than
`true`: an auto-generated JIP id outlives the object it decorates and leaves a queue entry per object
forever, where an object-keyed message is dropped when that object is deleted. That id *is* the
object's netId, so two broadcasts against one object write the same queue key and the later silently
evicts the earlier — a gap only a late joiner ever sees. Give an object all its entries in a single
broadcast where you can: `fnc_ammobox_actions` attaches both the arsenal and the rearm entry for the
airdropped and Mobile HQ boxes, and the Mobile HQ depends on that object-keyed lifetime because
undeploy deletes its box. Suffix the id only where entries genuinely cannot share a call — the FOB's
defences and guards are attached from different files at different times, and the killhouse
terminal's gear is attached after its controls menu.

**A function that is already broadcast must attach locally.** `fnc_FOBactions` and
`fnc_ammobox_actions` run on every machine, so a plain `_obj addAction` inside them produces exactly
one entry per machine. A `remoteExec` inside such a function instead fans out once per machine that
runs it, so an eight-player session gets eight copies of that one entry on every screen — and a
single-player test shows one, because there is only one machine to multiply by.

**Duplicate guards must stay machine-local.** The adders are broadcast to every client and each
client adds its own local action, so a guard written with a public `setVariable` lets the first
client through and locks every other one out permanently.

**A button needs no broadcast at all.** The command column is built per client when the menu opens,
so an entry that became a button stopped needing a broadcast, a JIP id and a duplicate guard along
with it — which is what let the FOB redeploy come out of `fnc_guardsFOB` entirely.

## Menu rows

`fnc_open_action_menu` takes an optional `[r,g,b,a]` float array per row; a row without one renders in
the listbox default. Row labels are plain text — a listbox renders `<t>` markup literally rather than
applying it — so a scroll-entry colour and a row colour cannot share a definition.

| Menu | Row colours |
| --- | --- |
| Killhouse Controls | `[0,1,0,1]` spawn targets, `[1,0,0,1]` spawn enemies, `[1,1,0,1]` cleanup, `[1,0.533,0,1]` exit |
| Vehicle Recycling | None — both rows default |
| Vehicle Customization | None — all four rows default |
| Quick Kits | None — one row per scanned loadout, all default |
| Debug and its pages | One meaning per colour (`debug_menu.hpp`): `[1,1,1,1]` opens a page, `[1,0.667,0,1]` acts, `[0,1,1,1]` asks for a map click, `[0.082,1,0,1]` / `[0.6,0.6,0.6,1]` a toggle that is on / off, `[1,0.4,0.4,1]` clears or deletes |

The command column is not a menu in this sense: it is seven fixed buttons in the request dialog
itself (`request_menu.hpp`, idc 1610-1616), written from the top down by `fnc_command_fill` and run
by `fnc_command_select`. The entry's CODE rides in `uiNamespace`, because a control's action is a
string, and entries that do not apply are hidden rather than greyed so the column never shows a gap.

It differs from the reusable menu on closing. Only an entry that opens a dialog of its own brings the
request menu down — Squad Manager, FOB Manager and Special Operatives — because those would stack on
top of it. The rest spend, hint and leave the menu standing, so buying two things in a row does not
mean walking back to the prop between them. Entries that cost are drawn in the same orange the
supports catalogue paints an unbought permanent with: the label carries the figure, but nothing else
carried the fact that clicking spends it.

Quick Kits is the only player menu whose row count is not fixed: the rows come from the loadout list the
server scans and broadcasts, and the entry refuses to open when that list is empty. Debug rows are
deliberately unlocalised English — a dev surface no player reads.

Debug is the one menu that opens other menus. Its root lists pages, every other page's first row is
*< Back*, and a label ends ` >` on a page, `(click map)` on a map pick and `[on]` / `[off]` on a
toggle. The object under the cursor is read once, when the root opens, because a row runs with the
dialog down and the pointer gone. The Economy row opens a hand-built dialog rather than one of these
lists, because it pairs an edit box with the buttons that spend it.

## Vendored module entries

Not DUWS-authored, but they share the same scroll menu, the same priority space, and the same `<t>`
markup. DUWS bands from 10 to 100, and no vendored entry rises above that floor — R3F's release entry
ties `ACT_COMMIT` at 10 and everything else sits under it.

| Module | Entries | Source and formatting |
| --- | --- | --- |
| AIS | First Aid/Revive, Stabilize, Drag, Carry, Release, Unload Injured, Load Injured | `src/modules/AIS/System/fn_postinit.sqf`, added through `AIS_Core_fnc_addAction` at a fixed priority of 1.5. Titles are hardcoded English and restyled through `setUserActionText` with `#E9FDF7` text plus a per-action `<img>` icon — the only entries in the scroll menu that carry an inline image |
| R3F Logistics | Object move/rotate/align entries and the config-tool dump actions | `src/modules/R3F_LOG/objet_deplacable/deplacer.sqf:166-171`, priority 10 on release and 6 on the rest, coloured `#ee0000` and `#00eeff` |
| TAW View Distance | View-distance menu | `src/modules/taw_vd/fn_openMenu.sqf`, reached through the CfgFunctions include in `src/description.ext` |
