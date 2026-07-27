# Dialogue routing and subtitle system: implementation plan

Two changes behind one entry point:

1. **Route** every spoken line to a surface chosen by *who is speaking*, not by which file
   the line happens to live in. Today the same character reaches the player through three
   different surfaces depending on the script that raised the line.
2. **Replace** `BIS_fnc_showSubtitle` with a renderer that does not let a reply wipe the
   line it answers.

The two are one change because the router is the wrapper: 274 call sites already pass
`[speaker, text]` — speaker first, which is exactly what a router keyed on speaker needs —
so the mechanical half of both halves is a single name swap.

## Categories

Three surfaces, named so a new line has an obvious home.

| Category | Surface | Squelch | Rule |
|---|---|---|---|
| **VOICE** | Large bottom-centre subtitle | No | An exchange the player is *a party to* |
| **NET** | Native Arma chat, upper left | Yes | Radio traffic the player *listens in on* |
| **SYSTEM** | Notification / hint / OSD | n/a | Nobody is speaking |

The VOICE/NET line is drawn by participation, not by whether a radio is involved. Overlord
is on the radio and is VOICE, because Overlord is talking *to* the player; Slingshot 1-1 is
also on the radio and is NET, because the player called for fire and is now listening to a
gun line work. Intercepted OPFOR traffic is NET for the same reason, one step further
removed. That rule decides new lines without anyone consulting a roster.

SYSTEM is named only so it stops being mixed into the other two. It is out of scope here
and does not change.

### Speaker roster

Every `_speaker*` assignment in `src/duws` is `localize "STR_DUWS_T_*"` — no computed or
literal speaker names exist — so the roster is closed and the routing table is complete.

| Key | English | Subtitle sites | Category |
|---|---|---|---|
| `STR_DUWS_T_OVERLORD` | Overlord | 108 (+1 lowercase) | VOICE |
| `STR_DUWS_T_actionteam` | Alpha 1-1 → `duws_callsign` | 73 | VOICE |
| `STR_DUWS_T_civ` | Civilian | 32 | VOICE |
| `STR_DUWS_T_infomat` | informant | 4 | VOICE |
| `STR_DUWS_T_survivor` | Survivor | 3 | VOICE |
| `STR_DUWS_T_IDAP` | IDAP staff | 2 | VOICE |
| `STR_DUWS_T_pilot` | Pilot | 18 | **split four ways, see below** |
| `STR_DUWS_T_allseer` / `_Scout` | Allseer 1-1 | 5 + 1 | NET |
| `STR_DUWS_T_Express` | Express 2-1 | 4 | NET |
| `STR_DUWS_T_Viper` | Viper 1-5 | 3 | NET |
| `STR_DUWS_T_Rein` | Delta 3-2 | 2 | NET |
| `STR_DUWS_T_koipilot` | Koi 1-1 | 2 | NET |
| `STR_DUWS_T_changgongpilot` | Longbow 1-1 | 2 | NET |
| `STR_DUWS_T_slingshot` | Slingshot 1-1 | 1 | NET |
| `STR_DUWS_T_Cobra` | Cobra 1-3 | 1 | NET |
| `STR_DUWS_T_hound` | Hound 2-2 | 1 | NET |
| `STR_DUWS_T_Signal` | Signal 3-1 | 1 | NET |
| `STR_DUWS_T_Signal2` | Signal 2-2 | 1 | NET |
| `STR_DUWS_T_DISGUISE_OPFOR_SPEAKER` | OPFOR | 2 | NET |
| *(none — Swordfish 1-1)* | — | 2 side-chat sites | NET |

`STR_DUWS_T_pilot` is one key covering three different characters. "Pilot" is the right name
for exactly two of them — the people the player meets rather than calls:

| Where | Who | Speaker | Category |
|---|---|---|---|
| `server/misc/fnc_intro_heli.sqf:125,155` | The insertion pilot, in the cabin with the player | `_pilot_intro` → "Pilot" | VOICE |
| `rescue_pilot/fnc_rescue_pilot_mission.sqf:575,605` | The downed pilot being carried out — *"My leg's in bad shape"* | `_pilot_downed` → "Pilot" | VOICE |

Both rescue_pilot sites read one `_speaker1` assigned at `:414`, so the key change lands
there once and the two call sites are untouched.

The other 14 sites are aircraft the player requested, and they answer under a callsign like
every other support. Two of those callsigns already exist in the source and are simply not
reaching the speaker slot:

| Support | Sites | Callsign | Status |
|---|---|---|---|
| Heli taxi | `fnc_helotaxi` 5 | Chariot 1-1 | Hardcoded at `fnc_helotaxi.sqf:12` as `_taxiName`, used only inside message bodies |
| Artillery, mortar, JDAM, laser, cluster, napalm | `fnc_arty` 4 `globalChat` replies | Slingshot 1-1 | `STR_DUWS_T_slingshot` exists **and** a duplicate literal at `fnc_arty.sqf:49` |
| Heli lift | `fnc_helolift` 4, `fnc_helolift_ropes` 1 | Crane 1-1 | New key |
| Air drops — paradrop, ammobox, SAWP, SIVA | 1 each | Stork 1-1 | New key, shared by all four |

Crane and Stork are proposals, not requirements — they are stringtable values and cost
nothing to rename. One callsign across the four drop supports rather than four is deliberate:
the player learns a short roster (your ride, your guns, your lift, your resupply), and four
near-identical delivery callsigns is noise, not texture.

