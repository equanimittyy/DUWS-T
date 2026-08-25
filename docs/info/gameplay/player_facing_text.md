# Player-facing text and actions

Everything the player reads lives in `src/stringtable.xml`, grouped into `<Container>` blocks by
subsystem. Keys are `STR_DUWS_T_*` (a handful of newer ones use a bare `STR_DUWS_*` prefix);
lookups are case-insensitive, so a `localize` that differs in case from the `Key ID` still
resolves. The second half of this doc covers the mechanisms and call-site conventions that produce scroll-menu
entries, which carry much of it.

## English is the source of truth

Every key carries both `<Original>` and `<English>`, and Arma falls back to `<Original>` when the
active language has no tag. **Edit the two in lockstep** — changing only `<English>` leaves the old
wording live for anyone whose game language isn't listed on that key.

## The localised tags lag English on purpose

The `<German>`, `<Spanish>` and `<Chinesesimp>` tags were translated from the pre-rework text and
have not been carried through the English prose passes. They still hold the retired callsigns
(`Action Squad`, `Overlord 1-1`, `Viper 1-5`), the old unnamed-department phrasing for Allseer, and pre-rework
briefings whose timings and reward tags no longer match the English.

This is known divergence, not corruption: **do not treat a German/Spanish/Chinese tag that
disagrees with `<English>` as a bug, and do not machine-translate the gap closed.** Retranslation is
a pass of its own, because the briefings encode gameplay numbers a translator has to check against
the mission code rather than against the old text.

## Player callsign substitution

The squad callsign is host-settable (`duws_callsign`, default `Alpha 1-1`). `fnc_cs` rewrites the
literal string `Alpha 1-1` at display time, so **any key whose text contains `Alpha 1-1` must be
localised through `([localize "STR_..."] call fnc_cs)`** — a bare `localize` prints the default
callsign no matter what the host chose. Fixed callsigns (`Overlord`, `Allseer`, `Dispatch`) are
never wrapped. Substitution matches the English literal only, which is a second reason the localised
tags cannot simply be aligned key-for-key.

## Register: how the prose sounds

The prose is a professional military voice: flat declaratives in the present tense, procedure verbs
(*locate, eliminate, displace, be advised, stand by, roger, over, out*), and no theatrics. It does
not shout — no exclamation marks, no words shouted mid-sentence (`Targeting FAILED`) — and it does
not narrate the software. The `Support & Radio` container is the reference for radio framing:
speaker-first callsign (`Alpha 1-1, this is Overlord.` / `Swordfish 1-1 to Alpha 1-1, ...`), and a
team broadcast opening on the address (`All units, ...`). Numbers are spelled out in spoken lines and
written as numerals in HUD text.

**A kill is confirmed in service vocabulary, not shooter-game idiom.** A result reads *eliminated*,
*neutralised*, *confirmed KIA*, *confirmed kill*, *disposed of* — never *take him down*, *tango
down*, or *he's down*. The verb is varied across the elimination missions so four near-identical
confirmations do not read as one template.

**Name the concrete nouns the player plans against** — the place, the clock, the vehicle — rather
than gesturing at them. The informant brief is the worked example: *All units, an enemy informant is
operating out of %1. Locate and eliminate him before he reaches %2 by vehicle. He is set to leave at
%3 in a %4, and will displace early if a firefight breaks out.* — %1 the town, %2 the named escape
zone, %3 the leave clock, %4 the vehicle class. The pass that produced it turned "slipped out of the
area" into "has reached {zone}": a named place the player reads off the map beats an abstraction, and
the fail line names where he got to.

The three spec-based elimination briefs (armour, HVT, snipers) name the place in code rather than in
the string: `fnc_mission_run` finds the nearest named settlement to the objective marker
(`nearestLocations`, a 5 km ring, a grid reference as fallback) and folds it into the brief's `%1`,
so *marked near %1* prints *marked near Agglelesh*. The DUWS zone the objective sits in is not named
— the settlement alone locates it.

