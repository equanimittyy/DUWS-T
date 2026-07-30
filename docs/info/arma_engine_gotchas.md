# Arma engine gotchas

Engine behaviours that aren't visible in the SQF itself and cost real debugging time.
Each entry states the rule, why the engine forces it, and how to apply it. Add an entry
when an Arma-specific trap — not a plain SQF bug — burns a debugging session. For where
the mission's subsystems live see [`architecture.md`](architecture.md).

## `remoteExec` to your own machine still runs a frame later

**`remoteExec` never executes inline, not even when the target is the machine already running
the code. It queues the call, which runs in the scheduled environment on a later frame. Two
statements that must not be separated cannot be split across a `remoteExec` to self.**

The trap is a server-side function that validates then acts: `if (pool < cost) exitWith {};`
followed by `[-cost] remoteExec ["fnc_pool_writer", 2]` looks atomic, and on one machine it
reads as ordinary sequential code — but the debit lands in a later frame, so a second request
arriving in between passes the same check against the same undebited pool. The command also
returns nothing, so there is no handle to wait on and nothing to reveal the gap.

**How to apply:** on the server, invoke a server-side function with `call`, which runs it
inline. Reserve `remoteExec [..., 2]` for callers that are genuinely remote. When the verdict
has to travel back to a client, `remoteExec` a reply function at the requesting player rather
than trying to return a value — `fnc_pool_try_spend` and `fnc_pool_spend`
(`src/duws/server/server_fnc_init.sqf`) are the two halves of that handshake.

## The JIP queue is append-only unless the message carries an ID you choose

**`remoteExec`'s third parameter decides what a machine joining *later* receives. A bare `true`
appends the message under an engine-generated ID that nothing can reference, so it stays queued
for the session and every future joiner runs it. An object or a string is addressable: a repeat
call with the same ID replaces the first, `remoteExec ["", "thatID"]` deletes it, and an
object-keyed entry is dropped when the object is deleted.**

| Third parameter | Effect |
|---|---|
| absent / `false` | fire and forget, current machines only |
| `true` | append under an engine-generated ID. Never referenceable, never removable |
| a string | queue under that ID; a repeat call replaces, `remoteExec ["", id]` deletes |
| an object | queue under the object's `netId`; dropped when the object is deleted |

The cost of a bare `true` is not wrong state — an entry naming a deleted object is a no-op,
because the adders guard on `isNull` and `addAction` on `objNull` does nothing. It is that a
joiner executes the whole backlog before reaching anything that matters, and the backlog grows
with the campaign rather than with the player count. One `addAction` per corpse the campaign ever
produced is the shape that bites.

**An object-keyed ID *is* that object's netId**, so two entries on one object evict each other and
only the survivor reaches joiners. That is silent and it breaks behaviour: the sabotage laptop
carried its own `addAction` and, in hardcore, the intel rotary from
`server/dialog/fnc_actionRotary.sqf`, and the rotary evicted the sabotage action, so a joining
client could not finish the mission.

**How to apply:** key every entry that repeats. Where an object carries exactly one entry, pass
the object — it self-cleans. Where two entries must both survive on one object, suffix a string
per entry (`format ["fob_guards_%1", netId _fob]`); the trade is that a string entry naming a
deleted object lingers, which is bounded and quiet where a collision is neither. Eviction is
correct only when the later entry is *meant* to supersede the earlier one — a corpse entry
replacing a spent live-body search on the same unit is right. A transient message (a one-off OSD
or hint) should not be queued at all.

## Non-serializable handles must not live in the mission namespace

**Never store a `DISPLAY`, `CONTROL`, `SCRIPT`, `LOCATION`, or other handle type in a
`missionNamespace` global. Keep UI handles in `uiNamespace`.**

The mission namespace is written into save games, so every global in it must have a
serialized form. Handle types don't, so the engine rejects the write with *"Variable X
does not support serialization and should not be stored in the mission namespace"* —
raised when the global is assigned or at the next save. Booleans, numbers, strings, and
arrays of those serialize fine.

`disableSerialization` does **not** grant an exception. It only tells the engine to skip
serializing a script's **local** (`_underscore`) variables and to not save mid-script; a
value written into a persistent namespace is still checked.

