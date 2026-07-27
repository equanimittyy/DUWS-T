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
the `remoteExec` JIP parameter so joining clients receive it and the queued message is dropped
automatically when the object is deleted. The killhouse does this in
`server/misc/fnc_createKillhouse.sqf`, bouncing each hit to `killhouse_srv_target_hit`.