**No em-dashes in player prose.** A parenthetical goes in commas, not dashes — the same brief once
read *leave at %1 — or sooner if shots are fired — in a %2* and now reads *at %2, or sooner if shots
are fired, in a %3*. A transmission is punctuated in clipped clauses, not literary asides. The rule
is applied as each subsystem's text is reworked, not swept across the file at once, so older strings
still carry the dash: standing prose debt, the same kind as the lagging localised tags and the seven
off-voice side-mission hints below, not a bug to fix in passing.

**Who is speaking sets the register, not only the words.** The command net (Overlord, Allseer) is
clipped and procedural and names the player's callsign on a result (*To Alpha 1-1, the informant
has been disposed of. Good work.*). A civilian answering in the world speaks in character and imprecisely: the informant
ask-reveal gives a live bearing and range while he is in town (*about %1 m %2 of you*) but, once he
has driven off, only a bystander's guess (*Him? I think I just saw him leave town heading %1*) — the
system knows where he is; a local only saw which way he went. The hint box has no persona at all
([§Hint prose is system prose](#hint-prose-is-system-prose)), and dialogue always has one
([§Dialogue: the voiced surface](#dialogue-the-voiced-surface)).

**Terminal punctuation is decided by the surface, not by the sentence.** Prose surfaces are
punctuated as prose; the two surfaces that exist to be glanced at are kept bare.

| Surface | Terminal period | Because |
|---|---|---|
| Hint box | **yes** | it is prose the player reads, and it wraps |
| Dialogue and subtitles | **yes** | spoken lines, punctuated as speech |
| Mission descriptions, briefings, task text | **yes** | prose, read at length |
| A3 notification card | **no** | a headline, kept clean |
| Map marker text | **no** | a label on the map, kept free of clutter |

Sentence breaks *inside* a string are untouched by this — only the final one goes. A card reads
`Last Mobile HQ destroyed. Name another in %1 min`, keeping the break and dropping the tail.

A label takes no period on any surface, because it is not a sentence: a side-mission name
(`Clear Area`), a menu heading (`Mission Selector`), a card's title field, and a line ending on a
substituted value (`Squad renamed to:` + the name).

## Which surface a message goes to, and never both

Three surfaces put text on screen. **Dialogue** is the voiced channel — a persona (Overlord, Allseer,
a support callsign, a civilian) speaking over the radio or in the room, through `fnc_duws_dialogue`;
it is chosen whenever a line has someone to say it, and its mechanics are in
[§Dialogue: the voiced surface](#dialogue-the-voiced-surface). The other two are the system's own
voice, with no persona, and they are not interchangeable with each other. **A system message uses one
of them.**

| Surface | Command | Use it for | Length |
|---|---|---|---|
| Hint box | `hint` | a gameplay directive or a refusal answering one player — an instruction to act on, a price, a gate — anything with no speaker | wraps, no limit |
| Notification card | `BIS_fnc_showNotification` | the important case: a change of state the whole team is told about | 60 characters, clipped |

**Prefer the radio over the hint box.** A line a callsign would plausibly speak — a fire mission
called, a transport inbound or on station, an aircraft shot down, a drop delivered, a fire mission
complete — is voiced on the net through `fnc_duws_dialogue` (SUB-NET for a support callsign, NET for
Overlord), not printed as a hint. The hint box is not the default surface for status: it is reserved
for **gameplay directives** — the things the player reads in order to act, such as designating with
the laser, clicking the map to set a route, picking a valid lift target, keeping clear of enemy
ground, or the access key for a called-in element — together with the refusals, prices and gate
messages the request menu answers with, which have no speaker and no place on the radio. Decide by
whether the message is something to act on (hint) or something that happened and someone could say
(radio).

A notification card is for news: something the campaign did that every player has to know, whether or
not they were the one who triggered it. Reach for it when the audience is the team; if the audience is
one player, it is a hint or a radio line by the rule above.

**Never fire the same event on two surfaces.** One sentence in two boxes reads as two things
happening, and a hint doubling a voiced radio line, or a card doubling a hint, buys nothing — the
card clips at 60 characters where the hint had no limit, and the radio already said it. An event
picks one surface.

**One exception stands, and it is the economy.** `CPaddedattrition`
(`server/server_init.sqf`) pays kill income to each player individually and tells each of them
alone, so by audience it is a hint — but CP arriving is what the card vocabulary already means,
through `cpaddedmission` and `apaddedmission`, and kill income is the one income that would look
different. It also fires on the economy tick rather than on an action, so it is neither frequent
enough to read as noise nor small enough to want burying. The call site carries the same note.

The card's ceiling is a hard one and it clips mid-sentence with no error, which is a trap of its own
([`arma_engine_gotchas.md`](../architecture/arma_engine_gotchas.md#a-cfgnotifications-description-is-clipped-not-wrapped-past-roughly-60-characters)).
That budget is a reason to keep a card's text to a headline rather than a reason to split a long one
across both surfaces.

## The notification card catalogue

Cards are styled by their `CfgNotifications` class in
[`shared/includes/notifications.hpp`](../../../src/duws/shared/includes/notifications.hpp), named as the
first element of the `BIS_fnc_showNotification` argument. The class decides colour, icon and
duration; the call site supplies only the text. Every class runs `duration = 4`.

**Two shapes.** Most classes are an icon card: a picture on the left, `description = "%1"` filled by
the call site. The economy family is a badge card instead — no picture, `iconText = "+%1"` drawing
the figure over the icon slot, and a fixed description on the class rather than one passed in. That
is why a CP award call passes a bare number where every other call passes a sentence.

**Colour carries meaning**, and the four in service are consistent:

| Colour | Means | Classes |
|---|---|---|
| white `{1,1,1,1}` | neutral information | `info`, `missionclean`, `sitrepinfo`, `arsenal`, the `unlock_*` family |
| blue `{0.2,0.5,1,1}` | something gained | `US_takencontrol`, `repup`, `infosearch` |
| red `{1,0.2,0.2,1}` | something lost, or a critical failure the player must act on | `alert`, `US_lostcontrol`, `repdown`, `biohazard`, `critical` |
| cyan `{0.5,1,1,1}` | economy | the `CPadded*` / `APaddedmission` badge family |

Gain and loss are the two sides' own colours, taken from the pair the setup screen already paints
its faction rows with — `[.2,.5,1,1]` for BLUFOR against `[1,.2,.2,1]` for OPFOR
(`client/dialog/fnc_HQ_faction_dialog.sqf`). A card saying *you took this* wears blue and one saying
*you lost this* wears red, and the player has met both before the campaign starts. Arma's own
`ColorBLUFOR` and `ColorOPFOR` are the wrong values for it: those are mixed for map markers on a
light background and read as muddy text on the card's black one.

**A card's direction is the class, not the wording.** Every loss now has a red class to go to:
`alert` for a thing destroyed or a war getting worse, `repdown` beside `repup` for reputation.
`alert` is the old `info2`, which was white and carried one card -- a FOB being destroyed, reported
in the same colour as a repair station opening.

**Red carries a second sense beyond loss: the critical failure.** `critical` is the exception to
white-is-information -- the campaign-defeat card and the enemy-contact card go red not because
something is gone but because the player has to act, and neither can be allowed to read as neutral
chatter scrolling past. The campaign card branches on the outcome: a win keeps white `info`, a defeat
takes `critical`. The enemy-contact card is one call site (`fnc_enemy_contact`) raised from the HQ,
every held zone and every FOB alike -- the FOB warning was a subtitle line before and now matches the
HQ's card and map mark.

**A class that carries more than one event takes its title from the call site.** `alert` held a
fixed `$STR_DUWS_T_gwn85uxh` title while serving four of them, so a destroyed MHQ, a dead informant
and a rise in escalation all announced themselves as `FOB Lost`. A class whose `title` is anything
but `"%1"` may carry exactly one event.

**The catalogue — 22 classes in service, plus the `SupportUnlock` base the unlock family inherits
from, which is never fired itself:**

| Class | Colour | Sites | Carries |
|---|---|---|---|
| `info` | white | 12 | the general-purpose card; MHQ, FOB, hire, black market, supports; the campaign-victory card |
| `arsenal` | white | 5 | the captured-materiel reward at a side-mission objective -- its advertisement and its seized confirmation |
| `biohazard` | red | 4 | RAVAGE / WBK zombie-mode announcements |
| `missionclean` | white | 2 | the side-mission cleanup countdown |
| `repup` | blue | 3 | reputation gained |
| `alert` | red | 4 | MHQ or FOB destroyed, informant killed, escalation risen |
| `critical` | red | 2 | the campaign-defeat card, and the enemy-contact card (HQ, FOBs, held zones) |
| `repdown` | red | 1 | reputation lost |
| `sitrepinfo` | white | 2 | the SITREP support |
| `US_takencontrol` | blue | 2 | zone captured |
| `US_lostcontrol` | red | 1 | zone lost |
| `infosearch` | blue | 1 | a search that revealed something |
| `unlock_armory` · `unlock_halo` · `unlock_mobile_HQ` · `unlock_fob` · `unlock_repair` · `unlock_recycle` | white | 1 each | the six permanent support unlocks |
| `CPadded` · `CPaddedmission` · `CPaddedattrition` · `APaddedmission` | cyan | 1 each | zone, mission, kill income, mission AP |

**A support unlock is white**, all six of them. Blue is reserved for ground and standing taken off
the enemy — a zone, a reputation, a search that paid — and a purchase the player made at their own
base is not that. The family earns a class per facility only for the icon: `info`'s warning triangle
over an unlock reads as the opposite of what it announces.

The two rep cards wear the handshake `meet_ca.paa` rather than a flare, because reputation is the
one figure the player moves by dealing with people rather than by shooting.

**One anomaly.** `fnc_BluHQinit.sqf` fires `TaskFailed`, which is Arma's own class rather than one of
these, so that single card is styled by the engine. And five call sites name their class in
lowercase (`cpadded`, `us_takencontrol`, `us_lostcontrol`, `cpaddedmission`, `apaddedmission`)
against a CamelCase definition — config lookup is case-insensitive, which is why the drift went
unnoticed.

## A permanent unlock is one card, the same card, to the whole team

The six permanent unlocks — the VA Arsenal, HALO Jump, Mobile HQ, FOBs, and the recycling and
vehicle modification stations — share one shape: a fixed `Permanent Support Unlocked` title, the
facility's own icon, and `BLUFOR has unlocked the Vehicle Recycling Station` as the description.
Nothing is passed in, so no call site can drift from the shape; `SupportUnlock` holds the parts
they share and each class supplies only its icon and its sentence
(`shared/includes/notifications.hpp`).

**It fires from `server/supports/fnc_support_perm_grant.sqf`, not from the purchase.** A permanent
row is bought once for the whole team, and that function is the one place that runs exactly once
per unlock — two players reaching the same row in the same frame are charged once and announce
once. Announcing from the buyer's own `fnc_support_buy` reached only the buyer for three of the six
and raced for all of them.

The description never carries the menu row's label, which is where the price lives: a card reading
`Vehicle Modification Station (5 CP)` prices something the player has already paid for. Nor does it
explain the facility (`Scrap vehicles on the pad at the Recycling Station`) — that is the one thing
a four-second card cannot teach, and the scroll action on the object already says it.

A row that grants a comm item raises the engine's own card as well, naming the radio entry the
buyer now holds. That is a second message only in appearance: the engine's card is per-player and
says *you are carrying this*, where the unlock card is the team's news.

## Hint prose is system prose

A hint reports state. It does not narrate the software (`The system is finding…`, `Please wait…`),
it does not exclaim, and it does not speak — callsign framing and procedure words belong to
`fnc_duws_dialogue` and the subtitle line, never to the hint box. A support that cannot fly says
`Heavy transport could not reach your position`, not `Mule 1-1 failed to reach your position`.

**Six side-mission hints are knowingly in the wrong voice** and are left that way. They narrate
rather than report, and the revision that rewrites the side missions owns them — fixing the prose
piecemeal now would be re-editing text that is about to be replaced wholesale:

| Key | Text |
|---|---|
| `STR_DUWS_T_fxyys123` | The pilot's fading fast. Two minutes, maybe less. |
| `STR_DUWS_T_fxysw123` | …The pilot stopped answering the radio. He's most likely bled out. |
| `STR_DUWS_T_towerdecrypt` | They're nearly through the intel. Two minutes left. |
| `STR_DUWS_T_fxkczy00` | The enemy rigged the truck with a timed charge and there's no disarming it in the field… |
| `STR_DUWS_T_3jmpthvi` | Unloading complete. The truck's yours. |
| `STR_DUWS_T_auto_drop_hint` | You were already carrying the pilot, so he's been set down here. |

They are listed here rather than commented beside their keys because `stringtable.xml` carries no
XML comments today, and this is not the change that should find out whether the parser accepts them.

## Dialogue: the voiced surface

`fnc_duws_dialogue` is the only path that gives a line a *speaker*. Everything else on screen is the
system talking; this is a persona — Overlord and Allseer on the command net, a support callsign, an
intro or downed pilot in the room, a civilian answering a question. The call is
`[_speaker, _text, _channel]` with both strings already `localize`d and `_channel` normally `""`,
which lets the speaker decide the channel.

**A dialogue voice is a real element in the fiction, not a callsign invented to carry a line.**
Overlord and Allseer on the net, a support callsign the player called, an intro or downed pilot, a
civilian in the world — each is demonstrably on the net or in the room when its line plays. A one-off
callsign wired to nothing the player can see or call is not a voice: a brief and its result come from
an established element, not from a name minted for the occasion.

**Callsign substitution is automatic here.** The body runs `fnc_cs` on the speaker and the text
itself, so a dialogue call site passes the raw `localize`d keys and does **not** wrap them — unlike a
hint, card or task, which has no such step and must wrap any `Alpha 1-1` string at the call site
([§Player callsign substitution](#player-callsign-substitution)). Only the speaker label takes the
senior's name (`Alpha 1-1 (steph)`); the text does not, because the callsign also appears mid-line,
where `Alpha 1-1 (steph), move out` would read as part of the sentence.

**Three channels, and the speaker picks by default.** `fnc_duws_dialogue_channel` routes to NET,
VOICE, or SUB-NET off two explicit lists in `fnc_duws_dialogue`. **NET** is the prominent command net
— Overlord alone — on the subtitle with a squelch tone, because its briefs and results are the lines
the player least wants to miss. **SUB-NET** is every other radio callsign (Allseer, the supports, the
air drops, the rescued squad): it renders to a bottom-left radio log — its own structured-text overlay
(`fnc_duws_subnet_log`, RscTitles `DUWS_SubnetLog`), not the engine's `systemChat`, because that
cannot tint a speaker — with the speaker coloured by faction (blue BLUFOR, red enemy, so the disguise
ruse reads hostile at a glance). Squelched like any transmission but persistent, so radio chatter is
present without burying an in-room line or an Overlord brief. `fnc_duws_subnet_render` redraws the
overlay on a tick, fading each line over its ten-second life (older lines progressively more
transparent) and dropping it when spent, so the box thins out during a lull rather than sitting
frozen.
**VOICE** is everyone in the room with the player, on the subtitle, and is the default: **a new
speaker on no list lands on VOICE**, the loud visible surface, rather than on the chat box. The
player callsign is on no list, because you do not hear your own key-up.

**One subtitle slot, VOICE first.** The engine subtitle is a single line; a second replaces the first
mid-read, so `fnc_duws_dialogue_drain` holds one line at a time — and only NET and VOICE reach it,
since SUB-NET prints to the radio log, which stacks and needs no slot. SUB-NET has no drain, but a
shared cursor in `fnc_duws_dialogue` spaces *bunched* lines a couple of seconds apart, so two threads
keying up in the same beat do not dump at once and read as garbled cross-talk; an exchange that
already sleeps between its own lines prints with no added delay. VOICE drains first and
entirely — it answers something the player just did, and waiting behind an Overlord brief reads as a
dropped button press — and never expires. NET is dropped once it has waited over 8 s, because an
Overlord line queued behind a long in-room exchange reads worse late than silent. Two lines in the
same frame are ordinary, so nothing at the call site serialises them.

**Address the hearers; never re-broadcast.** Every call site reaches the function through
`remoteExec`: `0` for the whole team (a mission brief), a single client for a one-player answer (the
ask-reveal goes only to `_caller`). The body then runs on each machine already addressed and must not
broadcast again, or N clients each send to N. Like every client-called support, the function is
`publicVariable`'d in `server_fnc_init`, and the speaker tables build lazily on first use because a
JIP client can be handed a line before its own init has run.

**A result with a persona to voice it goes to dialogue, not a hint.** The informant win is Overlord's
line; the fail, which has no one to say it, is a plain hint. The support callouts are the same call —
inbound, on station, shot down, drop delivered, fire mission complete each have a callsign to speak
them, so they belong on the net, not in the hint box, which is left for the directive the player acts
on. Pick by whether someone is there to speak — but do not double a voiced line with a hint that
repeats it.

## Side-mission briefings carry their own reward block

One key per side mission serves both the strategic-map card and the task description, so the same
text has to read as a briefing in either place. It opens with the mission's category on its own
line, then situation, task, and any timer or kit the player has to plan around. It ends with the
reward, laid out on its own lines after a blank one:

```
Mission Type: Sabotage&lt;br /&gt;
… &lt;br /&gt;&lt;br /&gt;CP: 45&lt;br /&gt;AP: 15
```

The category is one word, named for the action the mission asks for rather than for what it is
about. It is what the player sorts on when picking work off the strategic map, so it tracks the
*task* and not the thread's name — "Destroy armour" asks for the tank commander's death, which
makes it `Elimination` rather than a destruction category.

| Category | Asks the player to | Threads |
|---|---|---|
| `Elimination` | kill enemy personnel or vehicles | HVT, snipers, armour, CQB, domination |
| `Sabotage` | destroy enemy equipment or installations | tower, cache, radar, laptop |
| `Requisition` | take materiel off the enemy and move it | supply truck, engineering vehicle, IDAP truck, intel |
| `Defence` | keep something alive until a timer runs out | hold position, protect civilian |
| `Rescue` | bring friendly personnel out | squad, pilot |

The set is deliberately coarse. Destruction splits only on whether the target breathes, so
`Elimination` and `Sabotage` between them cover most of the board; `Defence` covers both the
static-asset hold and the bodyguard job, which differ in what ends them but not in how they play.

Breaks are `<br />` (XML-escaped in the file, as above), never `\n` — a task description is parsed
as structured text, where a bare newline is whitespace. The numbers are the base rewards the thread
passes to `fnc_mission_reward`; `cp_reward_multiplier` scales the CP actually paid but not the
figure printed here, so a campaign run above 1x pays more than the card says. The two missions that
pay town reputation instead of army power carry a third `REP:` line, because `AP: 0` on its own
would read as unpaid work.

## Unreferenced keys

A key can be deleted only once nothing references it. No call site builds a key name dynamically
(no `format ["STR_DUWS_T_%1", ...]`), so a plain text scan over `src/` is authoritative for
liveness — which is what makes bulk pruning safe to reason about.

## Three mechanisms produce a scroll entry

| Mechanism | Produces | Used for |
| --- | --- | --- |
| `addAction` | An instant scroll entry | Almost everything |
| `BIS_fnc_holdActionAdd` | A hold-to-complete entry with an icon and progress ring | Searching bodies and containers, the disguise panel |
| `fnc_open_action_menu` | A dialog listbox opened *by* one scroll entry | Collapsing a cluster of related entries into a single scroll row |

`src/duws/client/dialog/fnc_open_action_menu.sqf` is the escape hatch from scroll-menu sprawl:
Black Market, Vehicle Recycling, Vehicle Customization, Killhouse Controls, Quick Kits and the debug
menu each occupy one scroll row and expand into a list. Rows in that listbox are *not* action-menu
entries.

The request menu's COMMAND AND CONTROL column is the same idea one level up: everything a player has
to ask command for is a button in the dialog Requests already opens, so the HQ structure carries one
scroll entry instead of the twelve it once did. The dividing line is **who needs it and how fast** —
an arsenal, a HALO jump, quick kits, an AI rearm, the killhouse teleports and the black market stay
on the scroll wheel and on the prop they belong to, because a player reaches for those without asking
anyone. Squad and FOB management, operative recruitment, intel analysis, the redeploy and the two
hires are buttons, built by `fnc_command_fill` in that order: what costs nothing above what does,
and the analysis directly under the operatives whose take it converts.

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
| Black Market | `[0,1,0,1]` on all three purchases |
| Killhouse Controls | `[0,1,0,1]` spawn targets, `[1,0,0,1]` spawn enemies, `[1,1,0,1]` cleanup, `[1,0.533,0,1]` exit |
| Vehicle Recycling | None — both rows default |
| Vehicle Customization | None — all four rows default |
| Quick Kits | None — one row per scanned loadout, all default |
| Debug | `[1,0.667,0,1]` on the six working tools, `[0.6,0.6,0.6,1]` on the unimplemented WARCOM row |
| Flag *(object)* as searchable, Force side mission | `[1,0.667,0,1]` on every row |

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

Quick Kits is the only menu whose row count is not fixed: the rows come from the loadout list the
server scans and broadcasts, and the entry refuses to open when that list is empty. Debug rows are
deliberately unlocalised English — a dev surface no player reads.

Both menus in the last row open from a Debug row rather than from a scroll entry, and are the one
place a menu opens another menu. The economy tool sitting between them in Debug is a hand-built
dialog rather than one of these lists, because it pairs an edit box with the buttons that spend it.

## Vendored module entries

Not DUWS-authored, but they share the same scroll menu, the same priority space, and the same `<t>`
markup. DUWS bands from 10 to 100, and no vendored entry rises above that floor — R3F's release entry
ties `ACT_COMMIT` at 10 and everything else sits under it.

| Module | Entries | Source and formatting |
| --- | --- | --- |
| AIS | First Aid/Revive, Stabilize, Drag, Carry, Release, Unload Injured, Load Injured | `src/modules/AIS/System/fn_postinit.sqf`, added through `AIS_Core_fnc_addAction` at a fixed priority of 1.5. Titles are hardcoded English and restyled through `setUserActionText` with `#E9FDF7` text plus a per-action `<img>` icon — the only entries in the scroll menu that carry an inline image |
| R3F Logistics | Object move/rotate/align entries and the config-tool dump actions | `src/modules/R3F_LOG/objet_deplacable/deplacer.sqf:166-171`, priority 10 on release and 6 on the rest, coloured `#ee0000` and `#00eeff` |
| TAW View Distance | View-distance menu | `src/modules/taw_vd/fn_openMenu.sqf`, reached through the CfgFunctions include in `src/description.ext` |