**This keeps the routing invariant intact.** The router depends on every speaker being a
`localize` of a stringtable key; promoting `_taxiName` from a hardcoded SQF literal to a key
preserves that, and fixes a localisation hole on the way — "Chariot" and "Slingshot" are
currently English in every language.

**It also deletes code.** Those callsigns reach the player today by being `format`-ed into
message bodies as `%1 %2-%3` — sender, then two digits pinned to 1. Once the speaker slot
carries the callsign, the strip-the-sender rule of the stringtable pass removes those
placeholders, and `_taxiName`, `_random1` and `_random2` are left orphaned in `fnc_arty` and
`fnc_helotaxi`. They go with them. Note the helotaxi trio is threaded through a `params` into
a spawned abort handler (`fnc_helotaxi.sqf:99,119,176,223,238,266`), so that removal is a
small unpick rather than a one-line delete.

### Where native chat draws

Upper left, where the mission already puts its side-chat lines. The player can move the Chat
element in Options → Game → Layout; the mission cannot, and does not try to. Drawing NET
anywhere else means writing a second custom renderer, at which point nothing about it is
native — and the bottom-right corner is in any case taken by
`client/misc/fnc_bottom_right_message.sqf`, the location/date OSD.

## Why the split does not remove the need for a new renderer

The complaint driving the original plan is behavioural: a new subtitle clobbers the
previous one the instant it appears, so a two-line exchange cannot be read. It is tempting
to assume that moving radio traffic to a scrolling chat box fixes that. It does not.

Of the 274 subtitle sites, **40 move to NET and 234 stay on VOICE** — 15%. The dense
back-and-forth that actually gets clobbered is Overlord ↔ Alpha 1-1 ↔ civilian, and every
one of those stays on the large subtitle by the rule above. The channel split fixes
*attribution*; it does not fix *legibility*.