**How to apply:** keep display/control references (open-dialog handles, cached controls)
in `uiNamespace`, which is never saved and is the engine's intended home for UI state.
Read with a default and null-check — `isNull (uiNamespace getVariable ["myDisplay",
displayNull])` — which also detects a dialog closed elsewhere. The faction selector holds
its reused dialog handle this way, in `fnc_factionSelector`
(`src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## Nothing in SQF writes a file, and an extension cannot be shipped inside a mission PBO

**The only durable write targets a mission can reach on its own are the profile-backed
namespaces (`profileNamespace`, `missionProfileNamespace`) and the clipboard. There is no
file-write command, and the `callExtension` route out of that is unavailable to a mission
because the engine never looks inside a PBO for the binary.**

Every file-based persistence library for Arma — iniDBI2, extDB, FileXT — is a compiled
extension for exactly this reason, not by preference. The engine resolves an extension only
from the root of a loaded mod folder or the game install directory, and a mission PBO is
neither searched nor unpacked to disk, so "vendor the dependency into the PBO" reaches a
file in no form. Script libraries vendor fine (`src/modules/`); their ceiling is still the
namespace.

The clipboard is a one-way door in the same way: `copyToClipboard` writes and nothing reads
back, so every clipboard import ends at a human pasting into an edit control. That rules it
out of any unattended path, whatever its size limits turn out to be.

**How to apply:** treat `missionProfileNamespace` as the store and design the payload as
plain numbers, strings, booleans and arrays so `str` / `parseSimpleArray` round-trips it —
then the store is one `setVariable` and an alternative writer costs nothing later. A
dedicated server is the one deployment that can add a real file store invisibly, because a
`-serverMod` extension is not announced to clients and needs nothing installed player-side;
singleplayer and hosted sessions cannot, since the host is the server. Reasoning and the
design built on it: [`../campaign_persistence_plan.md`](../campaign_persistence_plan.md#where-the-save-lives).

## `exitWith` exits the nearest loop or call scope, not the enclosing if/then

**Inside a loop, `if (cond) exitWith {...}` terminates the whole loop — even when the
`exitWith` is nested several `if/then` blocks deep. `if/then`/`switch` blocks are
transparent to it.**

`exitWith` unwinds to the nearest enclosing scope created by a loop (`while`, `for`,
`forEach`, `count`) or by `call`/`spawn`/`execVM`; the standard `if (done) exitWith {}`
break relies on exactly this. The trap is writing `if (a) then { if (b) exitWith {...} }`
expecting the `exitWith` to abandon only the inner block and let the loop keep iterating —
it does not, it exits the loop. A loop that was meant to retry then silently runs once and
quits.

**How to apply:** to skip-and-retry the current iteration use `continue` (or let control
fall off the end of the loop body); reserve `exitWith` for when you genuinely want the loop
to stop. The zone locator hit this: an origin keep-out used `exitWith` to "re-roll" a
position but instead dropped the zone entirely — see
[`zone_and_town_generation.md`](zone_and_town_generation.md#defects-subsystem-a).

## Structured-text controls need a parsed object, not `ctrlSetText`

**Set a `CT_STRUCTURED_TEXT` (type 13 / `RscStructuredText`) control with
`ctrlSetStructuredText (parseText "<t ...>...</t>")`, never `ctrlSetText`.**

`ctrlSetText` on a structured-text control stores the string verbatim, so `<t>` markup
renders as literal on-screen text — and it fails silently, with no error to point at the
cause (the wasted time goes into suspecting a missing class definition instead). Only
`parseText` turns the markup into the structured-text object the control draws.

**How to apply:** `_ctrl ctrlSetStructuredText (parseText _markup)` to set, `parseText ""`
to clear. The faction selector's "no units" caption uses this, in `fnc_factionSelector`
(`src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## Listbox rows show `<t>` markup literally; `addAction` titles render it

**`lbAdd` / `lbSetText` store a row's text verbatim, so `<t color=...>...</t>` shows as
literal tag characters. `addAction` titles, by contrast, are drawn as structured text and
render the same markup — so a label is fine in a scroll action but breaks in a listbox.**

The trap is moving a label from a scroll-wheel action into a listbox menu: several DUWS
strings bake the colour markup into the string itself (e.g. `STR_DUWS_T_HIRE_PMC`), so they
render clean as action titles but expose raw `<t ...>` tags the moment they populate a
listbox row. Row colour has its own channel anyway — `lbSetColor [idc, index, [r,g,b,a]]`.

**How to apply:** strip `<...>` tags before `lbAdd` and colour the row via `lbSetColor`.
The reusable action menu does this for every row, in `fnc_open_action_menu`
(`src/duws/client/dialog/fnc_open_action_menu.sqf`).

## `BIS_fnc_showSubtitle` is one slot: the next call wipes the line mid-read

**A second `BIS_fnc_showSubtitle` replaces whatever is on screen immediately. There is no
queue, and the function reports neither how long it holds a line nor when it clears — so
nothing can wait for the current line to finish except a timer you write yourself.**

This bites without any unusual play. `fnc_arty.sqf:36` and `:49` post two lines in the same
frame, and supports are independent comm-menu items with no shared lock, so two of them
narrating at once is ordinary. Whichever line lands second is the only one anybody reads.

The absent duration is the harder half: a queue in front of it has to guess. Erring short is
the safe direction — release early and the next line replaces this one cleanly, release late
and the screen sits blank in between.

**How to apply:** never call it from more than one place. `fnc_duws_dialogue` queues,
`fnc_duws_dialogue_drain` (`src/duws/client/misc/`) holds the single call and spaces lines by
`1.5 + 0.045 × length` seconds; a lint pins that call to that one file.

## Duplicate `<Key ID>` in stringtable.xml resolve to one definition, silently

**A `STR_` ID repeated in `src/stringtable.xml` loads without error, but the engine keeps
only one definition and the other copies are dead: editing a dead copy changes nothing
in-game, and reordering keys can flip which copy wins.**

The table is split into `<Container>` sections purely for navigation — IDs resolve
globally across all containers, so which duplicate the engine keeps is decided by file
order, not by section. When two copies of an ID differ in more than tag order, one string
silently never displays — a latent wrong-message bug.

**How to apply:** the table is deduplicated — keep it that way. When a string edit appears
to do nothing in-game, grep for a second `<Key ID>` with the same ID before assuming the
change didn't take, and fold any new duplicate into one copy on purpose rather than
leaving a dead twin.

## `format` discards surplus arguments, so a missing `%N` never errors

**`format` matches placeholders to the supplied array positionally and drops any argument
with no matching `%N` — no error, no rpt warning. A string that references fewer
placeholders than its call site passes renders plausible-but-wrong text forever.**

A *duplicated* placeholder hides best of all: `"%1 %2-%2"` against `[_name, _d1, _d2]`
yields a well-formed callsign on every call, just never one whose two digits differ — the
output reads correctly unless you already know the second digit is supposed to vary.

The reverse shape is as quiet and has bitten this mission: the boat taxi carried eight
`format` calls handing three arguments to strings containing no placeholders at all, and
all three names were undefined in that file. Every call formatted nothing from three nil
lookups, for as long as the code existed, and no player or log ever saw a complaint.

Localisation multiplies the exposure: every language holds its own copy of the format
string, so one locale can drop a placeholder while the rest are correct, and only players
in that locale ever see it.

**How to apply:** treat the placeholder set as a contract between the call site and *every*
language variant of the key. When editing a `%N`-bearing string, grep the ID for its
`format[...]` call, count the arguments, and confirm the highest `%N` matches in each
language tag — the engine will not tell you when they diverge.

## A trigger statement is a string, so anything formatted into it is a float round trip

**`setTriggerStatements` takes source text, not a closure. A local captured into it has to be
written in with `format`, and a number written into a string and parsed back is not guaranteed to
compare equal to the one that went in.** The value still *looks* right in a log line; it fails
only against `==`, `isEqualTo` or `in`.

This mission stores zone ownership as a list of positions, and the capture path is exactly this
shape: `fnc_createzone.sqf` formats `_zonePos` into the capture trigger's statement, so the array
`fnc_captured` hands to `fnc_zone_control_set` — and which is then filed in
`WARCOM_zones_controled_by_BLUFOR` — descends from text, while the zone's own code still holds the
original. Comparing the two for equality is a coin toss on how many digits survived.
`fnc_zone_control_set` compares X and Y rather than using `in`, which dodges the Z component but
not this.

**How to apply:** prefer `thisTrigger setVariable` over interpolation — the statement can read the
object it is attached to, and the value never becomes text. Where a position must be matched
against one that has been through a statement string, match it by distance (`_a distance2D _b < 1`)
rather than equality; zones and bases are hundreds of metres apart, so a metre of tolerance cannot
select the wrong one.

**Such a match is an identity test, not a proximity one**, and the two read alike at a glance. The
tolerance is float slop and its exact value carries no meaning — unlike the radii in
`fnc_spawnWait` or `fnc_duws_bluforNear`, where the distance *is* the question and the number is
tuned. Comment the difference where you write it, or the next reader folds an identity lookup in
with the gameplay ranges.

## `hint` renders beneath the open map, so map-phase prompts are invisible

**A `hint` (or `hintSilent`) issued while the map is open — `forceMap true` /
`openMap` — draws into the hint box on the mission UI layer, which sits *under*
`findDisplay 12` (the map). The prompt fires (the hint sound plays) but the player
never sees it.**

The trap is a "click on the map"-style instruction shown with `hint` right before an
`onMapSingleClick` wait: the click handler works, but nothing tells the player to click,
so the step looks broken or gets skipped. `titleText`/`cutText` share the problem — those
layers are also below the map.

**How to apply:** draw the prompt on the map display itself. Create a static
`RscStructuredText` control on `findDisplay 12` and set it with `ctrlSetStructuredText` —
static controls are click-transparent, so the underlying `onMapSingleClick` still fires.
`fnc_map_prompt` (`src/duws/client/dialog/fnc_map_prompt.sqf`) does this for the HQ /
AO-direction prompts; pass `""` to clear it before `openMap [false, false]`.

## `onMapSingleClick` is one global slot: the next installer steals the previous one's click

**There is exactly one map-click handler per machine. A second `onMapSingleClick` overwrites
the first with no error and no way to read back what was replaced, so the feature that
installed first waits forever for a click it will never receive.**

The trap is two independent features that each open the map and wait on a click — the HQ map
board alone carries base fast travel and the civilian-zone readout. Nothing warns you: the
second feature works perfectly and the first simply never completes, which reads as the first
feature being broken rather than as a collision.

**How to apply:** every map-click mode raises its own "I own the map" global before
`openMap true` and refuses to start if another mode's flag is up
(`DUWS_baseTravelMapOpen`, `DUWS_civMapViewOpen`). Clear the flag *and* the handler
(`onMapSingleClick ""`) from a `waitUntil { !visibleMap }` spawn, because the engine gives no
callback for the player closing the map and a mode abandoned that way would hold the slot for
the rest of the mission.

## Diary records display newest-first, so add them bottom-up

**`createDiaryRecord` prepends: the record created last is drawn at the TOP of its
subject. To lay a manual out top-to-bottom, create the entries in reverse.**

The map's Notes (diary) is built for a running log, so the newest entry sits on top.
A manual that should read intro-first therefore has to be written last-line-first, which
inverts the obvious reading of the source. The trap is adding a new section at the end of
the script and finding it on top in-game, or assuming source order equals screen order.

Record text is parsed as structured text, so `<br/>`, `<t ...>` and `<font>` work — but
in `stringtable.xml` the markup must be entity-escaped (`&lt;br/&gt;`), or the XML parser
eats the tag as an element.

**How to apply:** the manual (`fnc_duws_help.sqf`) keeps its entries in an array in
display order and calls `reverse` once before the `forEach`, so the source reads the way
the player sees it and only that array changes when reordering. Reuse that pattern for any
new diary subject rather than hand-ordering `createDiaryRecord` calls.

## `for "_i" from A to N step 1` runs `floor(N)+1` times, truncating a fractional bound

**The counter advances in whole steps while `counter <= N`, so a fractional `N` (e.g.
`1.5`) stops at `floor N` and iterates exactly as many times as `to floor N` would. A
fractional value fed straight into such a loop as a "multiplier" is silently rounded
down — `1.5` behaves identically to `1`.**

The endpoint is inclusive-by-comparison, not by count; there is no partial iteration, and
no error or warning marks the truncation. It reads as if the fractional setting works while
producing the integer result.

**How to apply:** resolve a fractional multiplier to an integer *before* the loop — e.g.
`_n = floor _m; if (random 1 < (_m - _n)) then { _n = _n + 1 }` for probabilistic
rounding — then loop `to _n`. The OPFOR unit-multiplier options are kept integer
(`enemyunitMultiplier` 1/2/3) for this reason: the enemy-spawn builders in
`src/duws/server/init_zones/fnc_createop*.sqf` loop `for "_i" from 0 to
enemyunitMultiplier`, so a fractional option there would not change the unit count.

## Scheduled scripts share ~3 ms per frame, so a long loop runs at frame rate

**Everything started with `spawn`/`execVM` runs in the scheduled environment, where the
engine gives *all* such scripts about 3 ms of execution per frame between them. A loop
whose body costs more than that slice gets one iteration per frame, so its wall-clock time
is set by the frame rate and by how many other scripts are competing — not by how much work
it actually does.**

Boot is the worst case: a dozen scripts are spawned at once, and a loop calling a
mid-cost engine command per iteration settles at roughly one iteration per frame however
many iterations there are. The terrain survey in
`src/duws/server/misc/fnc_moreUrban_locations.sqf` measured ~50 candidates/second across
runs of 1144, 3392 and 5909 candidates — a flat rate that tracks frame rate rather than
workload, which is the signature to look for. Nothing in the SQF hints at it; the loop
simply appears to hang.

**How to apply:** batch the work inside `isNil { ... }`, whose code the engine runs
unscheduled and therefore uninterrupted. It shares the calling scope for both reads and
writes, so a cursor and an output array declared outside are visible inside and no state
has to be threaded through a namespace. Bound each batch by a wall-clock deadline rather
than an iteration count — per-iteration cost is rarely uniform — and yield between batches
so the server still services clients. `sleep`/`waitUntil` cannot be used inside the block:
unscheduled code cannot suspend.

Batching that survey to a 15 ms budget took it from ~50 to ~259 candidates/second, which is
the scale of the effect when a loop is scheduler-bound rather than genuinely expensive. To
tell the two apart afterwards, accumulate the time spent inside the batches and log it
against wall-clock: converged means the engine calls are now the floor.

## A shared global mutated as `x = x - c; publicVariable "x"` loses concurrent writes

**`publicVariable` broadcasts an absolute value, and there is no network lock. When two
machines each read a shared global, compute a new value, and `publicVariable` it, the
later broadcast overwrites the earlier — the two changes do not add up. Read-modify-write
of a networked global from more than one machine silently drops updates (and can *create*
resource from nothing).**

Each machine keeps its own copy; `publicVariable` overwrites every remote copy with the
sender's number. So `x = x - cost; publicVariable "x"` run on two clients against a
shared pool of 50 both read 50, both write 30 — net spend 20 instead of 40, and 20 units
appear from nowhere. Local `x = x + n` is itself atomic (SQF yields only at suspension
points), so the loss is specifically the stale *base* a second machine read before the
first machine's broadcast landed. A save game persists the corrupted value for the rest of
the session. In single-player there is one machine and the bug is invisible, so it only
surfaces in co-op.

A delta writer fixes the arithmetic but not the authorisation: the *caller* still decides
whether to spend, and on a client that decision reads a snapshot the server has already moved
past. Both have to be server-side. See
[`cp_economy.md`](cp_economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

**How to apply:** never `publicVariable` a shared resource from a non-authoritative
machine. Route every change through one server-side function that takes a signed *delta*
and applies it (`x = x + _delta; publicVariable "x"`); callers send the delta via
`[_delta] remoteExec ["fn", 2]` and never touch the global directly. The server serialises
the deltas as ordinary atomic statements, so nothing is lost regardless of who fires when
— a delta cannot carry a stale base the way an absolute can. Command points use exactly
this: `fnc_cp_adjust` (`src/duws/server/server_fnc_init.sqf`) is the sole writer of
`commandpointsblu1`; the host's own `publicVariableEventHandler` does not fire for its own
broadcast, so that function also refreshes the on-screen counter locally when
`hasInterface`.

## A joining client is sent every `publicVariable`'d global, then its own init overwrites them

**`publicVariable` is JIP-persistent: the engine keeps the last broadcast value and delivers
it to a client that joins in progress. A per-client init file that then assigns the same
global unconditionally clobbers the delivered value — locally, and silently. The joiner now
disagrees with the rest of the session, and the disagreement becomes everyone's the moment
that client broadcasts the global back.**

The delivery happens before the mission's own client init runs, so ordering does not save it:
the joiner genuinely receives the team's value and then throws it away. Nothing errors,
because assigning a global that already holds a value is legal, and in single-player and on a
host the fault is invisible — both are the machine that did the broadcasting.

The damage is not the stale local copy but the write-back. A client acting on its wrong copy
takes an action the team has already taken, and the `publicVariable` that follows pushes the
wrong state outward, so one joiner's bad read becomes the session's state.

**How to apply:** guard every client-side initialisation of a broadcast global with
`if (isNil "x") then {x = default};`, so a delivered value survives and only a genuinely fresh
session installs the default. Assigning unconditionally is correct *only* for globals that are
never broadcast — which means the decision to `publicVariable` a global and the decision to
initialise it live in two different files and have to be kept in step by hand. In this mission
they are not: `client/includes/supports_init.hpp` guards three flags and assigns three others
unconditionally while `client/dialog/fnc_request_support.sqf` broadcasts all six
([`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#open-defects)).

## Weather set on the server synchronises itself, so mirroring it into a global is dead state

**`setOvercast`, `setFog` and `setDate` are artificially synchronised: run on the server, the
engine propagates the change to every client and to joiners. A client that sets them locally is
overridden by the server's value shortly after. Copying the value into a broadcast global adds
nothing, and the copy rots the moment anyone forgets to re-broadcast it.**

The failure is quiet in a way a normal stale global is not. A `publicVariable`'d weather mirror is
usually broadcast once at init, when it holds a placeholder, and then written every cycle by the
weather loop without a second broadcast — so remote readers keep receiving the placeholder forever
while the sky they are looking at says something else. Nothing errors, because the writes are all
legal and the local machine (server, or a host) always agrees with itself.

**How to apply:** read the sky through `overcast` and `fogParams`, which return the engine's own
synchronised state on any machine, and never mirror weather into a global. Only one script-driven
weather change runs at a time — starting a `setOvercast` halts an in-flight `setFog` — so the
engine's values are also the only ones that account for a transition being cut short. `setRain` is
independent and can run alongside either.

## Waypoint and flight commands are ignored unless the group is local to that machine

**`addWaypoint`, `deleteWaypoint`, `flyInHeight`, `setMass` and `ropeCreate` take effect only
on the machine where the group or object is local. Issued anywhere else they fail silently —
no error, no log line, the AI simply never moves. A hosting player is also the server, so the
mistake works perfectly for whoever is testing and for nobody else.**

Locality follows the creator: a group spawned by a client belongs to that client, and the
server holds only a remote reference to it. `remoteExec [..., 2]` then delivers the call to a
machine that cannot act on it. The pair fails in both directions — a client-spawned group
whose orders are issued server-side, and a server-spawned group ordered from a client.

`fnc_helolift` had both halves at once: it spawned the transport helicopter client-side, then
`remoteExec`'d its waypoints to the server. It also defined its two server-side helper
functions inline in a file that only clients run, so on a dedicated server those names were
never assigned and the calls hit a nil variable. Both defects were invisible to a hosting
player and the feature was simply disabled for everyone else.

**How to apply:** decide which machine owns an AI group before writing anything that commands
it, spawn it there, and route every order back to that machine. Server ownership is the safe
default for anything a mission thread steers. A function invoked through `remoteExec` by name
must be in the registry so the receiving machine actually has it; defining it inline in the
caller only works when caller and target happen to be the same machine.

## Practice targets ignore damage entirely; `HitPart` fires on the shooter, not the owner

**The `TargetP_*` range targets (`TargetP_Civ_F`, `TargetP_Inf2_F`, `TargetP_HVT1_F` and the
rest) do not process bullet damage. `Hit` and `HandleDamage` never fire on them no matter what
`allowDamage` is set to, so a server-side damage handler waits forever. `HitPart` does fire —
but on the machine that fired the round, not the machine where the object is local.**

Clearing `allowDamage false` on one of these looks like the whole fix and changes nothing
observable: they have no damage-driven destroyed state to reach. Detecting a shot means
listening for the *impact* rather than the damage, which is what `HitPart` reports.

That event's locality is the second half of the trap, and it is the opposite of every other
damage handler. `Hit` and `HandleDamage` run where the object is local; `HitPart` runs where
the *projectile* came from. An EH added only on the server therefore stays silent for every
shot a client fires — and, once again, works perfectly for a hosting player, who is both.

**How to apply:** add the handler on every machine with `remoteExec ["addEventHandler", 0]`
and have its body send the result back to whichever machine owns the state. Pass the object as
the `remoteExec` JIP parameter so joining clients receive it — see
[§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose).
The killhouse does this in `server/misc/fnc_createKillhouse.sqf`, bouncing each hit to
`killhouse_srv_target_hit`.

## `setMarkerColor` accepts an inline `#(r,g,b,a)` string, not only a `CfgMarkerColors` class

**A marker colour does not have to be a class name. Passing a literal
`"#(0.5,0,0.5,0.3)"` works and renders that colour, so a mission needing shades outside the
stock `Color*` set does not need a `CfgMarkerColors` block in `description.ext`.**

The trap is reading the documented signature — "class from `CfgMarkerColors`" — and concluding
that a `#(...)` string in existing code must be broken, because it looks like the procedural
texture syntax used by `setObjectTexture` and nothing in the config tree matches it. The
civilian town ellipses in `server/misc/fnc_civ_init_Tomata.sqf` are painted this way and have
always rendered purple; the config block that would "fix" them is dead weight.

**How to apply:** use the inline form for one-off shades and keep `CfgMarkerColors` for colours
the player picks in the editor, which is what the `name` field on those classes is for. Set
translucency with `setMarkerAlpha` rather than trusting the string's fourth channel — the
channel's effect is unconfirmed, and a marker created without an explicit alpha sits at 1.

## `str` on a string adds literal quote characters, and this mission's marker names carry them

**`str "12345678"` does not return `12345678`. It returns the source-code representation, so
the result is eight digits wrapped in a pair of `"` characters. Zone markers are created as
`createMarker [str(_markername), _zonePos]`, which means the marker's real name includes
those quotes — and every later `setMarkerAlpha` / `setMarkerColor` / `setMarkerPos` has to
spell it the same way or it addresses a marker that does not exist.**

The trap is tidying up. `_markername` is already a `String` from `format`, so the `str` looks
redundant and removing it reads as an obvious cleanup — but creation and access have to agree,
and dropping it on one side silently does nothing at all. `setMarkerAlpha` on a name that
matches no marker throws no error and logs nothing; the zone simply stays invisible.

**How to apply:** in `server/init_zones/`, treat `str(_name)` as part of the marker's identity
rather than a conversion, and grep for the sibling accesses before touching either half. The
zone icon and its ellipse are built this way in `fnc_createzone.sqf:45,59` and addressed the
same way in `fnc_zone_reveal.sqf` and `fnc_captured.sqf`. Marker names built without `str` —
the mission has both conventions — are addressed without it, so the rule is per-marker, not
mission-wide.

## `diag_tickTime` counts from process start and is not restored by a savegame

**`diag_tickTime` is Arma's uptime, not the mission's: it is already in the thousands when a
mission begins and it restarts at zero when the game is relaunched. `time` is mission time,
starts near zero, and is saved and restored with the mission. A stamp taken from one clock is
meaningless against the other, and neither one is "seconds since this mission started".**

The trap is a cooldown written as `_last = diag_tickTime` and checked as
`_cd - (diag_tickTime - _last)`. That is correct while the process lives, so it survives every
test — but the "never used yet" default has to be a *negative* sentinel, and any sanity check
comparing the elapsed figure against the cooldown length will see values as large as the game's
uptime and read them as corruption. Resuming an autosave in a fresh session is the real failure:
the saved stamps are from the old process, the clock is back near zero, and every cooldown is
suddenly in the future and locked for as long as the previous session ran. Mixing the clocks
inside one system is worse — the rest-heal cooldown stamps `time`, so writing a `diag_tickTime`
value into it locks the action out for the remainder of the mission.

**How to apply:** pick one clock per cooldown and keep the sentinel, the stamp, and every check
on it. Prefer `time` where a savegame must carry the cooldown; `diag_tickTime` only where the
cooldown is meant to die with the session. The one genuine anomaly worth repairing is a stamp
*ahead* of its clock — clear it and let the function's own default apply, as the monitor in
`server/server_init.sqf:434` does. A stamp far in the past is just an action nobody has used.

## An `Acts_` ambient animation survives death, so the corpse stands and shrugs off hits

**A unit put into an `Acts_*`/`acts_*` ambient animation with a raw `switchMove` stays in that
animation when it dies. No death transition plays, no ragdoll, and the body holds the pose
standing upright — so incoming fire produces no visible reaction and the unit reads as
invulnerable even though `alive` has already flipped to `false`.**

The illusion is total from the player's side: they shoot a prop NPC, nothing moves, and they
conclude `allowDamage false` is set somewhere. Scripts watching the same unit see the opposite,
because `alive` and the `Killed` event are unaffected — the divergence is purely visual, which
is why it survives code review. Anything gated on that death (`waitUntil {!alive _x}`, a
`TaskFailed` notification, an action teardown) fires correctly and looks like it fired for no
reason.

`BIS_fnc_ambientAnim` and `BIS_fnc_ambientAnimCombat` do not have this problem: they install
their own handlers to break the animation, which is why a hand-rolled `switchMove` next to
working `ambientAnim` units looks like it should behave the same and does not. A temporary
`enableSimulation false` during placement is a separate mechanism and not the cause; simulation
being off does suppress damage, but the placement pattern in `server/init_hq/fnc_BluHQinit.sqf`
re-enables it a fraction of a second later.

**How to apply:** when posing a unit with a raw `switchMove`, add a `Killed` handler that clears
the move — `[_unit, ""] remoteExec ["switchMove", 0]`, broadcast so every client's copy drops the
pose, not just the machine where the unit is local. The HQ officer in
`server/init_hq/fnc_BluHQinit.sqf` does this, as does the barrier engineer in the same file. A
posed unit left `allowDamage false` never reaches the failure, so the handler only becomes
load-bearing the moment that unit is made killable — pair the two changes.

**Broadcast the pose as well as the clear, and key it.** `switchMove` is local in both
directions, so a server-side pose dresses the unit on a hosting player's screen and on no other.
Clearing it globally while setting it locally is the shape this mistake takes, because the death
bug above forces the clear to be noticed and nothing forces the set to be. The set needs a JIP
key so a joiner is posed too, and the `Killed` handler then has to drop that queue entry —
`remoteExec ["", _key]` — or a player joining after the death is handed the pose for a corpse,
which is the state the clear exists to prevent. `playMoveNow` is local the same way.

## `enableSimulation` is local, so a server-side freeze leaves clients simulating

**`enableSimulation` only affects the machine it runs on. `enableSimulationGlobal`, server-only,
is the one that reaches everybody.** A unit or prop frozen server-side and then hard-placed with
`setPosWorld` at an absolute Z sits still on the server while every client keeps simulating it,
fails to resolve it onto ground, and renders it falling — permanently, because the server's
position updates keep putting it back in the air. Props settle and drift per machine instead,
so a base looks subtly different to each player.

Both read as correct to a hosting player, whose client is the server. The pattern is therefore
invisible in single-player and in any host-only test.

**How to apply:** use `enableSimulationGlobal` for anything a client also renders, including the
transient freeze used to stop fall damage during placement — the window is short but the client
never gets the matching re-enable, so it never stops simulating at all. `fnc_duws_deploy` in
`server/server_fnc_init.sqf` is the reference: global simulation, local `allowDamage`, the
latter because damage on a server-local object is resolved server-side anyway and broadcasting
it per prop would cost a JIP entry each.

## `reverse` returns Nothing, so it cannot be inlined — and `deleteWaypoint` shifts indices

**`reverse` reverses an array in place and evaluates to Nothing, not to the reversed array. Any
expression that consumes its result — `forEach (reverse _xs)`, `count (reverse _xs)` — is handed
Nothing rather than a list, so the loop body never runs and no error names `reverse` as the
cause.**

This bites hardest next to `deleteWaypoint`, which is the usual reason to want a list backwards.
Waypoints are addressed as `[group, index]`, and deleting one renumbers every later waypoint down
by one. A forward pass over `waypoints _group` therefore deletes only every other waypoint: index
0 goes, what was index 1 becomes index 0, and the loop moves on to index 1 — now the old index 2.
Clearing a civilian's circuit that way leaves half of it in place, and the group walks off again
mid-conversation.

Both halves fail quietly. The forward-delete leaves a plausible-looking shorter list, and the
inlined `reverse` leaves an empty loop; neither raises anything in the `.rpt`.

**How to apply:** bind the array first, reverse it as its own statement, then iterate —
`private _wps = waypoints _group; reverse _wps; { deleteWaypoint _x } forEach _wps;`. Iterating
`for "_i" from (count _wps - 1) to 0 step -1` is equivalent and avoids `reverse` entirely.
`fnc_civ_panic.sqf` and the `fnc_civ_moveToPlayerServer` block in `server/server_fnc_init.sqf`
both do the bind-then-reverse form.

## A waypoint statement never runs if the group cannot reach the waypoint

**`setWaypointStatements` fires only on actual completion. A waypoint the group can never reach
— an exit point past the map edge, a position closed to the group's movement type — is never
completed, so its statement never runs and a `waitUntil` on the flag it sets blocks forever.**

The despawn thread in `fnc_intro_heli.sqf` waited on exactly such a flag. Its flyaway waypoint
sits `15000` m from the HQ on a random bearing, which lands off the map for a large share of HQ
placements; AI aircraft turn back at the boundary, so the group orbits and the statement is
never evaluated. Nothing errors and nothing is logged — the thread just never resumes, leaving
the helicopter and its crew airborne over the base for the rest of the session. `allowDamage
false` on the intro aircraft removes the `!alive` escape hatch that would otherwise cover it.

**How to apply:** treat a waypoint statement as best-effort notification, never as the sole
completion signal for cleanup. Gate deletion on something the engine cannot withhold — distance
travelled plus a hard time cap — the way `fnc_helotaxi.sqf` does, which waits only for the
helicopter to clear 100 m of the player and then deletes on a fixed timer.

## `doStop` outlives the orders it was issued against, and new waypoints do not release it

**A unit under `doStop` ignores its group's waypoints until it is given a move order of its own.
Deleting the group's waypoints and adding a fresh set does not clear the stop — the new circuit
is issued, is visible to `waypoints`, and is simply never walked.**

This is invisible at the call site because the stop and the re-order live in different functions.
`fnc_civ_moveToPlayerServer` (`src/duws/server/server_fnc_init.sqf`) ends on `doStop` so a
civilian called over stands still to be spoken to; every ending of the conversation then routes
through `fnc_civ_resume` into `fnc_civ_wp_Tomata`, which rebuilds the circuit and nothing more.
Each civilian is its own group leader, so the stop held the whole group: anyone the player talked
to stood where the conversation ended for the rest of the town's occupancy. Nothing errors, and
the group's waypoint list looks correct under inspection — the symptom reads as a stuck `CYCLE`
waypoint rather than as a stopped unit.

**How to apply:** pair every `doStop` with an explicit release wherever orders are re-issued, not
where the stop was set. `doMove` to the first waypoint's position is the release —
`_unit doMove (waypointPosition _first)` — because it is both a move order and the leg the group
was about to walk anyway, so it costs nothing on paths that were never stopped.

## `cmd [...] remoteExec ["call", 0]` broadcasts the return value, not the command

**A unary command binds tighter than the binary `remoteExec`, so `titleText [...] remoteExec
["call", 0]` runs `titleText` on the calling machine and then broadcasts what it evaluated to —
Nothing. Every other machine receives an empty payload and shows nothing.**

The missing piece is a pair of braces: `"call"` expects code as its argument, so the intended
form is `{titleText [...]} remoteExec ["call", 0]`. Without them the statement still reads as a
broadcast and still runs the command, which is why it survives review. It also survives testing:
in single-player and on a hosted server the caller is a player's machine, so the local execution
produces exactly the intended visual and the dead broadcast is invisible. Only a dedicated
server, or a second client in a co-op session, exposes it — and nothing reaches the `.rpt`.

**How to apply:** name the command rather than wrapping code in braces — but `remoteExec` hands
the command an argument *list*, not a single value, so a unary command whose one argument is
itself an array needs a second pair of brackets:
`[["In memory of...", "PLAIN", 3]] remoteExec ["titleText", 0]`. Written flat the command is
handed only the first element — `titleText "In memory of..."` — and throws on the type, so the
by-name form silently fails too if the nesting is dropped. That is how the memorial card came to
display nothing while the `titleCut` fades on either side of it, all written nested, kept
working. `src/duws/server/misc/fnc_intro_heli.sqf` is the worked example for both.