What it does change is the shape of the fix. With the net traffic gone, the subtitle stream
is a conversation between at most two people, so the renderer needs to hold **two lines**,
not a four-line feed. See [§Two lines, not four](#decided-trade-offs).

## Inconsistencies to fix

### One character, three surfaces

| Problem | Where |
|---|---|
| Overlord speaks through `BIS_fnc_showSubtitle` (108 sites), through `fnc_sideChat_filter` → `sideChat` (15 sites), and through `player globalChat` — where the sender name shown is the *player's* unit, not Overlord, and only that one client sees it | `client/misc/fnc_found_intel.sqf:8,15,21` puts three Overlord lines on two surfaces in a 23-line file |
| `fnc_sideChat_filter` hardcodes the untranslated literal `"OVERLORD"` as the sender for *every* line it carries | `shared/functions/fnc_sideChat_filter.sqf:18` |
| …so lines that are not Overlord are attributed to Overlord: `boattaxi_notaboard` and `boattaxi_rtb` are Swordfish 1-1, and `cp9cw550` ("Requesting a FOB on my position") is the player | `client/supports/taxi/fnc_boatTaxi.sqf:75,130`, `client/supports/fnc_request_fob.sqf:28` |
| The no-radio fallback is *louder* than the gated path: with a radio the line goes to the side channel, without one it goes to `globalChat` — the global channel, which everyone sees regardless of side | `fnc_sideChat_filter.sqf:17-23` |
| One event, two surfaces, two different strings: a side-chat line and an Overlord subtitle fire back to back for the same zone reveal | `server/init_zones/fnc_zone_reveal.sqf:18-19` |
| One event, three surfaces: campaign-won fires a notification, a hint, and a side chat | `server/misc/fnc_capture_zones_task.sqf:56-58` |
| One event, four surfaces: `systemChat`, a hint, the OSD, and an Allseer subtitle | `server/supports/fnc_sitrep_support.sqf:19,22,25,27` |
| The same disguise line is posted twice, to `systemChat` and to the subtitle | `server/misc/fnc_disguiseAsEnemy.sqf:126-127` |
| The six bombing supports show only the player's half of the exchange to the room. The gun line's four replies are on `globalChat`, which is client-local — in co-op nobody but the caller hears the fire mission answered | `client/supports/fnc_arty.sqf:36`, then `:56,58,127,129` |

Setup-phase `globalChat` (`fnc_locatorzones_*`, `fnc_moreUrban_locations`, `fnc_WARCOM_init`,
`fnc_init_OPFOR_WARCOM`) is **not** in scope. Those are SYSTEM progress lines, deliberately
on `globalChat` because `hint` renders beneath the forced-open map. They stay as they are.

### Attribution

| Problem | Where |
|---|---|
| Bodies introduce themselves, so `Speaker: line` renders "Overlord: This is Overlord. …" | `STR_DUWS_T_u18xeu4p`, `_8skllpyx`, `_taskforces_launched`, `_taskforces_launchrqst`, `_opfast`, `_ammospotted`, `_stmeajce`, `_77l9izur`, `_0jegiaf4`, `_hf9bhgvb` |
| The body names a *different* callsign than the speaker slot: "Knight 1-5 to HQ" under speaker "Pilot"; "Swordfish 1-1 to Alpha 1-1" under speaker "OVERLORD" | `STR_DUWS_T_heli_moving`, `STR_DUWS_T_boattaxi_notaboard` |
| `STR_DUWS_T_allseer` and `STR_DUWS_T_Scout` are two keys with one English value, "Allseer 1-1" — but they diverge elsewhere ("Naher Späher" / `"Allseer 1-1"` in German), so collapsing them drops three translations | `stringtable.xml`, Callsigns container |
| Three callsign values carry literal quote marks in their non-English forms — `"全视眼 1-1"`, `"Koi 1-1" Pilot` — which render as `"全视眼 1-1": line` once the name sits in a sender slot | `STR_DUWS_T_allseer`, `_koipilot`, `_changgongpilot` |
| A hardcoded English string with no stringtable key, sent as dialogue | `server/warcom/fnc_WARCOM_gps_marker.sqf:25` — `format["TF Primary Target: %1", …]` |
| Lowercase `STR_DUWS_T_overlord`, which is not a key and resolves only because `localize` is case-insensitive | `client/missions/fnc_stratmap.sqf:12` |
| A real player name in the speaker slot instead of a callsign | `client/misc/fnc_corpse_search_action.sqf:32,55,66,71` |
| A deliberately unattributed line — `["", _message1]` | `destroy_tower/fnc_destroy_tower_mission.sqf:225` |
| A **position array** where the speaker belongs, because the call is built with `format` and interpolates `str(_foundPickupPos)` | `server/supports/fnc_fob_server.sqf:70` |

### Audio

| Problem | Where |
|---|---|
| The squelch fires on face-to-face dialogue: `protect_civ` plays radio chatter for all 9 of its lines, including the informant standing in front of the player. Every other civilian file plays none | `protect_civ/fnc_protect_civ.sqf`, vs `fnc_civ_lootAction.sqf`, `fnc_civ_healAction.sqf`, `fnc_civ_recruitAction.sqf`, `fnc_addAskEnemyAction.sqf` |
| The squelch is placed by hand and the two sets do not line up: 166 `fnc_broadcastRadioChatter` calls against 274 subtitle sites, on no discernible rule | across `src/duws` |
| The squelch is broadcast even when the line it marks is not: all 166 calls target `0`, but 51 subtitle sites target `_caller` and 3 `_player` | across `src/duws` |
| Audio and text are desynchronised: the mutex is held for the full 4-20 s ambient sample, so a second line inside that window gets no squelch while its subtitle still displays | `server/server_fnc_init.sqf:1044-1045,1109` |
| The "replace random talking with a UI sound" change is half-applied — the squelch was added *in front of* the random vanilla `RadioAmbient1..30` sample, not instead of it | `:1047-1052`, then `:1087-1109`, duration table `:1055-1085` |
| `DUWS_Radio_End` is defined and never played — the other half of a squelch pair whose middle section was never removed | `shared/includes/sounds.hpp:31-35` |

## Design

### The router

```sqf
// fnc_duws_dialogue: [_speaker, _text, _channel] — third argument optional
```

First two arguments are unchanged, so every existing site works untouched after the name
swap. `_channel` is `""` by default, meaning *decide from the speaker*.

**The router runs on every machine the call site addressed, not on the caller's.** Every
site reaches it through `remoteExec [..., 0]` (or `_caller`, or `_player`), so by the time
the body executes it is already on the right machines and the fan-out is done. Every surface
it then picks must be a *local* call. This is the single constraint that shapes the NET and
audio paths below, and re-broadcasting from inside the router is the mistake it exists to
prevent: N clients each sending to N clients is N² copies of the line, and it overrides the
per-site targeting that the 54 `_caller`/`_player` sites depend on.

**NET is the explicit list; VOICE is the default.** A speaker the table does not know
renders as a subtitle — visible and wrong — rather than disappearing into a chat box
nobody is looking at. That is the fail-loud direction, and it means adding a callsign later
without touching the table degrades gracefully.

The table is built once per client from stringtable keys, not from literals, so it holds in
every language:

```sqf
DUWS_netSpeakers = ["STR_DUWS_T_allseer", "STR_DUWS_T_Scout", …] apply { localize _x };
```

`allseer` and `Scout` collapsing to one string in English is harmless — both are NET, and in
German and Spanish they do not collapse at all.

**The channel decision is its own function, `fnc_duws_dialogue_channel`.** The router itself
touches `localize`, chat and UI, none of which exist in sqf-vm, so it cannot be unit-tested;
the lookup is a pure function of the speaker and is the one piece of this design the lint
cannot check. `tests/lib/extract_fn.py` pulls a single top-level `NAME = { … }` block out of
real source, so the lookup has to be a separate definition taking the already-localised
speaker to be testable at all. It also carries the blank-speaker and non-string-speaker
cases, which are exactly the branches worth asserting.

### Why the callsign substitution has to move first

`fnc_cs` (`server/server_fnc_init.sqf:222-242`) swaps the literal `"Alpha 1-1"` for the
host-chosen `duws_callsign`. It is currently applied **by the caller**, wrapped around the
speaker at 68 sites: `([localize "STR_DUWS_T_actionteam"] call fnc_cs)`. Those split two
ways, and the second form is the one a `_speaker` grep misses: **24** are assignments
(`_speaker = (…)`, three whitespace spellings) and **44** are written inline as the first
element of the subtitle array.

That breaks the router. If the host renames their team to "Bravo 2-2", the router receives
`"Bravo 2-2"` and can no longer recognise it as the player callsign. Moving `fnc_cs` inside
the wrapper means the router matches on the pre-substitution string and substitutes
afterwards. This is the same reordering the stringtable pass needs, for a different reason —
see below — so it is one task serving both.

Stripping `call fnc_cs` from the 68 speaker slots is a mechanical find-and-replace; the
remaining 74 `fnc_cs` calls — message bodies, hints, notifications, marker text — stay where
they are until the wrapper takes the dialogue half over too.

**The wrapper substitutes both the speaker and the text, and the surviving body wraps
double-apply harmlessly.** `fnc_cs` scans for the literal `"Alpha 1-1"` and replaces it, so
a second pass finds nothing left to match. The one input that breaks that is a host callsign
which itself contains `"Alpha 1-1"` — `"Alpha 1-1 Actual"` would expand twice. Accepting
that beats stripping the body wraps inside a phase whose whole value is being mechanical.

### The VOICE renderer

A client-side queue of at most **two** lines, each with its own expiry, rendered into a new
`RscTitles` class beside `DUWST`. The newer line sits below the older; the older dims rather
than vanishing, and expires on its own timer.

**A third line bumps the oldest immediately — it does not wait its turn.** Dialogue is
narrating events the player is watching, so a queue that holds lines back drifts out of sync
with what is happening on screen, and the backlog arrives describing a firefight that has
already ended. Bumping keeps the text tied to the moment and still solves the actual defect:
a reply no longer erases the line it answers, because the question is still on screen beneath
it. What bumping costs is the third line of a rapid three-line burst, and there is no such
burst in the source — the tightest run is the intro's `sleep 8` between Overlord lines.

The UI ground is clear: `RscTitles` is defined in exactly one place, `description.ext:61-79`,
holding a single class (`DUWST`, the intro splash shown once from
`server/misc/fnc_intro_heli.sqf:128`). `BIS_fnc_rscLayer` appears nowhere in `src/duws`, so
no layer number is claimed and a fresh named layer cannot collide. The only care needed is
not fighting the default title layer during the intro, which runs `cutRsc`, `titleText` and
`titleCut` within seconds of two pilot lines.

The display handle goes in `uiNamespace`, never `missionNamespace`: the mission namespace is
serialized into save games and rejects handle types. See
[§Non-serializable handles](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace).

**The renderer must return immediately — expiry cannot be a `sleep` in the call path.** Nine
sites reach the router through `call`, which is synchronous, and `BIS_fnc_showSubtitle`
returns straight away today; a queue that suspends for its own timer would stall those
callers for the duration of the line. `fnc_civ_healAction.sqf:56,68` is the case that makes
it concrete — two `call` subtitles either side of a `sleep 3`, which is exactly the two-line
exchange this renderer exists to keep on screen. Expiry belongs to one long-lived ticker or
a frame handler owned by the renderer, not to the calling script.

`shared/includes/notifications.hpp` is not reusable here — it is a `CfgNotifications` block
driving `BIS_fnc_showNotification`, a separate BI queue with its own rendering. That is the
SYSTEM surface and it stays where it is.

### The NET path

```sqf
[west, _speaker] sideChat _text;   // local, no remoteExec — the router is already there
```

The `[side, identity]` left operand is the local-effect form of `sideChat`, and the speaker
string is the chat identity, so the engine renders `Speaker: line`. It is not an untested
assumption: `fnc_sideChat_filter.sqf:18` ships this exact form today as
`[[West,"OVERLORD"], _message] remoteExec ["sideChat", 0]`, and its `remoteExec` wrapper is
what makes one machine's call reach the room — which is precisely the wrapper the router
must *not* repeat. `CfgRemoteExec` needs no change either way:
`shared/includes/remoteExec.hpp:10` sets `mode = 2` for Functions and `:44` for Commands, so
the whitelist is ignored.

Four things about the existing side-chat path change:

- **The fan-out moves to the call site.** `fnc_sideChat_filter` is invoked once and
  broadcasts; the router is invoked everywhere and must not. Dispatching locally is also
  what preserves per-site targeting — `fnc_disguiseAsEnemy.sqf:127` sends the intercepted
  OPFOR traffic to `_caller` alone, and a re-broadcast would leak one player's eavesdrop to
  the whole server.
- **The radio gate goes.** `fnc_sideChat_filter` currently checks `"ItemRadio" in
  assignedItems _sender` and falls back to `globalChat` — a *wider* channel — when the
  check fails. A gate whose failure mode is broadcasting more loudly is not a gate. NET goes
  to the side channel unconditionally.
- **The sender is the real speaker**, not the hardcoded `"OVERLORD"` literal.
- **`fnc_sideChat_filter` is deleted** once its 15 live call sites are re-pointed:

| Sites | Where | Goes to |
|---|---|---|
| 7 | `fnc_found_intel:8,15`, `fnc_request_fob:28,41,62`, `fnc_fob_server:47`, `fnc_WARCOM_gps_marker:25` | VOICE — Overlord or the player |
| 6 | `fnc_uav_scanner:73,82,91,162`, `fnc_boatTaxi:75,130` | NET — Allseer 1-1 and Swordfish 1-1 |
| 1 | `fnc_zone_reveal:18` | Deleted — duplicates the subtitle on the next line |
| 1 | `fnc_capture_zones_task:58` | SYSTEM — campaign-won, already has a notification and a hint |

Swordfish 1-1 needs a stringtable key; it exists only inside message bodies today.

**The engine owns the colour, so the callsign has to carry the distinction.** Side-channel
text is coloured by the channel, not by us — there is no per-line colour on `sideChat`, and
routing hostile traffic through `[east, …]` instead would put it on a channel BLUFOR players
do not receive at all. Intercepted OPFOR traffic is therefore told apart by its sender name
("Siren 1-4", "HQ") and by reading as enemy procedure, not by being tinted.

**A server that disables the side channel silences NET, and that is an accepted risk.**
`disableChannels[]` in `server.cfg` is common on co-op servers that push radio traffic into
TFAR or ACRE. The mission cannot see or override it, and the failure is silent: 46 lines
simply never appear. The alternative is `systemChat`, which cannot be disabled but has no
sender field — the speaker would have to be prefixed into the text by hand, giving up the
one thing the native channel does well. Nothing in `src` disables channels, the mission
ships mod-free, and a server that has deliberately moved radio into a mod is not a
configuration to design the default around.

### Two malformed inputs the renderer must survive

`destroy_tower/fnc_destroy_tower_mission.sqf:225` passes `["", _message1]` — a deliberately
unattributed line. The renderer needs a blank-speaker path that does not emit a dangling
`": "`, and blank routes to VOICE.

`server/supports/fnc_fob_server.sqf:70` passes a **position array** where the speaker
belongs, because the call is built with `format` and interpolates `str(_foundPickupPos)`.
That is a pre-existing bug and this plan does not fix it; the router must not crash on a
non-string speaker, and must route it to VOICE rather than testing it against the table.

### Audio

The squelch marks an **incoming transmission**, not a category. You hear it when a
transmission arrives, never when you key up yourself:

| Speaker | Squelch |
|---|---|
| Every NET speaker, hostile included | Yes |
| Overlord — VOICE, but genuinely on the radio | Yes |
| The player callsign — that is you talking | No |
| Civilians, informants, survivors, IDAP staff, the downed pilot, the intro pilot | No |

That rule is decidable from the speaker alone, which is what lets it live in the router. It
also removes the radio hiss from every civilian conversation and from the 9 mis-squelched
`protect_civ` lines in one move.

`STR_DUWS_T_actionteam` carries the one case the rule cannot see: the player answering
Overlord on the net and the player talking to a civilian face to face are the same key. The
rule above lands on silence for both, which is correct for the face-to-face half and
harmless for the other — you do not hear your own squelch either way. If play says
otherwise, the fix is the same one applied to `STR_DUWS_T_pilot`: split the key and triage
the 73 sites.

`DUWS_Radio_End` is deleted rather than wired up. A start/end pair brackets audible speech,
and there is none here — the transmission is text, so the end tone would fire against
nothing. One tone per incoming transmission is the whole effect.

Strip the `RadioAmbient` pool and its sleep from `server/server_fnc_init.sqf:1053-1109`, keep
`DUWS_Radio_Start`. With the long sleep gone, the `DUWS_radioChatterRunning` mutex no longer
suppresses the squelch on closely-spaced lines, and the 166 explicit
`fnc_broadcastRadioChatter` call sites all disappear into the router.

**The squelch is a local `playSound`, for the same reason the NET dispatch is local.** The
router already runs on every addressed machine; another `remoteExec [..., 0]` from inside it
would play the tone N times per line.

**That narrows the squelch audience at 54 sites, and it is the intended outcome.** All 166
chatter calls target `0` today, but 51 subtitle sites target `_caller` and 3 target
`_player` — so a line only one player can read currently squelches for the whole server.
Folding the two together ties the tone to the line. Expect it in play testing rather than
reading it as a regression.

### The stringtable pass

This is the larger half of the work, and it is content rather than code.

Speaker names are already independent keys, so `Speaker: line` composes at runtime with
**six new keys** — `_pilot_intro`, `_pilot_downed`, and one each for Swordfish, Chariot,
Crane and Stork. Every other speaker name already has one.

**107 English bodies** open with a self-introduction or a callsign address — not the handful
the problem tables sample. Scope it to `English` and `Chinesesimp` and it is still ~214 edits,
which is why this is the larger half of the work and why it is the last phase rather than the
first.

**Strip the sender, keep the addressee.** The two patterns look alike and only one is
redundant:

| Body | Speaker slot | Treatment |
|---|---|---|
| "This is Overlord. Nothing we don't already know." | Overlord | Strip — the slot already says it |
| "Alpha 1-1, this is Overlord. Civilians may be present…" | Overlord | Strip "this is Overlord", **keep "Alpha 1-1,"** — that is who is being called |
| "Alpha 1-1 to Overlord, we've got the exact objective location." | Alpha 1-1 | Strip the sender half, keep "to Overlord" |
| "Knight 1-5 to HQ, almost on station." | Pilot | Sender contradicts the slot; reconcile the two, do not just delete |

That rule also settles the interaction with `fnc_cs`. Addressee tokens stay, so `"Alpha 1-1"`
survives in the bodies that call the player by name and the substitution keeps having
something to match. Only sender-side occurrences leave.

`German` and `Spanish` sit at ~75% coverage and already lag, as the callsign strings do by
design. A body edited in English and left alone in German keeps its old self-introduction,
which reads redundantly but is not broken.

**Strip the quote marks from the Chinesesimp callsign values in the same pass.**
`STR_DUWS_T_allseer`, `_koipilot` and `_changgongpilot` wrap their non-English names in
literal `"`, which was invisible while the name only appeared mid-sentence and becomes
`"全视眼 1-1": line` the moment it is a sender. English is already clean; German and Spanish
keep theirs, along with the rest of the localisation debt.

`client/missions/fnc_stratmap.sqf:12` uses lowercase `STR_DUWS_T_overlord`. Fix it while in
there.

### Bombing supports

`client/supports/fnc_arty.sqf` covers all six bombing types and has exactly one subtitle, at
`:36`. That one is the player calling the mission in — `_speaker` is the player callsign at
`:16` — so it stays VOICE and is the *only* half of the exchange anyone currently sees.

The gun line's four replies are `player globalChat` at `:56,58,127,129`, which is
client-local: in a co-op session nobody but the caller hears the fire mission answered. They
are Slingshot 1-1, they become NET, and converting them is the same mechanical edit that
fixes a real multiplayer gap.

## Migration

### Saved campaigns

Nothing to migrate, and the question of whether the save works at all does not arise. The
only save is vanilla `saveGame` (`server/misc/fnc_autoSave.sqf:11`) — see
[§What the current save does not cover](campaign_persistence_plan.md#what-the-current-save-does-not-cover)
— and no shipped save encodes dialogue state either way. `duws_callsign` is the one
persisted value this change reads, and its meaning does not change: it stays the
host-chosen replacement for the literal `"Alpha 1-1"`, only substituted a layer lower down.

### The sweep is the risk, not the design

274 call sites across 92 files, plus 166 squelch calls across 74. The mechanical edit is not
hard; landing it *reviewably* is. A diff that renames 274 sites **and** changes what the
player sees cannot be reviewed at all — a wrong speaker or a wrong channel is invisible in a
274-site diff, and `tests/run.sh` will not catch either. It checks bracket balance and path
resolution; it has no opinion on which surface a line lands on.

So the sweep is split from the semantics. Phases 0-2 are a no-op **by construction**: if
anything changes on screen, something is wrong, and that is the whole diagnostic. Phase 3 is
the first behaviour change, it is small, and it reverts on its own because the pass-through
is still in place beneath it.

Phase 3 splits again, and this is the seam worth keeping. **3a routes NET to the chat box
while VOICE still calls `BIS_fnc_showSubtitle` unchanged** — the whole attribution fix, with
no new UI code and nothing new to draw. Everything that follows works against either
renderer: the squelch (4) is decided in the router, the `fnc_sideChat_filter` retirement (5)
only touches NET, and the stringtable pass (6) improves both surfaces.

That makes **3b the only phase that needs in-engine iteration**, and the only one that can be
deferred or abandoned without stranding the rest. If the two-line renderer turns out to want
more tuning than expected, the mission still ships with correct attribution and quiet
civilians.

| Phase | Change | Visible? | Guard |
|---|---|---|---|
| 0 | Land `fnc_duws_dialogue` as a pure pass-through to `BIS_fnc_showSubtitle`. NET table present, unused. | No | Boot registry reports it non-empty |
| 1 | Rename the 274 call sites | No | 263 + 2 + 9 all accounted for; `BIS_fnc_showSubtitle` greps to zero |
| 2 | `fnc_cs` moves into the wrapper; strip it from the 68 speaker slots | No | A host-chosen callsign still appears |
| 3a | Turn on NET routing. VOICE still calls `BIS_fnc_showSubtitle` untouched. | **Yes** | 40 lines move to the chat box, each once per player; the subtitle behaves exactly as before |
| 3b | Replace the VOICE path with the two-line renderer | Yes | Two lines 1 s apart are both readable |
| 4 | Squelch into the router; delete the 166 `fnc_broadcastRadioChatter` calls and the function | Yes | Greps to zero; registry stays clean |
| 5 | Retire `fnc_sideChat_filter`: re-point 15 sites, delete the file and its registry line | Yes | `check_paths.py` fails if the registry line outlives the file |
| 6 | Stringtable pass | Yes | No line renders as "Overlord: This is Overlord" |

Phase 2 has to precede phase 3, not follow it. The router matches the speaker *before*
callsign substitution; while the 68 sites still pre-substitute, a host who renames their team
to "Bravo 2-2" hands the router a string it cannot place. See
[§Why the callsign substitution has to move first](#why-the-callsign-substitution-has-to-move-first).

### Two sites a naive sweep will miss

The rename splits three ways, and the counts are the guard — a script that finds 263 and
stops has silently left 11 sites on the old function:

| Form | Count |
|---|---|
| `remoteExec ["BIS_fnc_showSubtitle", …]` | 263 |
| `remoteExec ['BIS_fnc_showSubtitle', …]` — **single-quoted, inside a quoted trigger statement** | 2 |
| `call BIS_fnc_showSubtitle` | 9 |

The two single-quoted ones are `server/init_hq/fnc_BluHQinit.sqf:693` (a
`setTriggerStatements` body) and `server/supports/fnc_fob_server.sqf:70` (a `format`
template). They are strings the engine compiles later, so no linter sees them and no
double-quote pattern matches them. Edit those two by hand and exclude them from the script.

The sweep script should refuse to run unless the pre-counts match exactly. A regex that
quietly matches fewer sites than expected is the failure mode that leaves a half-migrated
mission booting cleanly.

### Deleting the two functions is not symmetric

They are registered differently, so only one of them has the lint interlock:

| Function | Registration | Guards on deletion |
|---|---|---|
| `fnc_sideChat_filter` | `preprocessFileLineNumbers` of a real file, `server/server_fnc_init.sqf:720` | Both — `check_paths.py` fails an orphaned registry line as a new unresolved path, and the boot self-check then logs `ERROR REGISTRY` for the empty compile |
| `fnc_broadcastRadioChatter` | Defined **inline**, `server/server_fnc_init.sqf:1039-1111` | Neither — there is no path to resolve and nothing left behind to compile empty |

The boot registry self-check lives at `server/server_fnc_init.sqf:1112-1127`: it walks
`allVariables missionNamespace` for `fnc_*` and reports any that stringify to `{}`.

Delete the file, the registry line and the `publicVariable` in one commit and the guarded
half stays quiet. The unguarded half needs the grep rule instead — a lint banning
`BIS_fnc_showSubtitle`, `fnc_broadcastRadioChatter` and `fnc_sideChat_filter` under
`src/duws` is the only thing that keeps 274 sites from drifting back one at a time, and for
the inline function it is the only check there is.

### One interaction with the persistence plan

`server/supports/fnc_fob_server.sqf:20-24` announces a new FOB over subtitle and squelch
behind a `sleep 5`. The campaign persistence plan needs that function replayable at boot to
rebuild saved FOBs, and lists a silent flag as a prerequisite — otherwise a restore queues
the whole announcement set at startup.

That flag belongs to the router, not to `fnc_fob_server`: a suppress mode on
`fnc_duws_dialogue` covers every replayed announcement at once, where a per-function flag
has to be re-invented at each builder the restore path calls. Nothing here needs to build it
now; the router just should not make it awkward to add.

## Files touched

| File | Change |
|---|---|
| `client/misc/fnc_duws_dialogue.sqf` | New. Router, NET table, callsign substitution, local NET and squelch dispatch. |
| `client/misc/fnc_duws_dialogue_channel.sqf` | New. Pure speaker→channel lookup, including the blank and non-string speaker paths. Separate so `extract_fn.py` can pull it into sqf-vm. |
| `client/misc/fnc_duws_voice_render.sqf` | New. Two-line queue, expiry, dim-on-supersede. Returns immediately; expiry runs off its own ticker. |
| `description.ext:61-79` | New `RscTitles` class beside `DUWST`. |
| `server/server_fnc_init.sqf:222-242` | `fnc_cs` applied inside the wrapper; registry lines for the three new functions. |
| `server/server_fnc_init.sqf:1039-1111` | Drop `fnc_broadcastRadioChatter` and the `RadioAmbient` pool; the squelch moves into the router. |
| `tests/unit/functions.txt`, `tests/unit/cases.sqf` | Register `fnc_duws_dialogue_channel` and assert every roster entry plus the two malformed speakers. |
| `shared/includes/sounds.hpp:31-35` | Delete the unplayed `DUWS_Radio_End` class. |
| 265 `remoteExec` sites | `"BIS_fnc_showSubtitle"` → `"fnc_duws_dialogue"`. |
| 9 `call` sites | Same. |
| `server/init_hq/fnc_BluHQinit.sqf:693`, `server/supports/fnc_fob_server.sqf:70` | Name change inside the quoted trigger statement, not in SQF. |
| 68 `actionteam` speaker slots — 24 assignments, 44 inline | Strip `call fnc_cs`; the wrapper does it. |
| 166 `fnc_broadcastRadioChatter` sites | Deleted. |
| `shared/functions/fnc_sideChat_filter.sqf` | Deleted. |
| 15 `fnc_sideChat_filter` call sites | Re-pointed to `fnc_duws_dialogue` with a real speaker. |
| `server/misc/fnc_intro_heli.sqf:125,155` | `STR_DUWS_T_pilot` → `STR_DUWS_T_pilot_intro`. |
| `rescue_pilot/fnc_rescue_pilot_mission.sqf:414` | `STR_DUWS_T_pilot` → `STR_DUWS_T_pilot_downed`. |
| `client/supports/taxi/fnc_helotaxi.sqf` | Speaker → Chariot 1-1 at 5 sites; drop `_taxiName`/`_random1`/`_random2` (`:12-14`) and their `params` plumbing (`:99,119,176,223,238,266`). |
| `client/supports/fnc_helolift.sqf` 4, `server/supports/fnc_helolift_ropes.sqf:51` | Speaker → Crane 1-1. |
| `fnc_paradrop.sqf:13`, `fnc_ammobox.sqf:32`, `fnc_sawp_drop.sqf:12`, `fnc_siva_drop.sqf:13` | Speaker → Stork 1-1. |
| `client/supports/fnc_arty.sqf:36` | Stays VOICE — `_speaker` is the player callsign (`:16`), this is the fire mission going out, not the gun line answering. |
| `client/supports/fnc_arty.sqf:56,58,127,129` | `globalChat` → router, speaker `STR_DUWS_T_slingshot`; drop the duplicate literal at `:49-51`. |
| `server/warcom/fnc_WARCOM_gps_marker.sqf:25` | Hardcoded English → new stringtable key. |
| `server/supports/fnc_sitrep_support.sqf:19` | Drop the duplicate `systemChat`. |
| `server/misc/fnc_disguiseAsEnemy.sqf:126` | Drop the duplicate `systemChat`; `:127` routes to NET on the speaker table alone. |
| `server/init_zones/fnc_zone_reveal.sqf:18` | Drop the duplicate line; keep the subtitle. |
| `client/missions/fnc_stratmap.sqf:12` | Fix the lowercase key. |
| `stringtable.xml` | Six new keys (`_pilot_intro`, `_pilot_downed`, Swordfish, Chariot, Crane, Stork); strip the sender half of ~107 English bodies and their Chinesesimp twins, keeping addressees. |

## Task list

Ordered by the migration phases above. Everything through phase 2 must be invisible in play;
the first three boxes are done when nothing has changed on screen.

- [ ] **P0** Land `fnc_duws_dialogue` as a pass-through, with the NET table built but unused, and `fnc_duws_dialogue_channel` as a separate pure lookup. Verify: boot log reports both non-empty in the registry count; add the lookup to `tests/unit/functions.txt` and assert every roster entry plus the blank and non-string speakers in `cases.sqf` — it is the one thing the lint cannot check.
- [ ] **P1** Sweep the 274 call sites. Verify: pre-counts matched 263 + 2 + 9; `BIS_fnc_showSubtitle` greps to zero under `src/duws`; `bash tests/run.sh`; the two single-quoted sites edited by hand.
- [ ] **P2** Move `fnc_cs` into the wrapper and strip it from the 68 speaker slots — the 44 inline ones are the half a `_speaker` grep misses. Verify: a host-chosen callsign still appears, and a renamed team still routes to VOICE.
- [ ] Split `STR_DUWS_T_pilot`. Two VOICE keys (`_pilot_intro`, `_pilot_downed`, 4 sites); the other 14 move to support callsigns — Chariot 1-1, Crane 1-1, Stork 1-1 and the existing `_slingshot`. Verify: no `_speaker` assignment anywhere is a bare SQF literal, which is what the router relies on.
- [ ] **P3a** Turn on NET routing; VOICE keeps calling `BIS_fnc_showSubtitle`. Verify: a support call lands in chat under its own callsign; the subtitle is unchanged from before; in a two-client session each NET line appears **once** per player, not twice — that is the local-dispatch check.
- [ ] **P3b** Write the two-line VOICE renderer and switch VOICE to it. Verify: two VOICE lines fired 1 s apart are both visible, the older dimmed, a third bumps the oldest.
- [ ] **P4** Fold the squelch into the router as a local `playSound`; delete the 166 `fnc_broadcastRadioChatter` sites and the inline function. Verify: two NET lines 2 s apart both get a squelch, once each; a civilian conversation gets none; a `_caller`-targeted line no longer squelches for the rest of the server.
- [ ] **P5** Re-point the 15 `fnc_sideChat_filter` sites; delete the file, its registry line and its `publicVariable`. Verify: grep returns nothing; `check_paths.py` passes; the boot log shows no `ERROR REGISTRY`.
- [ ] Drop the four duplicate-surface postings (sitrep, disguise, zone reveal, campaign won).
- [ ] Convert the four `fnc_arty.sqf` `globalChat` calls. Verify: a non-host player sees a fire mission called by the host.
- [ ] `fnc_WARCOM_gps_marker.sqf:25` hardcoded English → a stringtable key.
- [ ] **P6** Stringtable pass, English and Chinesesimp; strip the quote marks from the three Chinesesimp callsign values. Verify: no line renders as "Overlord: This is Overlord", no sender name renders inside quotes, and no body names a callsign its speaker slot contradicts.
- [ ] Add the lint rule banning the three retired names under `src/duws`.
- [ ] In-game: run a side mission with dense dialogue and confirm no line is lost; call a support and confirm it lands in chat, not on the subtitle; go disguised and confirm the intercepted OPFOR traffic does not displace dialogue.

## Decided trade-offs

**NET bodies are not shortened for the chat box.** Some run past 100 characters — *"Alpha 1-1,
this is Allseer 1-1. We've spotted an enemy supply truck moving between zones…"* — which
reads fine as a subtitle and long in chat. Rewriting them for length is a separate editorial
pass on top of the ~214 edits the sender-strip already costs, and stripping the sender takes
the worst offenders down on its own. Judge the remainder in play, with the real box.

**Two lines, not four.** The original plan proposed a four-line stacked feed. Four lines is
a killfeed, and it reads as one. Once NET traffic leaves the subtitle the remaining stream is
a two-party conversation — Overlord to the player, or a civilian to the player — so two lines
covers the actual failure (a reply wiping its question) without turning the bottom of the
screen into a scrolling log. If play shows two is not enough, it is a constant in one file.

**NET is the explicit list, VOICE the default.** The inverse — listing VOICE speakers and
defaulting to NET — would silently swallow any callsign added later into a chat box the
player is not watching. Defaulting to the loud surface makes a missing table entry visible
in the first minute of play instead of never.

**Squelch by category, not by call site.** The 166 hand-placed `fnc_broadcastRadioChatter`
calls are the reason radio hiss plays over face-to-face civilian dialogue in `protect_civ`
and nowhere else in the civilian scripts. One rule in the router replaces 166 independent
decisions and cannot drift again.

**The wrapper keeps the two-argument signature.** Passing a stringtable *key* instead of a
localised string would let the router key on identity directly rather than on the localised
name, but it means editing all 274 sites and every one of the `format`-wrapped cases.
Building the NET table from the same keys at init gets language-independence for the cost of
one `apply`.

**The FOB speaker bug is flagged, not fixed.** `server/supports/fnc_fob_server.sqf:70`
renders a coordinate triple where a speaker name belongs. It is pre-existing, it is in a
`format`-built trigger statement that wants care, and fixing it here would mix an unrelated
repair into a mechanical rename. The router tolerates it; the fix is its own change.

**German and Spanish keep their self-introductions.** They are already at ~75% coverage and
localisation lags English here by convention. The redundant reading is the cost of not
blocking this change on a full translation pass.

**Designed from the requirement, not from Dynamic Civil War.** DCW was cited as a working
reference, but its source is not on this machine and was not inspected. Nothing here is
derived from it.

**The disguise eavesdrop goes to NET.** `fnc_disguiseAsEnemy` posts intercepted OPFOR radio
traffic every 20 s while the player is disguised. It is radio and it is not addressed to the
player, so the category rule places it without an exception. It is also the only feedback
that the disguise is still holding, which is an argument for the loud surface — but a line
arriving every 20 s for the full disguise duration would monopolise a two-line subtitle
queue and bury the dialogue it exists to protect. The chat box absorbs a repeating line
without cost, and the enemy callsign in the sender slot keeps it distinguishable.

**The squelch marks incoming, not radio-ness.** Attaching it to "is this a radio line"
leaves the player callsign undecidable, because the same key covers both halves of a
face-to-face exchange and a net exchange. Attaching it to "did this arrive at the player"
resolves every speaker from the speaker alone, and lands on the right answer for the case
that actually grates: no hiss over a civilian conversation.
