# Arma engine gotchas

Engine behaviours that aren't visible in the SQF itself and cost real debugging time.
Each entry states the rule, why the engine forces it, and how to apply it. Add an entry
when an Arma-specific trap — not a plain SQF bug — burns a debugging session. For where
the mission's subsystems live see [`architecture.md`](../architecture.md).

## `remoteExec` to your own machine still runs a frame later

**`remoteExec` never runs inline, even when the target is the machine already running the code:
it queues the call for the scheduled environment on a later frame. Two statements that must not be
separated cannot be split across a `remoteExec` to self.**

A server-side validate-then-act — `if (pool < cost) exitWith {}` then `[-cost] remoteExec
["fnc_pool_writer", 2]` — looks atomic but is not: the debit lands a frame later, so a second
request arriving between passes the same check against the same undebited pool. The command
returns nothing, so there is no handle to wait on and nothing to reveal the gap.

**How to apply:** on the server, `call` a server-side function to run it inline; reserve
`remoteExec [..., 2]` for genuinely remote callers. When a verdict must travel back to a client,
`remoteExec` a reply function at the requesting player rather than returning a value —
`fnc_pool_try_spend` and `fnc_pool_spend` (`src/duws/server/warcom/fnc_economy_init.sqf`) are the
two halves of that handshake.

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

The cost of a bare `true` is not wrong state — an entry naming a deleted object is a no-op (the
adders guard on `isNull`, and `addAction` on `objNull` does nothing) — but that a joiner runs the
whole backlog before reaching anything that matters, and the backlog grows with the campaign, not
the player count. One `addAction` per corpse the campaign ever produced is the shape that bites.

**An object-keyed ID *is* that object's netId**, so two entries on one object evict each other and
only the survivor reaches joiners, silently. The sabotage laptop carried its own `addAction` and,
in hardcore, a second intel entry; the second evicted the sabotage action, so a joining client
could not finish the mission. It carries one entry again, but the collision returns the moment
anything puts a second back on it.

**How to apply:** key every entry that repeats. One entry per object: pass the object, it
self-cleans. Two that must both survive on one object: suffix a string each
(`format ["fob_guards_%1", netId _fob]`) — a string entry on a deleted object lingers, bounded and
quiet where a collision is neither. Eviction is right only when the later entry is *meant* to
supersede the earlier (a corpse entry replacing a spent live-body search). A transient message (a
one-off OSD or hint) should not be queued at all.

## A scripted `#particlesource` renders only where it was set, unlike a config smoke object

**A particle source built by script — `"#particlesource" createVehicle` then `setParticleClass` /
`setParticleParams` — is a local visual: the emitter exists only on the machine that ran those
commands. Spawn one server-side and the smoke shows on the host alone; remote and JIP clients see
nothing. A config-backed emitter object (`test_EmptyObjectForSmoke`, `test_EmptyObjectForFireBig`) is
the opposite — one global `createVehicle` renders on every client, because its emitter lives in config
and each machine runs it off the shared object.**

The trade is look for locality: the config helpers are a fixed few (a big black/oily column, a big
fire), so a different column — taller, greyer, medium — means a scripted source, which then has to be
built on every machine. `remoteExec` the builder to all present clients and key its JIP entry to the
parent object so a late joiner rebuilds it while the parent stands (see [§The JIP queue is
append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose)). The builder
must exist on each machine — compile it in `client_init.sqf`, which the server runs too, not in a
server-only file.

**How to apply:** delete the source explicitly on each machine when its parent goes; there is no free
teardown. Deleting an object only *detaches* its `attachTo` children, it does not delete them, so a
source left to the engine keeps smoking from wherever the binned parent last stood. The `effects`-array
convention (`_p setVariable ["effects", …]`) does not rescue it: no reaper deletes a machine-local
source when its shared parent is removed over the network. `fnc_duws_keep` is no help either — it tracks
global composition members and never sees a machine-local source. Instead have each machine watch its own
parent reference and delete its own source once the parent is null (`waitUntil { isNull _parent };
deleteVehicle _src`): `isNull` flips true wherever the parent is binned, host or client, so every machine
reaps its own source exactly once. The patrol-camp beacon (`fnc_camp_smoke.sqf`) is built this way.

## Non-serializable handles must not live in the mission namespace

**Never store a `DISPLAY`, `CONTROL`, `SCRIPT`, `LOCATION`, or other handle type in a
`missionNamespace` global. Keep UI handles in `uiNamespace`.**

The mission namespace is saved, so every global in it must serialize. Handles don't: the engine
rejects the write with *"Variable X does not support serialization and should not be stored in the
mission namespace"*, raised on assignment or at the next save. Booleans, numbers, strings and
arrays of those are fine. `disableSerialization` grants no exception — it only skips a script's
**local** (`_underscore`) variables and mid-script saves; a value in a persistent namespace is
still checked.

**How to apply:** keep display/control references in `uiNamespace`, which is never saved and is
the engine's intended home for UI state. Read with a default and null-check — `isNull (uiNamespace
getVariable ["myDisplay", displayNull])` — which also detects a dialog closed elsewhere. The
faction selector holds its reused dialog handle this way, in `fnc_factionSelector`
(`src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## Nothing in SQF writes a file, and an extension cannot be shipped inside a mission PBO

**The only durable write targets a mission can reach on its own are the profile-backed
namespaces (`profileNamespace`, `missionProfileNamespace`) and the clipboard. There is no
file-write command, and the `callExtension` route out of that is unavailable to a mission
because the engine never looks inside a PBO for the binary.**

Every file persistence library — iniDBI2, extDB, FileXT — is a compiled extension for this reason,
not by preference: the engine resolves an extension only from a loaded mod folder's root or the
game install, and a mission PBO is neither searched nor unpacked, so "vendor it into the PBO"
reaches a file in no form. Script libraries vendor fine (`src/modules/`); their ceiling is still
the namespace. The clipboard is one-way — `copyToClipboard` writes, nothing reads back — so every
import ends at a human pasting, ruling it out of any unattended path.

Neither namespace is unconditionally reliable: Antistasi defaults `missionProfileNamespace` **off
on Linux servers** (detected via `(productVersion # 6) isEqualTo "Linux"`), so which namespace is
live is a runtime decision on a platform the mission does not control.

**How to apply:** treat `missionProfileNamespace` as the store, but name it and its flush command
in one function each so the `profileNamespace` fallback is a one-line change. Serialise with
`toJSON` (Arma 3 2.18+) and key by name — a hashmap tolerates a field added later, where an array
of positions silently misreads every older save. Only a dedicated server can add a real file store
invisibly (a `-serverMod` extension needs nothing player-side); singleplayer and hosted sessions
cannot, since the host is the server.
Reasoning: [`../campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#where-the-save-lives).
Container shape: [`../campaign_save_format.md`](campaign_save_format.md).

## A variable first assigned inside `while do` does not survive the loop

**`while {...} do {...}` runs its block in a scope of its own. A variable that gets its first
assignment in there is created in that scope and is gone when the iteration ends — so reading it
after the loop is reading an undefined variable, whatever the last iteration put in it.**

The trap is that other variables in the loop *do* survive, so the broken one looks like a typo.
`server/missions/fnc_missionTargetPos.sqf` returned five values from after its loop: `_targetpos`,
`_Posfound` and `_failSafe` came back because `params` had declared them in function scope,
`_randomPos` and `_Building` came back undefined because nothing had. Every side mission was then
handed an undefined position for its area marker, objective icon and task destination, and
`createMarker` at one draws nothing — a blank map for years. The `.rpt` carried `Error Undefined
variable in expression: _randompos`, unattached to any subsystem, which is why it was never read
as a mission bug.

**How to apply:** `private _x = <empty value>` above the loop for anything the code after reads.
`params` counts as that declaration, which is why a params-declared variable behaves differently
from its neighbours. The same applies to `for do`, `switch do` and `if then`.

## `params` on a single-array argument destructures it, not binds it

**`X call code` sets `_this` to `X`. When `X` is one array and the block opens with `params ["_a"]`,
`params` walks the array element-by-element and binds `_a` to `X select 0` — the first element, not
the whole array. To receive an array argument intact, read `_this` directly.**

The trap is a callback whose single argument happens to itself be an array. A placement loop handed
each candidate function its anchor as `[_pos, _dir, _zoneCentre]` via `_anchor call _fnCand`; the
function opened with `params [["_anchor", []]]`, so `_anchor` came back as `_pos` alone, and the next
destructure read `_pos`'s x-coordinate as the position. `BIS_fnc_findSafePos` then reported `type
SCALAR, expected ARRAY, on index 0` on every draw and the band pass placed nothing.

**How to apply:** when a `call`/`spawn` block's entire argument is one array you want whole, use
`private _a = _this`. Keep `params ["_a", "_b", ...]` for when `_this` is a list of distinct arguments
to spread. Wrapping at the call site (`[X] call code`) works too but pushes it onto every caller.

## A typed `params` template logs to the RPT on mismatch, then falls back

**`params [["_v", default, [typeTemplate]]]` does not *silently* coerce a wrong-typed value to the
default -- it writes an "Type X, expected Y" error to the RPT first, then uses the default. So a type
template is the wrong tool for a slot whose type legitimately varies: the fallback works, but every
mismatch spams the log.**

A static-placement row carried a role *string* at index 5 on the HQ/FOB fences and an isWeapon *bool*
at the same index on the zone-prefab rows. A `["_role", "", [""]]` template was meant to absorb the
bool quietly into `""`; instead it logged one type error per gun per site. Read the slot untyped
(`["_role", ""]`) and coerce by hand -- `if !(_role isEqualType "") then { _role = "" }` -- when a
value's type is expected to differ and the fallback is the intended path, not an error.

## `exitWith` exits the nearest loop or call scope, not the enclosing if/then

**Inside a loop, `if (cond) exitWith {...}` terminates the whole loop, even nested several
`if/then` blocks deep — `if/then`/`switch` are transparent to it.**

`exitWith` unwinds to the nearest scope created by a loop (`while`, `for`, `forEach`, `count`) or
by `call`/`spawn`/`execVM`; the standard `if (done) exitWith {}` break relies on this. The trap is
`if (a) then { if (b) exitWith {...} }` expecting to abandon only the inner block — it exits the
loop instead, so a loop meant to retry silently runs once and quits.

**How to apply:** to skip-and-retry an iteration use `continue` (or fall off the loop body's end);
reserve `exitWith` for stopping the loop. The zone locator hit this: an origin keep-out used
`exitWith` to "re-roll" a position but dropped the zone entirely — see
[`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#zone-and-civilian-siting-defects).

## `ctrlCreate` on a config display ignores the mission's base classes entirely

**`ctrlCreate ["RscButton", idc]` resolves the class against the parent display's own config
before `missionConfigFile`. On a `createDisplay "RscDisplayEmpty"` (a `configFile` display) every
control is the *engine's* `RscButton`/`RscFrame`/`RscStructuredText`, and the mission's overrides
in `shared/includes/defines.hpp` never apply.**

The two sets differ in ways a screenshot does not obviously blame on the class: engine frames are
RobotoCondensed (narrower than PuristaMedium, reads as text too small) and its structured text is
left-aligned where the mission's is centred. Only the buttons make it unmistakable — the mission
paints them `{0.067, 0.518, 0.729, 0.5}` blue, the engine's come up grey.

**How to apply:** nothing to fix at the source — a mission class cannot outrank a display's own
config. Pin what matters after `ctrlCreate` (`ctrlSetFont`, `ctrlSetFontHeight`,
`ctrlSetBackgroundColor`, `ctrlSetTextColor`) and put structured-text alignment in the markup
(`<t align='center'>`). `client/dialog/fnc_HQ_faction_dialog.sqf` does this once for the whole
screen; anything added there has to join it. Controls declared in a `.hpp` and opened with
`createDialog` inherit from `missionConfigFile` normally and are unaffected.

## A `createDisplay` screen takes no cursor, and shares no draw order with a dialog beside it

**`createDisplay` renders controls but puts no mouse pointer on screen; `createDialog` does. A
screen built the first way is clickable only while a dialog is open beside it — and the two are
separate surfaces whose draw order is not their creation order.**

The trap stays invisible while the two surfaces occupy different ground. The faction setup screen
has always been an `RscDisplayEmpty` of `ctrlCreate` controls with `startup_hq_placement_dialog`
open underneath, its combos working — so nothing said the dialog carried the cursor for both.
Growing the display's opaque background panel down over the dialog's two buttons then took them off
the screen: no error, no log, just a green panel where the buttons had been.

**How to apply:** keep everything the player sees on one surface.
`client/dialog/fnc_HQ_faction_dialog.sqf` owns every control on that screen and opens
`shared/includes/hq_placement.hpp` empty, purely for the cursor. A second display is for input,
never for pixels that must sit in a known order against the first.

## Structured-text controls need a parsed object, not `ctrlSetText`

**Set a `CT_STRUCTURED_TEXT` (type 13 / `RscStructuredText`) control with
`ctrlSetStructuredText (parseText "<t ...>...</t>")`, never `ctrlSetText`.**

`ctrlSetText` stores the string verbatim, so `<t>` markup renders as literal on-screen text — and
fails silently, the wasted time going into suspecting a missing class. Only `parseText` turns the
markup into the object the control draws.

**How to apply:** `_ctrl ctrlSetStructuredText (parseText _markup)` to set, `parseText ""`
to clear. The faction selector's "no units" caption uses this, in `fnc_factionSelector`
(`src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## `ctrlSetStructuredText` has no IDC form, and the parse error voids the whole file

**`ctrlSetStructuredText` exists only as `control ctrlSetStructuredText text`. Unlike
`ctrlSetText`, `ctrlEnable`, `ctrlShow` and the `lb*` family, there is no `[idc, text]` overload —
writing one is a syntax error.**

The damage is out of proportion to the typo because it fails at *compile* time, not at the call.
`compile preprocessFileLineNumbers` on such a file logs `Error Missing ;` with file and line, then
hands back a code block that does nothing: every function the file defines becomes a silent no-op,
so `[] call fnc_x` returns without running and the caller falls over on whichever variable that
function was to set — a mile from the cause. Registration files compile dozens of paths in a row,
so the one useful line sits in the RPT at server-init, thousands of lines above the symptom.

**How to apply:** take the control first —
`(_display displayCtrl 8603) ctrlSetStructuredText parseText _markup`. In an event handler with no
display in scope, read the one the dialog's `onLoad` stashed:
`uiNamespace getVariable ["duws_faction_confirm_display", displayNull]`. Both patterns are in
`src/duws/client/dialog/fnc_faction_confirm.sqf` and `fnc_faction_prompts.sqf`. When a setup screen
never appears, grep the RPT for `Error Missing ;` before reading the script it should have run.

## Listbox rows show `<t>` markup literally; `addAction` titles render it

**`lbAdd` / `lbSetText` store a row's text verbatim, so `<t color=...>...</t>` shows as literal
tag characters. `addAction` titles are drawn as structured text and render the same markup — so a
label fine in a scroll action breaks in a listbox.**

Moving a label from a scroll action into a listbox is the trap: several DUWS strings bake colour
markup into the string (e.g. `STR_DUWS_T_HIRE_PMC`), so they render clean as action titles but
expose raw `<t ...>` tags as listbox rows. Row colour has its own channel —
`lbSetColor [idc, index, [r,g,b,a]]`.

**How to apply:** strip `<...>` tags before `lbAdd` and colour the row via `lbSetColor`.
The reusable action menu does this for every row, in `fnc_open_action_menu`
(`src/duws/client/dialog/fnc_open_action_menu.sqf`).

## `BIS_fnc_showSubtitle` is one slot: the next call wipes the line mid-read

**A second `BIS_fnc_showSubtitle` replaces the screen immediately. There is no queue, and the
function reports neither how long it holds a line nor when it clears — nothing can wait for the
current line to finish except a timer you write.**

`fnc_arty.sqf:36` and `:49` post two lines in the same frame, and supports are independent
comm-menu items with no shared lock, so two narrating at once is ordinary — whichever lands second
is the only one read. The absent duration is the harder half: a queue must guess, and erring short
is safe (release early and the next line replaces cleanly; late and the screen sits blank).

**How to apply:** never call it from more than one place. `fnc_duws_dialogue` queues,
`fnc_duws_dialogue_drain` (`src/duws/client/misc/`) holds the single call and spaces lines by
`1.5 + 0.045 × length` seconds; a lint pins that call to that one file.

## Duplicate `<Key ID>` in stringtable.xml resolve to one definition, silently

**A `STR_` ID repeated in `src/stringtable.xml` loads without error, but the engine keeps one
definition and the other copies are dead: editing a dead copy changes nothing, and reordering keys
can flip which copy wins.**

The `<Container>` split is navigation only — IDs resolve globally across containers, so which
duplicate wins is decided by file order, not section. When two copies differ in more than tag
order, one string silently never displays — a latent wrong-message bug.

**How to apply:** the table is deduplicated — keep it that way. When a string edit appears to do
nothing in-game, grep for a second `<Key ID>` with the same ID before assuming the change didn't
take, and fold any new duplicate into one copy rather than leaving a dead twin.

## `format` discards surplus arguments, so a missing `%N` never errors

**`format` matches placeholders to the array positionally and drops any argument with no matching
`%N` — no error, no rpt warning. A string referencing fewer placeholders than its call site passes
renders plausible-but-wrong text forever.**

A *duplicated* placeholder hides best: `"%1 %2-%2"` against `[_name, _d1, _d2]` yields a
well-formed callsign every call, just never one whose two digits differ. The reverse shape has
bitten this mission: the boat taxi carried eight `format` calls handing three arguments to strings
with no placeholders at all, all three names undefined in that file — every call formatted nothing
from three nil lookups, with no complaint. Localisation multiplies the exposure: each language
holds its own copy, so one locale can drop a placeholder while the rest are correct.

**How to apply:** treat the placeholder set as a contract between the call site and *every*
language variant of the key. When editing a `%N`-bearing string, grep the ID for its `format[...]`
call, count the arguments, and confirm the highest `%N` matches in each language tag.

## Config text is shown verbatim, so a `%N` in it reaches the player unsubstituted

**A `$STR_` reference in config — `CfgDebriefing` titles and descriptions, action names, class
`displayName` — is resolved and displayed as-is. There is no call site to hand it arguments, so a
placeholder in that key renders as the literal characters `%1`.**

This bites when one key serves both a script and a config entry. The campaign's losing text shows
twice: `server/misc/fnc_capture_zones_task.sqf` formats it into the hint with the map's name, and
`shared/includes/debriefing.hpp` shows it on the outro card. The moment the script gained a `%1`,
the card read "%1 is in ruins" — the shared key was the bug.

**How to apply:** a `%N`-bearing key belongs to script call sites only. When config needs the
same sentence, give it its own placeholder-free key rather than pointing both at one ID.

## `localize` on a finished sentence looks it up as a key and speaks nothing

**`localize` only translates a stringtable ID; handed anything else it treats the whole string as a
key, misses, and logs `String <text> not found` to the rpt while returning no usable line. It is not
a passthrough on non-keys — a string already run through `localize`/`format` must never reach a
second `localize`.**

`fnc_mission_finish` localises its line argument, so callers hand it a *key*, not text. The escort
mission baked the delivery town's name into its close line and passed that to finish; finish
re-localised the finished sentence, missed, and the success line went silent — while rep and reward,
later in finish, still ran and masked the cause.

**How to apply:** a line needing a runtime `%N` is finished text — build and speak it at the call
site (`fnc_duws_dialogue`) and hand finish `[]`. Reserve finish, and any `localize`-wrapping helper,
for bare keys.

## A code block sees no locals from where it was written unless it is `call`ed

**SQF blocks are not closures. Scoping is dynamic: a block sees the privates of whatever `call`ed
it, and nothing else. Run it any other way — `spawn`, `execVM`, a saved block the engine invokes
later — and every private in scope where it was written is gone. Where the engine invokes a block
with no arguments, `_this` is empty too, and a global is the only channel left.**

`spawn` is the half that looks safe, because the block is usually written and started a line apart.
`fnc_civ_garrison.sqf` built its garrison in a local block reading `_centre` and `_radius` from
around it and `spawn`ed it: both were nil in the new thread, so `BIS_fnc_findSafePos` got nothing
and the town got no garrison — a spawner that quietly places nothing, not an error naming the
variable. `fnc_civ_handler.sqf` shows the correct form — `[_i, _centre, _radius] spawn _fnc_fill`,
read back with `params`.

This is why several globals look gratuitous and are not. `BIS_fnc_strategicMapOpen` runs each
mission's block with no arguments, so the seventeen launcher blocks in
`shared/includes/mission_types.hpp` each carry a hard-coded index, and
`client/missions/fnc_mission_launch.sqf` turns that index back into a `DUWS_missionSlots` slot — an
index is the one thing such a block can hold without capturing anything.

**How to apply:** pass everything a `spawn`ed block needs through `_this` and read it with
`params`, or `call` the block where it has no reason to run in parallel. When a fix would delete a
global a deferred block reads, preserve the deferral, not just the value — replace the global with
another global or something the block can carry literally. Building the block text with `format`
and `compile` works and is what `setTriggerStatements` forces (below), but it costs the compiler
and is worth avoiding where a literal index will do.

## A trigger statement is a string, so anything formatted into it is a float round trip

**`setTriggerStatements` takes source text, not a closure. A local captured into it is written in
with `format`, and a number written into a string and parsed back is not guaranteed to compare
equal to the one that went in.** It still *looks* right in a log line; it fails only against `==`,
`isEqualTo` or `in`.

This mission stores zone ownership as positions, and the capture path is exactly this shape:
`fnc_createzone.sqf` formats `_zonePos` into the capture trigger's statement, so the array
`fnc_captured` hands to `fnc_zone_control_set` — filed in `WARCOM_zones_controled_by_BLUFOR` —
descends from text while the zone's own code holds the original. Comparing them for equality is a
coin toss on how many digits survived. `fnc_zone_control_set` compares X and Y rather than using
`in`, dodging the Z component but not this.

**How to apply:** prefer `thisTrigger setVariable` over interpolation — the statement can read the
object it is attached to, and the value never becomes text. Where a position must be matched
against one that went through a statement string, match by distance (`_a distance2D _b < 1`), not
equality; zones and bases are hundreds of metres apart, so a metre of tolerance cannot pick wrong.

**Such a match is an identity test, not a proximity one**, and the two read alike. The tolerance is
float slop with no meaningful value — unlike the radii in `fnc_site_poller` or `fnc_duws_bluforNear`,
where the distance *is* the question. Comment the difference, or the next reader folds an identity
lookup in with the gameplay ranges.

## `hint` renders beneath the open map, so map-phase prompts are invisible

**A `hint` (or `hintSilent`) issued while the map is open — `forceMap true` / `openMap` — draws
into the hint box on the mission UI layer, *under* `findDisplay 12` (the map). The prompt fires
(the sound plays) but the player never sees it.**

The trap is a "click on the map" instruction shown with `hint` right before an `onMapSingleClick`
wait: the handler works, but nothing tells the player to click, so the step looks broken.
`titleText`/`cutText` share the problem — those layers are also below the map.

**How to apply:** draw the prompt on the map display itself. Create a static
`RscStructuredText` control on `findDisplay 12` and set it with `ctrlSetStructuredText` —
static controls are click-transparent, so the underlying `onMapSingleClick` still fires.
`fnc_map_prompt` (`src/duws/client/dialog/fnc_map_prompt.sqf`) does this for the HQ /
AO-direction prompts; pass `""` to clear it before `openMap [false, false]`.

## `onMapSingleClick` is one global slot: the next installer steals the previous one's click

**There is exactly one map-click handler per machine. A second `onMapSingleClick` overwrites the
first with no error and no way to read back what was replaced, so the feature that installed first
waits forever for a click it never receives.**

Two independent features that each open the map and wait on a click are the trap — base fast travel
and the civilian-zone readout, both reached from the HQ a pace apart. The second works perfectly
and the first never completes, which reads as the first being broken rather than a collision.

**How to apply:** the slot is arbitrated by one owner name in `uiNamespace`, not a flag per mode.
Claim with `["MODE", _handler] call fnc_mapclick_claim`, release with
`["MODE"] call fnc_mapclick_release` (`server/misc/fnc_mapclick_init.sqf:25`, `:68`). Claiming while
another mode holds is refused *and* said to the player, so a collision surfaces as a message;
re-claiming as the current holder succeeds, which lets a multi-stage mode swap handlers between
stages. Release restores the background listener rather than clearing to `""` (the player-marker
system needs the clicked position all mission), and a release from anyone but the holder is a
no-op, so a mode clearing itself cannot disarm whoever claimed in between. A
`waitUntil { !visibleMap }` spawn is still needed to release on the player closing the map
(`client/missions/fnc_map_readout_open.sqf:27-35`): the engine gives no callback, and a mode abandoned
that way would hold the slot for the rest of the mission. `DUWS_mapReadoutOpen` in that file only
stops the readout opening twice; it is not a claim on the slot.

## A click handler's `_pos` belongs to the engine, not to the local of the same name beside it

**Handler code handed to `onMapSingleClick` is a string the engine compiles and runs in its own
scope, binding `_pos`, `_units`, `_shift` and `_alt` itself. A local called `_pos` in the
installing scope never reaches it, however connected the two look.**

Three sites declare one and none uses it: `client/warcom/fnc_WARCOM_mapclick_assault.sqf:6`,
`client/supports/fnc_mapclickuav.sqf:6` and `client/supports/fnc_mapclickarty.sqf:50` each open with
`_pos = [];` above a handler string that mentions `_pos` (the arty site also passes its local to
`format` as `%1` in a template that substitutes `%2` onwards). All are harmless at runtime and
invisible to a text search, which counts the name inside the string as a use — which is how they
survive a dead-code pass that removes the ordinary unused locals beside them.

**How to apply:** treat a handler string as a separate scope and do not declare the variables the
engine supplies; if it needs a value from the installing scope, substitute via `format` or pass it
as `_this` through the binary form. Any tool counting where a local is used must blank string
literals first, or every one of these reads as live.

## A mission event handler id is a per-event index, not a unique handle

**`removeMissionEventHandler ["EntityCreated", _id]` addresses a position in the list of handlers
for that event type, not a handle unique to yours. Store an id and remove it later and you bet the
position still means what it did at registration — a bet you lose silently, unhooking whichever
handler now sits there.**

`EntityCreated` is the live case: three handlers share it and one is DUWS's.
`server/misc/fnc_scanEnemyGear.sqf` reads gear off new enemies, and
`shared/factions/MODERN/AUTODETECT_blufor.sqf` and `AUTODETECT_opfor.sqf` (or
`AUTODETECT_RANDOM_opfor.sqf`) retexture vehicles and redress crew. Neither autodetect handler ever
removes itself, so nothing keeps those indices honest, and a wrong id disables part of faction
detection with no error — surfacing as vehicles quietly wearing the wrong livery, hours from cause.
Registration order is not visible either: the autodetect handlers are added by `fnc_factions_check`
at `server/server_init.sqf:31`, the gear scan ~fifteen seconds later from its own spawn.

**How to apply:** prefer a handler that never needs removing, gated internally on a flag, over one
removed by id. Where removal is required, capture the id in the same scope that registered it so it
cannot outlive the registration — and treat any event type another system also hooks as reason not
to remove by id at all. Whether a savegame preserves these indices is unestablished; a further
reason not to hold one across a save.

## Diary records display newest-first, so add them bottom-up

**`createDiaryRecord` prepends: the record created last is drawn at the TOP of its subject. To lay
a manual out top-to-bottom, create the entries in reverse.**

The map's Notes (diary) is a running log, so the newest entry sits on top; a manual that reads
intro-first must be written last-line-first. The trap is adding a section at the end of the script
and finding it on top in-game. Record text is parsed as structured text, so `<br/>`, `<t ...>` and
`<font>` work — but in `stringtable.xml` the markup must be entity-escaped (`&lt;br/&gt;`), or the
XML parser eats the tag as an element.

**How to apply:** the manual (`fnc_duws_help.sqf`) keeps its entries in an array in display order
and calls `reverse` once before the `forEach`, so the source reads the way the player sees it and
only that array changes when reordering. Reuse that pattern rather than hand-ordering
`createDiaryRecord` calls.

## An unescaped `&`/`<`/`>` in a diary body blanks the body but leaves the title

**Diary record text is structured-text XML, so a bare `&`, `<` or `>` anywhere in the body voids
the whole body parse. The title is plain text and still shows, so the symptom is a tab that lists
in the subject but renders empty — not an obvious parse error.**

The record is a `[title, text]` pair and only `text` is parsed. A section header like
`"FORCES, ECONOMY & WORLD"` compiles and the tab appears, but the `&` opens an XML entity that
never closes and the engine drops the body silently. Escape body literals as `&amp;` (`&lt;`,
`&gt;`) — the same rule the stringtable note above states, applied to SQF-built bodies too. It
also covers any dynamic value spliced in: a faction name or callsign carrying `&` reintroduces
the fault in whichever tab shows it.

## `for "_i" from A to N step 1` runs `floor(N)+1` times, truncating a fractional bound

**The counter advances in whole steps while `counter <= N`, so a fractional `N` (e.g. `1.5`) stops
at `floor N` and iterates as many times as `to floor N` would. A fractional "multiplier" fed
straight into such a loop is silently rounded down — `1.5` behaves identically to `1`.**

The endpoint is inclusive-by-comparison, not by count; no partial iteration, no warning. It reads
as if the fractional setting works while producing the integer result.

**How to apply:** resolve a fractional multiplier to an integer *before* the loop — e.g.
`_n = floor _m; if (random 1 < (_m - _n)) then { _n = _n + 1 }` for probabilistic rounding — then
loop `to _n`. The OPFOR unit-multiplier options are kept integer (`enemyunitMultiplier` 1/2/3) for
this reason, and `DUWS_fnc_scaleComposition`
(`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf`) rounds before it loops.

## Scheduled scripts share ~3 ms per frame, so a long loop runs at frame rate

**Everything started with `spawn`/`execVM` runs in the scheduled environment, where the engine
gives *all* such scripts about 3 ms per frame between them. A loop whose body costs more than that
slice gets one iteration per frame, so its wall-clock time is set by frame rate and by how many
other scripts compete — not by how much work it does.**

Boot is the worst case: a dozen scripts spawn at once, and a loop calling a mid-cost engine command
per iteration settles at ~one iteration per frame however many iterations. The terrain survey in
`src/duws/server/misc/fnc_moreUrban_locations.sqf` measured ~50 candidates/second across runs of
1144, 3392 and 5909 candidates — a flat rate tracking frame rate, not workload, which is the
signature. Nothing in the SQF hints at it; the loop simply appears to hang.

**How to apply:** batch the work inside `isNil { ... }`, which the engine runs unscheduled and
uninterrupted. It shares the calling scope for reads and writes, so a cursor and output array
declared outside are visible inside and no state threads through a namespace. Bound each batch by a
wall-clock deadline, not an iteration count (per-iteration cost is rarely uniform), and yield
between batches so the server still services clients. `sleep`/`waitUntil` cannot be used inside —
unscheduled code cannot suspend. Batching that survey to a 15 ms budget took it from ~50 to ~259
candidates/second; to tell scheduler-bound from genuinely expensive afterwards, accumulate the time
spent inside the batches and log it against wall-clock — converged means the engine calls are the
floor.

## A shared global mutated as `x = x - c; publicVariable "x"` loses concurrent writes

**`publicVariable` broadcasts an absolute value, and there is no network lock. When two machines
each read a shared global, compute a new value, and `publicVariable` it, the later broadcast
overwrites the earlier — the changes do not add up. Read-modify-write of a networked global from
more than one machine silently drops updates (and can *create* resource from nothing).**

Each machine keeps its own copy; `publicVariable` overwrites every remote copy with the sender's
number. So `x = x - cost; publicVariable "x"` on two clients against a pool of 50 both read 50,
both write 30 — net spend 20 instead of 40, 20 units from nowhere. Local `x = x + n` is atomic (SQF
yields only at suspension points), so the loss is the stale *base* a second machine read before the
first's broadcast landed, and a save persists the corrupted value. Single-player has one machine,
so it only surfaces in co-op. A delta writer fixes the arithmetic but not the authorisation: the
*caller* still decides whether to spend, reading a snapshot the server has moved past — both must
be server-side. See [`economy.md`](../gameplay/economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

**How to apply:** never `publicVariable` a shared resource from a non-authoritative machine. Route
every change through one server-side function taking a signed *delta*
(`x = x + _delta; publicVariable "x"`); callers send it via `[_delta] remoteExec ["fn", 2]` and
never touch the global. The server serialises the deltas as atomic statements, so nothing is lost
whoever fires when — a delta cannot carry a stale base. Command points use this: `fnc_cp_adjust`
(`src/duws/server/warcom/fnc_economy_init.sqf`) is the sole writer of `commandpointsblu1`; the host's
own `publicVariableEventHandler` does not fire for its own broadcast, so that function also
refreshes the on-screen counter locally when `hasInterface`.

## A joining client is sent every `publicVariable`'d global, then its own init overwrites them

**`publicVariable` is JIP-persistent: the engine keeps the last broadcast value and delivers it to
a client joining in progress. A per-client init that then assigns the same global unconditionally
clobbers the delivered value — locally and silently. The joiner disagrees with the session, and the
disagreement becomes everyone's the moment that client broadcasts the global back.**

Delivery happens before the mission's own client init runs, so ordering does not save it: the
joiner receives the team's value and throws it away. Nothing errors — assigning a global that
already holds a value is legal — and on a host or in single-player the fault is invisible. The
damage is the write-back, not the stale copy: a client acting on its wrong copy repeats an action
the team took, and the `publicVariable` that follows pushes the wrong state outward.

**How to apply:** guard every client-side init of a broadcast global with
`if (isNil "x") then {x = default};`, so a delivered value survives and only a fresh session
installs the default. Assigning unconditionally is correct *only* for globals never broadcast — so
the decision to `publicVariable` a global and to initialise it live in two files kept in step by
hand. Here they are not: `client/includes/supports_init.hpp` guards three flags and assigns three
unconditionally while `client/dialog/fnc_request_support.sqf` broadcasts all six
([`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#open-defects)).

## Weather set on the server synchronises itself, so mirroring it into a global is dead state

**`setOvercast`, `setFog` and `setDate` are artificially synchronised: run on the server, the
engine propagates the change to every client and joiner. A client setting them locally is
overridden by the server's value shortly after. Copying the value into a broadcast global adds
nothing and rots the moment anyone forgets to re-broadcast it.**

The failure is quieter than a normal stale global. A `publicVariable`'d weather mirror is usually
broadcast once at init holding a placeholder, then written every cycle by the weather loop without
a second broadcast — so remote readers keep receiving the placeholder while the sky says otherwise.
Nothing errors, and the local machine (server or host) always agrees with itself.

**How to apply:** read the sky through `overcast` and `fogParams`, which return the engine's own
synchronised state on any machine, and never mirror weather into a global. Only one script-driven
weather change runs at a time — starting a `setOvercast` halts an in-flight `setFog` — so the
engine's values are also the only ones that account for a transition cut short. `setRain` is
independent and can run alongside either.

## Waypoint and flight commands are ignored unless the group is local to that machine

**`addWaypoint`, `deleteWaypoint`, `flyInHeight`, `setMass` and `ropeCreate` take effect only on
the machine where the group or object is local. Issued anywhere else they fail silently — no error,
no log, the AI simply never moves. A hosting player is also the server, so the mistake works for
whoever is testing and nobody else.**

Locality follows the creator: a group spawned by a client belongs to that client, and the server
holds only a remote reference. `remoteExec [..., 2]` then delivers the call to a machine that
cannot act on it, and the pair fails both ways — a client-spawned group ordered server-side, and a
server-spawned group ordered from a client. `fnc_helolift` had both at once: it spawned the
transport helicopter client-side then `remoteExec`'d its waypoints to the server, and defined its
two server-side helpers inline in a client-only file, so on a dedicated server those names were
never assigned and the calls hit a nil variable — all invisible to a hosting player.

**How to apply:** decide which machine owns an AI group before writing anything that commands it,
spawn it there, and route every order back to that machine. Server ownership is the safe default
for anything a mission thread steers. A function invoked through `remoteExec` by name must be in
the registry so the receiving machine has it; inline definition only works when caller and target
are the same machine.

## Practice targets ignore damage entirely; `HitPart` fires on the shooter, not the owner

**The `TargetP_*` range targets (`TargetP_Civ_F`, `TargetP_Inf2_F`, `TargetP_HVT1_F` and the rest)
do not process bullet damage. `Hit` and `HandleDamage` never fire on them whatever `allowDamage`
is, so a server-side damage handler waits forever. `HitPart` does fire — but on the machine that
fired the round, not where the object is local.**

Clearing `allowDamage false` changes nothing observable: they have no damage-driven destroyed state
to reach. Detecting a shot means listening for the *impact*, which is what `HitPart` reports — and
its locality is the opposite of every other damage handler: `Hit`/`HandleDamage` run where the
object is local, `HitPart` where the *projectile* came from. An EH added only on the server stays
silent for every shot a client fires, and again works perfectly for a hosting player.

**How to apply:** add the handler on every machine with `remoteExec ["addEventHandler", 0]`
and have its body send the result back to whichever machine owns the state. Pass the object as
the `remoteExec` JIP parameter so joining clients receive it — see
[§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose).
The killhouse does this in `server/killhouse/fnc_createKillhouse.sqf`, bouncing each hit to
`killhouse_srv_target_hit`.

## `setMarkerColor` accepts an inline `#(r,g,b,a)` string, not only a `CfgMarkerColors` class

**A marker colour need not be a class name. A literal `"#(0.5,0,0.5,0.3)"` renders that colour, so
a mission needing shades outside the stock `Color*` set needs no `CfgMarkerColors` block in
`description.ext`.**

The trap is reading the documented signature ("class from `CfgMarkerColors`") and concluding a
`#(...)` string in existing code must be broken — it looks like the `setObjectTexture` procedural
syntax and nothing in the config tree matches it. The civilian town ellipses in
`server/civilian/fnc_civ_init_Tomata.sqf` are painted this way and have always rendered purple; the
config block that would "fix" them is dead weight.

**How to apply:** use the inline form for one-off shades and keep `CfgMarkerColors` for colours the
player picks in the editor (what the `name` field is for). Set translucency with `setMarkerAlpha`
rather than the string's fourth channel — its effect is unconfirmed, and a marker created without
an explicit alpha sits at 1.

## `str` on a string adds literal quote characters, and this mission's marker names carry them

**`str "12345678"` returns the source-code representation — eight digits wrapped in a pair of `"`
characters, not `12345678`. Zone markers are created as `createMarker [str(_markername), _zonePos]`,
so the marker's real name includes those quotes, and every later `setMarkerAlpha` /
`setMarkerColor` / `setMarkerPos` must spell it the same way or it addresses a marker that does not
exist.**

The trap is tidying up: `_markername` is already a `String` from `format`, so the `str` looks
redundant, but creation and access must agree and dropping it on one side silently does nothing.
`setMarkerAlpha` on a name matching no marker throws nothing; the zone stays invisible.

**How to apply:** in `server/init_zones/`, treat `str(_name)` as part of the marker's identity, not
a conversion, and grep the sibling accesses before touching either half. The zone icon and ellipse
are built this way in `fnc_createzone.sqf:45,59` and addressed the same in `fnc_zone_reveal.sqf`
and `fnc_captured.sqf`. Marker names built without `str` — the mission has both conventions — are
addressed without it, so the rule is per-marker.

## `diag_tickTime` counts from process start and is not restored by a savegame

**`diag_tickTime` is Arma's uptime, not the mission's: already in the thousands when a mission
begins, and back to zero when the game is relaunched. `time` is mission time, starts near zero, and
is saved and restored. A stamp from one clock is meaningless against the other, and neither is
"seconds since this mission started".**

The trap is a cooldown written `_last = diag_tickTime` and checked `_cd - (diag_tickTime - _last)`:
correct while the process lives, so it survives every test — but the "never used" default must be a
*negative* sentinel, and any sanity check against the cooldown length sees values as large as the
uptime and reads them as corruption. Resuming an autosave in a fresh session is the real failure:
the saved stamps are from the old process, the clock is back near zero, and every cooldown is
suddenly locked for as long as the previous session ran. Mixing clocks is worse — the rest-heal
cooldown stamps `time`, so writing a `diag_tickTime` value into it locks the action out for the
rest of the mission.

A third clock, the campaign date, is the one a *skippable* cooldown must use. `skipTime` moves
neither `time` nor `diag_tickTime`, so a cooldown on either is untouched by resting or a Zeus
dragging the clock to midnight. `dateToNumber date` is the fraction of the year elapsed and does
move with them; ×8760 it reads as hours. `setTimeMultiplier` scales the campaign date *and* `time`
but not `diag_tickTime` — the same split as `sleep` (mission time) versus `uiSleep`, which is why
nothing holding a real-world duration can use either. Do not fold the year into the figure: SQF's
32-bit floats give a millions-range stamp a precision unit worth more than a short cooldown. Work
within the year and treat a deadline more than one full cooldown ahead as expired, or the year
roll-over wedges it for the campaign.

**How to apply:** pick one clock per cooldown and keep the sentinel, stamp and every check on it.
Prefer the campaign date where resting or time acceleration should shorten the wait; `time` where a
savegame must carry the cooldown and neither resting nor a Zeus may shorten it, as
`shared/functions/fnc_mission_cooldown_left.sqf` does; `diag_tickTime` only where the cooldown is
meant to die with the session. The one anomaly worth repairing is a stamp *ahead* of its clock —
clear it and let the function's default apply, as the monitor in `server/server_init.sqf:434` does.
A stamp far in the past is just an action nobody has used.

## An `Acts_` ambient animation survives death, so the corpse stands and shrugs off hits

**A unit put into an `Acts_*`/`acts_*` ambient animation with a raw `switchMove` stays in it when
it dies: no death transition, no ragdoll, the body holds the pose upright — so incoming fire
produces no visible reaction and the unit reads as invulnerable even though `alive` is already
`false`.**

The illusion is total: the player shoots a prop NPC, nothing moves, and concludes `allowDamage
false` is set. Scripts see the opposite — `alive` and the `Killed` event are unaffected — so the
divergence is purely visual, which is why it survives review, and anything gated on the death
(`waitUntil {!alive _x}`, a `TaskFailed`, an action teardown) fires correctly and looks unprovoked.
`BIS_fnc_ambientAnim` and `BIS_fnc_ambientAnimCombat` install their own handlers to break the
animation, which is why a hand-rolled `switchMove` beside working `ambientAnim` units behaves
differently. A placement-time `enableSimulation false` is a separate mechanism, not the cause: it
suppresses damage while off, but `server/init_hq/fnc_BluHQinit.sqf` re-enables it a moment later.

**How to apply:** posing a unit with a raw `switchMove`, add a `Killed` handler that clears the
move — `[_unit, ""] remoteExec ["switchMove", 0]`, broadcast so every client drops the pose. The HQ
officer and barrier engineer in `server/init_hq/fnc_BluHQinit.sqf` do this. A posed unit left
`allowDamage false` never reaches the failure, so the handler becomes load-bearing only when that
unit is made killable — pair the two changes.

**Broadcast the pose as well as the clear, and key it.** `switchMove` is local both ways, so a
server-side pose dresses the unit only on a hosting player's screen. The death bug forces the clear
to be noticed and nothing forces the set to be, so the set needs a JIP key and the `Killed` handler
must drop that entry — `remoteExec ["", _key]` — or a player joining after the death is handed the
pose for a corpse. `playMoveNow` is local the same way.

**For a held stance rather than a gesture, prefer `setUnitPos`.** When a unit only needs to hold a
posture (crouched, prone, pinned) and not perform a specific `acts_` gesture, `setUnitPos "MIDDLE"` /
`"DOWN"` beats a raw `switchMove`: the stance keeps a living idle animation, and its effect is global
for a server-owned unit, so no per-client broadcast, JIP key, or death handler is needed. A raw
`switchMove` into an `acts_` crouch idle can freeze mid-transition into a visibly wrong half-crouch --
seen in Zeus on a captive squad while the player was still far off. Reset with `setUnitPos "AUTO"`.

## `side` of a dead unit is civilian, so an enemy-corpse test must not read `side`

**Once a unit dies the engine reports it on side `civilian`, whatever it fought as. So `side _corpse
== east` is false on every OPFOR body, and any prompt, loot, or cleanup gated on it silently never
fires -- the units all spawned and died correctly, so nothing in the logs points at the side test.**

The same code reads correctly a frame earlier: a `Killed` handler that runs `side _unit` at the
instant of death can still catch the fighting side, which is why a check that works inside the
handler breaks when the same test is moved onto a settled corpse (a search action, a body sweep).
Caching the side at spawn in a variable works but re-exposes the state to a body-swapping garbage
collector (the AGC mod), which rebuilds a distant corpse and drops its variables.

**How to apply:** identify an enemy corpse by the class config side, not the live side:
`getNumber (configFile >> "CfgVehicles" >> typeOf _corpse >> "side") == 0` (0 = east, 1 = west,
2 = independent, 3 = civilian). It is a pure config read, so it is death-stable and survives the
corpse swap. `client/search/fnc_intel_search_action.sqf` gates the enemy-corpse search this way.

## `enableSimulation` is local, so a server-side freeze leaves clients simulating

**`enableSimulation` only affects the machine it runs on; `enableSimulationGlobal` (server-only)
reaches everybody.** A unit or prop frozen server-side then hard-placed with `setPosWorld` at an
absolute Z sits still on the server while every client keeps simulating it, fails to resolve it
onto ground, and renders it falling — permanently, because the server's position updates keep
putting it back in the air. Props settle and drift per machine, so a base looks subtly different to
each player. Both read as correct to a hosting player, whose client is the server, so the pattern
is invisible in any host-only test.

**How to apply:** use `enableSimulationGlobal` for anything a client also renders, including the
transient freeze used to stop fall damage during placement — the window is short but the client
never gets the matching re-enable, so it never stops simulating. `fnc_duws_deploy` in
`server/misc/fnc_composition_stream_init.sqf` is the reference: global simulation, local
`allowDamage` (damage on a server-local object resolves server-side anyway, and broadcasting it per
prop would cost a JIP entry each).

## An unsimulated object does not fall, so placing one in the air parks it there

**Physics runs only while simulation is on. `setPosWorld` / `setPosATL` on an object with
simulation disabled puts it exactly where told and leaves it — no fall, no settle, no ground
contact. It hangs permanently, and nothing errors.**

Placement code reads identically either way, and the simulation flag is rarely set nearby:
compositions carry it in their stow record (`fnc_duws_stow` writes `simulationEnabled _x`,
`fnc_duws_deploy` replays it), so an object frozen at build time comes back frozen a campaign later.
Anything that places by lifting and dropping — the cure for a static settled into its ground — then
performs the lift and never gets the drop. The prefabs are the source here: each builds its props
and weapons with `enableSimulationGlobal false` and thaws them after, so a weapon the thaw misses is
placed, stowed and redeployed unsimulated for good.

**How to apply:** never assume an object you did not just create is simulated. Where a placement
depends on the object falling, assert `enableSimulationGlobal true` — global, not local, per
[§`enableSimulation` is local](#enablesimulation-is-local-so-a-server-side-freeze-leaves-clients-simulating)
— *after* the position is written, so the fall starts from that position rather than wherever a
frame boundary left the object. `DUWS_fnc_dropStatic`
(`server/init_zones/fnc_zone_stream_init.sqf`) ends on exactly that pair.

## `createVehicle` of an `Item_*` class makes a simulated holder that PhysX flings off a surface

**Spawning a loot item by its `Item_*` ground class (`createVehicle "Item_MobilePhone"`) yields a
`WeaponHolderSimulated`, a PhysX body. Placed on a table or shelf it is ejected off the surface on the
next simulation step and hangs in the air. `enableSimulationGlobal false` does not rescue it: it only
freezes it wherever it floated, per [§an unsimulated object does not
fall](#an-unsimulated-object-does-not-fall-so-placing-one-in-the-air-parks-it-there).**

A `GroundWeaponHolder` has no PhysX. Created in the air it stays, will not fall through geometry, will not
bounce off a table, and — left unfrozen — keeps its inventory openable, so the item is still lootable.
Seat loot in one of these, not in a simulated holder. Fill it on the create frame: an empty holder
self-deletes within about a second. Its cargo takes the *bare* inventory class, not the `Item_*` body, and
whether that class is a `CfgWeapons` item or a `CfgMagazines` round decides the slot —
`addItemCargoGlobal` versus `addMagazineCargoGlobal`.

**How to apply:** place pickup-able loot through `fnc_place_settled`'s `_asLoot` mode
(`server/init_zones/fnc_place_settled.sqf`), which builds the holder, picks the cargo slot by config and
seats it on the anchor. Set-dressing that is never picked up can stay a plain `Land_*` prop on the default
path. `server/debug/fnc_debug_spawn_intel.sqf` is the tool that shows which intel classes have an `Item_*`
body and which cargo slot each takes.

## `moveInGunner` into a simulated static leaves the turret dead; seat it frozen, then thaw

**A static weapon crewed *after* its simulation is enabled keeps a gunner who never traverses: it
fires only down its placed heading and ignores targets to either side. `moveInGunner` while the gun
is still frozen (`enableSimulationGlobal false`) and enable simulation *after*, and the turret
comes up live.**

The turret AI is brought up as the gun transitions from unsimulated to simulated with a gunner
aboard; a gunner added to an already-running gun never gets that pass, so the weapon fires but does
not slew. The symptom is exact and misleading — a crewed, upright, undamaged gun that shoots
straight ahead — reading as a locked turret, not a placement-order bug. `simulationEnabled` is no
help: it reads `true` either way, because the base *is* simulated; only the turret is inert.

The natural order is the wrong one: freezing a static during placement is required (to hold an
elevated row, or lift-and-drop onto uneven ground), and the obvious sequence is thaw-then-seat. The
zone prefabs happened to seat-then-thaw and worked; the drop-and-settle path thawed in
`DUWS_fnc_dropStatic` and seated afterward, so its turrets were dead — which is why the fault showed
only on hardpoints and zone guns re-crewed after streaming (the paths through the drop), while a
freshly built zone looked fine.

**How to apply:** seat every static while frozen, then thaw. `DUWS_fnc_seatStatic`
(`server/init_zones/fnc_zone_stream_init.sqf`) is the single seat step — re-freeze, `moveInGunner`,
thaw — and both crewing routines call it: `DUWS_fnc_crewCompositionStatics` for the prefab build
(thaw in place) and `DUWS_fnc_manStatics` for the stream re-crew and hardpoints (iterative drop).
One seat function is what stops the order drifting again. A crewed gun that fires but will not
rotate is this bug until proven otherwise.

## A hidden terrain object comes back the moment its damage state changes

**A terrain object cannot be deleted, so clearing ground means `hideObjectGlobal`. The engine
replaces a building with a fresh object when its damage state changes, and the replacement is not
hidden — so any explosion near a cleared site re-pops the buildings straight through whatever was
built on top.** `deleteVehicle` returns without complaint on a terrain object, so a pass that
deletes what it finds silently leaves every map building standing.

The replacement arrives through the `BuildingChanged` mission event, whose arguments are the old
object and the new; nothing carries the hidden flag across for you.

**How to apply:** hide a building only where one genuinely has to go, and register it when you do.
The mission clears ground in three places, split on this. A prefab zone centre takes the buildings
with it (`init_zones/fnc_createzone.sqf`) — dropped whole onto a centre picked for density, so a
house left standing lands inside it — and that pass holds the register plus the `BuildingChanged`
handler that re-hides each replacement. The HQ footprint and FOB perimeter go through
`server/misc/fnc_clear_foliage.sqf` instead, filtered to `TREE`/`SMALL TREE`/`BUSH` and needing no
register, because nothing it hides is a building.

The split is a trade: a hide is permanent and unrestorable, so a cleared town keeps invisible houses
for the campaign — worth paying where a composition must fit, not to stop a tree clipping a tent.

`BuildingChanged` is a local event: only the machine that simulated the damage fires it, so a
server-only handler misses a change a distant client caused. Escalation
(`server/warcom/fnc_escalation.sqf`) works around this — every machine registers its own watch
(`fnc_escalation_watch`) and forwards the ruined position to the server-owned counter. The zone-centre
re-hide handler above still runs server-only, so a client blowing up near a hidden building may fail
to re-hide the replacement on that client; that exposure is unfixed.

## A unary command binds tighter than `+`, so `sleep 2 + random 5` sleeps a flat 2 s

**`sleep 2 + random 5` parses as `(sleep 2) + (random 5)`, not `sleep (2 + random 5)`. The delay is
a flat 2 seconds, the randomised part discarded, and nothing appears in the RPT.**

Every unary command — `sleep`, `count`, `random`, `floor`, `str` — sits above `+`, `-`, `*` and the
comparisons in SQF's precedence table, taking only the token immediately to its right. `count _array
+ 1` is `(count _array) + 1`, normally what was meant; `sleep 2 + random 5` is the same shape and is
not, and the `+` then gets Nothing as its left argument. As a bare statement the result is
discarded, so the failure is silent — a play-test RPT with this in a garrison loop logged no error.

**How to apply:** parenthesise whenever a unary command is followed by arithmetic —
`sleep (2 + random 5)`. Staggered-wake loops are where this hides: a delay meant to spread a
garrison's units across frames collapses to one they all share — the thundering herd the stagger
existed to prevent.

## Conditional `count` is `{code} count array`; reversed operands throw, not miscount

**Binary `count` takes the block on the LEFT — `{alive _x} count _units`. Written the other way,
`_units count {alive _x}` is a type error (Code expected left, Array given): the expression aborts
and unwinds the whole function around it — it does not return a wrong number. `findIf` is the
opposite order (`_array findIf {code}`, array left), and reaching for that shape is the slip.**

The cost is that the throw is disconnected from the symptom. A reversed `count` in
`DUWS_fnc_hardpointClearCheck` errored on every 10 s tick and aborted the check before its clear
line, so a mortar / artillery battery never read its guns as destroyed — the visible failure was a
hardpoint that would not clear, with `Error count: Type Array, expected Code` sitting in the RPT
attached to nothing. That branch reads live objects (`DUWS_compositions`, real units), so the
sqf-vm unit suite cannot exercise it and the syntax lint checks bracket balance, not operator
arity: nothing catches the order before a play-test.

**How to apply:** copy the shape from a known-good line — `{alive _x} count _roster`, or the
sibling MINEFIELD branch `{...} count _mines` — rather than writing it from memory beside a
`findIf`. Treat any server clear/stream branch that touches live objects as untestable by the
suite, and read its RPT after play-testing.

## `reverse` returns Nothing, so it cannot be inlined — and `deleteWaypoint` shifts indices

**`reverse` reverses an array in place and evaluates to Nothing, not the reversed array. Any
expression consuming its result — `forEach (reverse _xs)`, `count (reverse _xs)` — is handed
Nothing, so the loop body never runs and no error names `reverse`.**

This bites hardest next to `deleteWaypoint`, the usual reason to want a list backwards. Waypoints
are `[group, index]`, and deleting one renumbers every later one down by one. A forward pass over
`waypoints _group` therefore deletes only every other waypoint — index 0 goes, old index 1 becomes
0, the loop moves to index 1 (old index 2) — so clearing a civilian's circuit leaves half in place
and the group walks off mid-conversation. Both halves fail quietly, neither reaching the `.rpt`.

**How to apply:** bind the array, reverse it as its own statement, then iterate —
`private _wps = waypoints _group; reverse _wps; { deleteWaypoint _x } forEach _wps;`. Iterating
`for "_i" from (count _wps - 1) to 0 step -1` is equivalent and avoids `reverse`. `fnc_civ_panic.sqf`
and the `fnc_civ_moveToPlayerServer` block in `server/civilian/fnc_civ_state_init.sqf` both do the
bind-then-reverse form.

## A waypoint statement never runs if the group cannot reach the waypoint

**`setWaypointStatements` fires only on actual completion. A waypoint the group can never reach —
an exit past the map edge, a position closed to its movement type — is never completed, so its
statement never runs and a `waitUntil` on the flag it sets blocks forever.**

The despawn thread in `fnc_intro_heli.sqf` waited on such a flag: its flyaway waypoint sits `15000`
m from the HQ on a random bearing, off the map for a large share of placements, and AI aircraft turn
back at the boundary, so the group orbits and the statement is never evaluated — the thread never
resumes, leaving the helicopter airborne over the base for the session. `allowDamage false` on the
intro aircraft removes the `!alive` escape hatch that would otherwise cover it.

**How to apply:** treat a waypoint statement as best-effort notification, never the sole completion
signal for cleanup. Gate deletion on something the engine cannot withhold — distance travelled plus
a hard time cap — as `fnc_helotaxi.sqf` does, waiting only for the helicopter to clear 100 m of the
player then deleting on a fixed timer.

## `moveInGunner` reports nothing when it fails, and the man is left standing where he spawned

**`moveInGunner` returns no value and raises no error. A static weapon whose gunner memory point is
inside the ground or clutter refuses the seat, and the only way to know is to read it back off the
gun: `gunner _gun isEqualTo _unit`.**

The failure is quiet in the worst way: the man is not lost, he is standing beside his gun, alive, on
the garrison roster and counted toward the zone's peak. So the zone is weaker than its count says,
capture is denied by a defender defending nothing, and the log records a full-strength garrison — a
deploy line counts what was *raised*, not what was *ordered*, so nothing separates a stranded pair
from one still walking into position. `moveInDriver` / `moveInCargo` / `moveInTurret` are the same.

**How to apply:** never treat the command as the end of the operation. Seat, read it back, and retry
— dropping the gun a little higher each pass, since a gun that lands *onto* its ground takes the
seat a gun sunk *into* it refuses. `DUWS_fnc_seatStatic` and `DUWS_fnc_manStatics`
(`server/init_zones/fnc_zone_stream_init.sqf`) are the read-back and retry; after the last drop the
man is deleted rather than left standing, with a `WARN` naming the gun, and the emplacement stays as
scenery the player can use.

## A physics body spawned clipping geometry takes a lethal collision impulse, not a nudge

**`createVehicle`, or a lift-and-drop `setPosWorld` then thaw, that lands a simulated body overlapping
a building, another vehicle or terrain clutter has the engine resolve the overlap with an ejection
impulse — and the damage that impulse deals can destroy the object outright the frame it appears. It
reads as a vehicle that explodes for no reason the instant it spawns, or an emplacement that wrecks
itself being placed.**

The overlap resolves the frame simulation runs, so the damage lands before any later line inspects
the placement. Healing after the fact — `setDamage 0` once it has settled — races that frame and loses
when one landing carries enough impulse to kill, and cannot help a body already gone. Parked civilian
cars pulled off a carriageway sometimes land inside a roadside house; the drop-and-settle gun path
lands a body on hard ground every attempt.

**How to apply:** hold the object `allowDamage false` across the whole settle window — set before the
position is written, cleared only once it has come to rest — so the same clip merely shoves it, then
restore `allowDamage true` (an object the player can never destroy is its own bug). `fnc_civ_traffic`
(parked cars) and `DUWS_fnc_manStatics` (`server/init_zones/fnc_zone_stream_init.sqf`, the gun drop
loop) both wrap placement this way, which is what let the gun path drop its heal-and-rebuild recovery.

## A static weapon that goes over throws its gunner out and refuses a new one

**A gun knocked onto its side does not keep the man — the engine ejects him — and refuses a new one
as long as it lies there. The emplacement is gone and its defender stands beside it, alive, on
whatever roster counted him as a gun.**

The seat is what most code tests, and it cannot tell an orientation fault from a clearance one: a
gun on its side and a gun sunk into its ground both simply refuse. So the retry that recovers the
second never recovers the first, and lifting between attempts makes it worse — a fallen gun dropped
15 cm lands fallen. Orientation is carried by `vectorUp` alone.

**The fall lands in the seconds after placement, not during it.** A rebuilt static keeps its
simulation, so it is a live physics body settling onto ground it was teleported into, and it goes
over as it settles. Code that places the composition and immediately inspects its guns sees nothing
wrong: every gun standing, every gun crewing, a clean rebuild in the RPT that the player then walks
up to and finds flat. Correct after a settle wait or not at all.

**How to apply:** test the tilt, never the seat — `(vectorUp _gun) select 2`, against vertical.
Vertical, not the ground's normal, which reads backwards on steep terrain: a gun on a 50° slope
scores below threshold and would be laid over to match the hill, while one lying on that hill scores
above and would be left down. Correct with `setVectorDirAndUp` on a `vectorDir` flattened into the
horizontal plane — a gun over its nose has a dir into the ground, and that against a vertical up
leaves the engine two near-parallel vectors and no orientation. `DUWS_fnc_dropStatic` stands the gun
up and drops it; the settle wait that makes the result readable is one per round in
`DUWS_fnc_manStatics` (`server/init_zones/fnc_zone_stream_init.sqf`). Neither half works without the
other. And a lean short of the angle the engine ejects at still keeps its gunner, so a gun that
settled tilted but not flat reads as seated and stands there crewed and askew: crew only a gun that
came to rest genuinely standing (a dot near vertical, well above the on-its-side floor), and re-drop
one that did not — nudged on x/y (`findEmptyPosition`) to hunt ground it stands on, since the spot
that tipped it will tip it again. Snapping the up-vector square (`setVectorUp [0,0,1]`) at the seat
tidies the last degree, but on tipping ground the snap alone is undone the moment it thaws; the
standing bar and the shuffle are what make it hold. `DUWS_fnc_manStatics` reads the lean, shuffles,
and seats; `DUWS_fnc_seatStatic` does the square-and-seat.

## `doStop` outlives the orders it was issued against, and new waypoints do not release it

**A unit under `doStop` ignores its group's waypoints until given a move order of its own. Deleting
the group's waypoints and adding a fresh set does not clear the stop — the new circuit is issued,
visible to `waypoints`, and simply never walked.**

This is invisible at the call site because the stop and the re-order live in different functions.
`fnc_civ_moveToPlayerServer` (`src/duws/server/civilian/fnc_civ_state_init.sqf`) ends on `doStop` so a
civilian called over stands still to be spoken to; every conversation ending then routes through
`fnc_civ_resume` into `fnc_civ_wp_Tomata`, which rebuilds the circuit and nothing more. Each
civilian is its own group leader, so the stop held the whole group — anyone spoken to stood where
the conversation ended for the rest of the town's occupancy. Nothing errors, and the waypoint list
looks correct: the symptom reads as a stuck `CYCLE` waypoint, not a stopped unit.

**How to apply:** pair every `doStop` with an explicit release where orders are re-issued, not where
the stop was set. `doMove` to the first waypoint's position is the release —
`_unit doMove (waypointPosition _first)` — both a move order and the leg the group was about to walk
anyway, so it costs nothing on paths that were never stopped.

`setDriveOnPath` is **not** a release: it commits the driver to a polyline but a preceding `doStop`
still holds the hull halted on the spot. In `fnc_convoy_drive` a `doStop` right before each
`setDriveOnPath` (added on the mistaken belief that formation-following overrides the path order — it
does not, see [§setDriveOnPath commits a driver to the path](#setdriveonpath-commits-a-driver-to-the-path-and-ignores-waypoints-formation-and-combat))
froze one hull per column dead, recovered only by the periodic teleport-snap. If `setDriveOnPath` will
drive the hull, issue it alone — the path order already overrides formation, so the stop buys nothing
and never clears.

## `lock true` stops a player boarding, not an AI disembarking

**`vehicle lock true` blocks the player from getting in or out and blocks AI from getting *in*, but it
does not keep an AI crew *inside*: a unit already aboard still bails when its group goes COMBAT, or when
the vehicle halts, stalls, or is disabled. Locking a car to pin an AI passenger looks right and holds
right up until the first firefight or the first wedge, then the passenger is on foot.**

The HVT convoy needs its commander to stay in his car so the player must stop the car, not chase a man on
foot. `lock true` alone did not hold him. Three layers together do: `lock true` (the player and boarding),
`setUnloadInCombat [false, false]` on the vehicle (the cargo bailing when the group goes COMBAT), and a
`GetOutMan` event handler on the unit that reseats him — `if (alive _unit && alive _veh) then { _unit
moveInCargo _veh }` — for the halted/disabled case the first two miss. `moveInCargo` re-enters past the
lock; gating on `alive _veh` lets a destroyed car eject its crew normally instead of reseating into a wreck.

**How to apply:** to keep an AI in a vehicle for gameplay, do not rely on `lock`. Stop the combat bail with
`setUnloadInCombat [false, false]` and enforce the rest with a `GetOutMan` reseat handler; `lock` only adds
the player and the no-boarding half. Reseat only while the vehicle is alive.

## `cmd [...] remoteExec ["call", 0]` broadcasts the return value, not the command

**A unary command binds tighter than binary `remoteExec`, so `titleText [...] remoteExec
["call", 0]` runs `titleText` on the calling machine and broadcasts what it evaluated to — Nothing.
Every other machine receives an empty payload and shows nothing.**

The missing piece is a pair of braces: `"call"` expects code, so the intended form is
`{titleText [...]} remoteExec ["call", 0]`. Without them the statement still reads as a broadcast
and still runs the command locally, which is why it survives review — and testing, since on a host
or in single-player the local execution produces the intended visual and the dead broadcast is
invisible. Only a dedicated server or a second co-op client exposes it, and nothing reaches the
`.rpt`.

**How to apply:** name the command rather than wrapping code in braces — but `remoteExec` hands the
command an argument *list*, not a single value, so a unary command whose one argument is itself an
array needs a second pair of brackets:
`[["In memory of...", "PLAIN", 3]] remoteExec ["titleText", 0]`. Written flat the command gets only
the first element — `titleText "In memory of..."` — and throws on the type, so the by-name form
fails silently too if the nesting is dropped. That is how the memorial card came to display nothing
while the `titleCut` fades either side, all written nested, kept working.
`src/duws/server/misc/fnc_intro_heli.sqf` is the worked example for both.

## `titleText`'s speed argument fades the new card in; it never fades the old one out

**`titleText [_text, _type, _speed]` times the card being *posted*. Posting an empty string to
clear the screen replaces the visible card instantly then spends `_speed` seconds fading in nothing
— the text snaps off rather than dissolving, and the call looks like a fade that did not take.**

`titleFadeOut _duration` is the only command that fades what is on screen. It takes a plain number,
so `remoteExec` needs one pair of brackets, not the two a titleText payload needs —
`[2] remoteExec ["titleFadeOut", 0]`.

**How to apply:** clear a title card with `titleFadeOut`, and keep the empty-string form only where
it fits — swapping one card for another with no gap. The intro's memorial card in
`src/duws/server/misc/fnc_intro_heli.sqf` is the worked example.

## `BIS_fnc_typeText`'s second and third arguments are screen coordinates, not timings

**The signature is `[lines, x, y, format]`. A hold or typing speed passed in those two slots is
read as a position, so the card types itself off the edge and the call reports nothing wrong.**
`[..., 1, 2]` puts it two full screens below the bottom — indistinguishable from never running.

The timing lever is per line, not per call: each entry of the line array is `[text, format, delay]`,
the delay being how long that line sits before the next types or the block fades. The two callers
show it — `client/misc/fnc_bottom_right_message.sqf:221` passes `-safezoneX` and `0.85` to pin the
date/time OSD bottom-right, `server/warcom/fnc_init_OPFOR_WARCOM.sqf:75` passes the line array alone
and lands centred.

**How to apply:** pass the line array alone unless you mean to move the card, and put a hold in the
line's own third element. A one-line card with no delay misleads: the default drops the line the
instant the last character lands, which reads as a flicker and invites the trailing-argument "fix"
that then hides it altogether.

## `localize` resolves on the machine that runs it, so a broadcast string carries the sender's language

**`localize` reads the stringtable of the machine executing it. Resolving a key server-side and
broadcasting the result sends the *server's* language to every client; broadcasting a code block
that localizes on arrival lets each client resolve its own.**

The two forms look interchangeable and are not:

```sqf
[localize "STR_X"] remoteExec ["hint", 0];                  // server resolves: everyone reads the server's language
[{hint localize "STR_X"}] remoteExec ["BIS_fnc_Spawn", 0];  // each client resolves its own
```

A dedicated server takes its language from its own config, so the first form can hand every player a
language none chose — invisible in single-player and on a host, where the resolving machine is a
player's own.

**How to apply:** this mission resolves server-side nearly everywhere — every `fnc_duws_dialogue`
call site is handed already-`localize`d text — so the `BIS_fnc_Spawn` hint sites are the exception,
not the convention. Do not fold them into the first form without deciding one language for everyone
is what you want: the German, Spanish and Chinese tags stop reaching anyone on a dedicated server
the moment you do.

## `player1` is an editor unit, so `remoteExec`ing to it addresses slot 1 and nobody else

**A `remoteExec` target that is an object runs only where that object is local. `player1` is a unit
placed in `mission.sqm`, not a synonym for "the player", so it resolves to whoever holds slot 1 —
the Game Master seat.**

Nothing at the call site says so, and single-player hides it: there you *are* player1, so a hint to
it behaves like a hint to everyone. Only a second co-op player exposes it, and nothing reaches the
`.rpt`. That is how fourteen side-mission announcements came to be readable by one player in a
four-player session while three other threads sent the identical hint to `0`.

**How to apply:** `player1` is right only where the thing belongs to the Game Master seat — manual
zone placement, HQ placement, the game-master-gated action rows. Anything the team reads takes
`[0,-2] select isDedicated`. The `select` is evaluated where the call is made: `isDedicated` is
false on every client, so the idiom only excludes an interfaceless server when the call site is
server-side, which is why client-side broadcasts keep a plain `0`.

## A comm-menu item id goes stale the moment the item is used

**`BIS_fnc_addCommMenuItem` returns an id that `BIS_fnc_removeCommMenuItem` needs back, but a
`CfgCommunicationMenu` class with `removeAfterExpressionCall = 1` is deleted by the engine the
instant the player calls it. The script that re-adds it gets a *new* id, so any id stored at
purchase time points at nothing — and whether other items' ids survive a removal is undocumented,
since nothing says whether an id is a stable handle or an index into a compacting array.**

Thirteen of DUWS_T's twenty comm classes are declared that way, and each re-adds itself from its own
script when its mission finishes or its cooldown expires (`client/supports/fnc_helolift.sqf`,
`fnc_mapclickuav.sqf`, both taxis, and the rest). Those re-adds used to discard the returned id,
invisible while nothing removed an item: the two High Command aircraft were the only rows with a
sell-back and the only two that kept their id current. The first feature that must remove any other
item finds it cannot.

**How to apply:** never call the two BIS functions directly. `fnc_support_comm_add` and
`fnc_support_comm_drop` (`client/supports/fnc_supports_init.sqf`) own a per-player class → id
record, every re-add routes through the add, and each of the thirteen `expression` fields opens with
`['<class>'] call fnc_support_comm_used` so the engine's own deletion is observable. Removal then
tears the whole slate down in **descending id order** — correct whether ids are handles or indices —
and rebuilds from the record, so the ids that come back are current. The record doubles as the
presence test: an entry exists exactly while the player holds that item, which lets one check refuse
to refund a support away on a mission.

## A `CfgNotifications` description is clipped, not wrapped, past roughly 60 characters

**The notification card's description box is a fixed size. Longer text is cut off mid-sentence with
no ellipsis and no error, so an over-long body reads as a sentence the mission forgot to finish.**

Found on the Mobile HQ release card, whose 87-character body reached the player as "The vehicle is
an ordinary truck again. Any squad leader can designate a new" — the tail vanished exactly where the
important half was. Nothing records it in the RPT, and it is invisible in the stringtable.

The ceiling is a pixel width, not a character count, so it moves with the proportional font: a line
of `l`s survives longer than one of `W`s, and the *title* field's budget is tighter still. **60
characters is the figure this mission writes to.** It was 75, and a 73-character side-mission line
still clipped in play — 60 sits under the narrowest clip seen rather than beside it.

**How to apply:** keep every `BIS_fnc_showNotification` body at or under 60 characters, counting a
`format` placeholder at its longest substitution. Titles are short noun phrases regardless. Anything
needing more room is not a notification: a briefing belongs in the task description (which scrolls),
an explanation in a `hint` (which wraps) — one or the other, never both,
[`player_text_style_guide.md`](../gameplay/player_text_style_guide.md#notification-card-dialogue-and-the-hint-box).

## SQF identifiers are case-insensitive, so `_Varname` and `_VarName` are one variable

**Variable and function names ignore case. `_Varname = "MHQ1"` then a read of `_VarName` is one
variable written and read back, not a write to one name and a read of an undefined second.**

At runtime this is harmless and invisible, which is why mixed spellings survive:
`client/dialog/fnc_MHQ_select.sqf:38-40` writes `_Varname` and reads `_VarName` twice, and works.
The cost lands on anything reasoning about the source as text — a case-sensitive search reports the
write dead and the reads undefined, both wrong. The same applies to command names: the engine
accepts `IF`, `ForEach` and `SetPos` as readily as their usual casing.

**How to apply:** fold case on both sides whenever a tool compares SQF identifiers — a dead-code or
rename pass that skips this produces confident false positives. Reading by eye, treat two spellings
as the same variable; changing one to match the other is a readability edit with no behavioural
effect.

## `getUnitLoadout` pads weapon arrays, so length is not presence

A weapon slot in `getUnitLoadout` is always seven elements when the unit carries that weapon --
`[classname, suppressor, pointer, optics, [mag, count], [mag2, count2], bipod]` -- absent
attachments left as `""` and absent magazines as `[]`. `count _weapon > 3` therefore tests whether
the unit has a *weapon*, never an optic, and `_weapon # 4 # 0` indexes into an empty array whenever
a launcher is carried without a magazine.

Reading an absent attachment compounds it: `configFile >> "CfgWeapons" >> "" >> ...` resolves to a
config with no classes, `configClasses` returns `[]`, and **`selectMax []` returns nil**. Assigning
nil *undefines* the variable, so the failure surfaces lines later as "Undefined variable in
expression" at the point of use, not the assignment that caused it. Test the slot, not the length.

A populated optic reaches the same `selectMax []` a second way: a continuous-zoom scope carries
`OpticsModes` but no `discreteDistance`, so `flatten (_modes apply {getArray (_x >> "discreteDistance")})`
is `[]` even though the modes list is not. Guard the flattened array, not just the modes list.

## The diary ignores `<t>`; structured-text colour there comes from `<font>`

`createDiaryRecord` bodies are structured text, but only a subset of the tags a
`ctrlSetStructuredText`/`parseText` control accepts render in the map's Notes. `<t>` is
**not** one of them -- it is silently dropped, taking its `color` and `size` with it, so
the text still shows but in the default colour. Diary records colour via `<font color='#RRGGBB'>`
instead; `<br/>` and `<img .../>` render in both contexts. Mixing the two is the trap: a
`<t color=...>` copied from a dialog string into a diary body compiles, shows, and stays
uncoloured, which reads as "the colour code is wrong" rather than "wrong tag".

One further mismatch on conversion: `<font size='N'>` is absolute pixels, whereas `<t size='N'>`
is a multiplier of the default. Copying `size='1.15'` or `size='2'` across renders ~1-2px text,
effectively invisible -- drop the size or pick a real pixel value.

## Seat and crew queries (`fullCrew`, `crew`) need a spawned object, not a classname

**`fullCrew` takes a vehicle Object. Handed a classname String it throws `Type String, expected
Object` and returns nothing. A capability check that runs in a menu build has only the classname --
no vehicle exists yet -- so it cannot ask a crewed object how many seats it has.**

When the throw lands inside a `call`ed classifier, the function returns nil rather than a tier, and
a gate built on that verdict fails open: the below-tier test errors instead of refusing, execution
falls through, and the purchase proceeds. One unhandled config-query error silently unlocks
everything it was meant to gate.

**How to apply:** count seats from config, which needs no object -- `getNumber (_cfg >> "hasDriver")
+ getNumber (_cfg >> "transportSoldier") + count ("true" configClasses (_cfg >> "Turrets"))`.
`isKindOf`, `getNumber` and `configClasses` all take a classname; the seat/crew *object* commands
(`fullCrew`, `crew`, `assignedDriver`) do not. `DUWS_fnc_vehTier`
(`src/duws/shared/functions/fnc_ap_gate.sqf`) classifies purchasable vehicles this way.

## `setPos*` seats the model origin, not the model's base, so a swapped class of different height sinks

**`setPosWorld`, `setPosATL` and `createVehicle`'s own placement put the object's model **origin**
[0,0,0] at the height you name -- not its lowest point. Two guns whose origins sit different
distances above their bases end up with their bases at different heights from the same command.**

A composition authors each weapon's Z against a placeholder class in Eden, eyeballed so that
placeholder sits on its surface -- which bakes the placeholder's origin-above-base into the number.
When faction auto-detect swaps the class for the faction's own gun (a ZU-23 for the vanilla static
AA), the Z is reused unchanged. The ZU-23's origin sits higher over its base, so the same Z drives
its base below the surface: the gun spawns underground and reads as never placed. A shorter
substitute floats instead. The drop-and-settle in `fnc_zone_stream_init.sqf` only rescues guns it
later crews, and it lifts from the buried position, so a deep sink never recovers; a gun on a
prefab roof or the FOB roof has no settle at all.

**How to apply:** the base offset is `(boundingBoxReal _obj select 0) select 2` -- how far the
lowest point sits below the origin (<= 0), read off a spawned object. To seat a swapped class's
base where the placeholder's base sat, shift by `baseZ(placeholder) - baseZ(resolved)`; this
preserves the row's real elevation, so a ground gun stays grounded and a roof gun stays on the roof.
`fnc_static_baseZ` (`src/duws/shared/functions/fnc_static_roles.sqf`) probes and caches the offset
per class; `fnc_static_place` there applies the shift only when the class actually changed, so an
unmodded faction is untouched.

## `buildingPos` slots sit above the floor, so a prop seated at that Z by hand floats

**`BIS_fnc_buildingPositions` / `buildingPos` return a building's authored unit-placement points, not
its floor collision surface. Their Z sits a variable gap above the walkable floor, so an object placed
straight onto that Z -- even base-corrected off its own bounding box -- hangs in the air.**

The gap is per building and per slot, not a fixed offset, so it cannot be subtracted out the way a
class's base offset can. Seating a camping table on a laptop-hunt slot by hand left it floating a
hand's width off the floor with the laptop stacked above it.

**How to apply:** drop the *carrier* simulated and let physx fall it the small gap onto the real floor,
then freeze (`enableSimulationGlobal false`). Batch it -- place every carrier, one `sleep`, then freeze
the lot -- so the wait is flat in the object count, not one `sleep` per prop.

Do **not** drop a prop that rides on the carrier (a laptop on a table). A physx body created at the
carrier's origin clips its geometry and takes an ejection impulse (see [§A physics body spawned clipping
geometry takes a lethal collision impulse](#a-physics-body-spawned-clipping-geometry-takes-a-lethal-collision-impulse-not-a-nudge));
left simulated to settle it keeps that impulse and comes to rest on the floor, not the top. A frozen
carrier is not a reliable collider for a live body dropped onto it. Instead seat the carried prop at rest
once the carrier is frozen -- create it above the top, zero its velocity, then freeze it -- via
`fnc_place_settled` (`src/duws/server/init_zones/fnc_place_settled.sqf`), the same seat-at-rest path the
patrol-camp intel uses. Callers:
`src/duws/server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf`,
`src/duws/server/missions/mission_threads/destroy_patrol_camp/fnc_destroy_patrol_camp_mission.sqf`.

## A shell `createVehicle`'d at rest never fuzes

**A projectile round (`Sh_82mm_AMOS` and kin) has an impact fuze, so one spawned stationary has nothing
to arm it and sits inert.** Spawn it just above the target and drive it down with `setVelocity [0, 0, -30]`
so it impacts at once. Callers: `fnc_sabotage_laptop_decoy.sqf`, `fnc_random_event_car_bomb.sqf`.

## `setPosATL` / `object getPos [dist, dir]` measure Z from the terrain, so re-seating a unit on an upper floor drops it to the ground floor

**`setPosATL`'s Z is height above *terrain*, not above whatever surface (floor, roof, bridge) is under
the object. `object getPos [distance, direction]` returns the same terrain-relative frame. So re-seating
a unit that stands on a building's upper floor with either command snaps it to ground-floor height
directly below.**

The carry/drop helper set the informant down with `setPosATL (_carrier getPos [1.2, dir])`; a drop on
an upper floor teleported him to the ground floor beneath the carrier. Fix: don't re-seat him at all --
`detach` leaves a unit at its current world transform, and he is already attached 1 m in front of the
carrier on the carrier's own floor, so he stays there and settles.
`DUWS_fnc_unitDrop` (`src/duws/server/misc/fnc_unit_carry.sqf`).

**How to apply:** to place a unit at a floor-relative point, work in the world/ASL frame --
`modelToWorldWorld` + `setPosWorld`, or `getPosASL` -- never `setPosATL` or the `getPos [dist, dir]`
overload. Better still, when a body is already at the wanted world spot, `detach` and let it settle
rather than issuing any setPos.

## An empty group is never freed, and each side caps at 144 groups

**`createGroup` claims a group slot that lives until it is explicitly freed. Nothing reclaims an
empty group on its own — a group self-deletes only if created with `createGroup [side, true]`
(delete-when-empty) or handed to `deleteGroup`. Each side has a hard cap of 144 groups; once it is
reached `createGroup` and `BIS_fnc_spawnGroup` return `grpNull` silently, so no new AI spawns at
all.**

The napalm strike allocated an empty WEST group per fire object — a stray
`[_bomb] joinSilent createGroup WEST` that grouped a projectile (never a unit, so the group stays
empty) to a throwaway group, 32 per call, none freed. A handful of napalm calls exhausted the
side's slots, after which every group-spawning path — reinforcements, taxis, the HC aircraft,
patrols — failed with no error, surfacing campaign-wide and hours from the strike that caused it.
`client/supports/fnc_arty.sqf`.

**How to apply:** create transient groups with `createGroup [side, true]`, or `deleteGroup _g` once
the last member is gone; never leave a `createGroup` whose members can all die or be deleted without
one of the two. Grouping a non-unit (a projectile, an object) leaks a slot immediately and is always
a mistake. When AI stops spawning mid-campaign with a clean RPT, read `count allGroups` before
suspecting the spawner.

## A script marker is never garbage-collected, so every exit path must delete its own

**`createMarker` makes a marker that lives until `deleteMarker` names it. The engine never reaps one
— not on unit death, not by GC, not at mission end within a session. A path that creates a marker
and returns before its `deleteMarker` orphans it for the rest of the mission.**

The fire-mission strikes drop two target markers up front and clear them in a tail cleanup. The
jet-shootdown early-out (`if (!_veh_alive) exitWith {...}`) released the support slot and returned
without reaching that cleanup, so every air strike — JDAM, laser, cluster, napalm — lost before its
drop left two grey ellipses on the map for good. Nothing errors; the map just accretes stale
markers. `client/supports/fnc_arty.sqf`.

**How to apply:** pair every `createMarker` with a `deleteMarker` that *each* exit path reaches —
clean inside every `exitWith` that can fire after creation, or funnel all paths through one cleanup.
This is the marker analogue of the group-slot leak above: a script-owned resource the engine will
not reclaim. Wrecks and corpses differ — the engine's GC does reap those — so an early-out that also
deletes the downed aircraft is belt-and-braces for the wreck but load-bearing for the markers.

## AI cargo bails a vehicle on contact by default; `setUnloadInCombat [false, false]` holds them

**AI riding as cargo disembarks on its own the moment the vehicle enters combat — takes fire, spots
an enemy, takes damage. It is engine behaviour, not a waypoint, so nothing in the SQF shows it. A
squad trucked toward an objective empties out into the open the instant the first round cracks past,
hundreds of metres short.**

`vehicle setUnloadInCombat [allowCargo, allowTurret]` is the switch; the default is `[true, true]`,
which is the auto-bail. `[false, false]` suppresses it for cargo and turret both, so the group rides
through contact to where the script means to unload them.

**How to apply:** set it once after the men are aboard. It disables only the *automatic* dismount —
the engine's own decision — so once suppressed, script owns every dismount and must provide one:
nothing gets them out otherwise. A truck-borne reinforcement holds cargo with it and dismounts from a
monitor that fires on arrival, on the truck dying, or on a ride-time ceiling
(`server/init_zones/fnc_garrison_reserve.sqf`). Pair it with `moveOut`, not an ordered get-out: a
dead, dying or still-moving vehicle refuses the ordered dismount, and a locked-in squad in a burning
truck is worse than the foot approach the lock was meant to improve — so the escape must be
unconditional.

**`lock true` is the harder hold, for when the occupant must never leave.** `setUnloadInCombat`
suppresses only the *automatic* dismount, and only from the frame it is applied: a unit can still be
ordered out, and nothing holds it in the window between crewing and the call. When keeping the
occupant aboard is the *goal* rather than a step before a scripted dismount, lock the vehicle
(`_veh lock true`) right after `moveIn` — it blocks entry and exit for the whole lifecycle, rides
through a group re-join (lock is on the vehicle, not the group), and does not impede the AI driving
its waypoints. The convoy-hunt HVT rides a locked car for exactly this: an AI commander who bails on
first contact ends up on foot, and the mission is to stop his car, not chase a runner
(`server/missions/mission_threads/target_hvt/fnc_target_hvt_mission.sqf`). The burning-truck caveat
above is the boundary — lock only where a stuck occupant is intended, never where the men must be
able to flee a dying vehicle.

## `setDriveOnPath` commits a driver to the path and ignores waypoints, formation and combat

**A hull under `setDriveOnPath [positions]` drives that exact polyline and nothing else: it overrides
the group's waypoints and formation, and the driver will not manoeuvre or break to fight while the
order stands — turrets still engage, but the driver just drives.** This is the whole point for a
convoy that must reach its goal (`fnc_convoy_drive`: the lead navigates normally, every follower
replays the lead's driven track, so no follower pathfinds its own corner into a wall), but it is
exactly wrong where the hulls must fight. To hand a hull back to native AI, clear the order with an
empty path (`_veh setDriveOnPath []`) and drop any `forceSpeed` cap; the roving patrol does this via
`DUWS_convoy_release`, the driver clears every path on that flag and lets combat AI take over.

Two consequences the driver design turns on. First, a hull whose driver moves to a new group (the HVT
car peeling out) keeps its old path order until something clears it, so the loop that takes the hull
over clears the path the first time it sees it, or the hull traces the wrong track. Second, the lead
must be the **frontmost** hull, because the followers trace the lead's breadcrumb trail: Arma migrates
group leadership on a death to any survivor, and if it lands on a hull at the *back* of the column every
hull ahead would trace the trail backward toward it — the whole column reverses into a jam. So the loop
keeps leadership on the frontmost hull (highest trail progress) with `selectLeader`, with hysteresis so
bunched front vehicles do not swap it every tick. `selectLeader` is safe here only because one loop owns
each group; when two loops shared a group they flipped leadership every tick, which is why the deny tank
now *joins* the running convoy loop instead of getting a second one.

## `group` of a vehicle object does not reliably name the crew's group

**`group _vehicle` is defined for units (men), not for a vehicle hull; on a crewed vehicle it does not
dependably return the driver/crew's group.** To decide which hulls a group drives, work from the men:
`fnc_convoy_drive` walks `units _group` and takes the vehicle of each man that is his vehicle's driver,
so the hull list is built from group membership, never by asking a hull which group it is in. A hull
whose driver has left the group (the peeled HVT car) drops out of the list for free the next tick.

## A runtime error inside a `call`ed function halts the whole calling script, not just the callee

**An unhandled runtime error — a wrong type to a command, a nil where a value is needed — in a
`call`ed helper does not fail that one statement and carry on. It unwinds the entire call chain and
stops the scheduled script that entered the `call`, right at the call site: every statement after
that `call` never runs. The rpt names only the innermost file and line (the helper), so nothing in
the log hints that the caller died too.**

The sharp edge is a mission thread that `call`s a setup helper before its own win/fail monitor loop.
If the helper throws, the thread stops at the `call` — the monitor never spawns, and the mission can
neither be won nor failed. The mission looks dead for no reason a reader can see, because the only
error line points at the unrelated-looking helper.

`setUnloadInCombat` is how this bit here: it takes an **Object** (the vehicle) on the left, not a
Group — the wiki's `groupName` wording misleads. Passing a group throws `Type Group, expected Object`,
and when such a call sat as the first statement of a convoy setup helper `call`ed before the mission's
monitor spawned, the throw killed the whole thread before the monitor existed, so killing the target
did nothing. (The convoy driver `fnc_convoy_drive` now applies it per-vehicle in a `forEach`.)

**How to apply:** apply per-vehicle in a `forEach _vehicles`, never to the group. More generally,
treat any `call` before a load-bearing loop as able to take the whole script with it: keep such setup
type-safe, or the one line you can't see fails the whole mission silently.

## `removeItem` cannot remove a worn uniform, vest, backpack, headgear or goggles

**`removeItem "class"` only reaches loose items — magazines, attachments, things *inside* a
uniform/vest/pack, and assigned kit (map, compass, radio, GPS, watch, NVG, binocular). The worn
container/head/eyewear slots are addressed by their own no-argument commands, so `removeItem` on a
worn uniform is a silent no-op: it returns without error and the uniform stays on. Code that strips
gear generically through `removeItem` therefore leaves clothing behind while looking like it worked.**

Dispatch the five worn slots to their own commands: `removeUniform`, `removeVest`, `removeBackpack`,
`removeHeadgear`, `removeGoggles` — each takes no class (a unit wears one), so guard on the worn class
(`uniform player == _cls`, etc.) to strip only the intended one. `removeUniform`/`removeVest`/
`removeBackpack` also discard the container's contents; there is no keep-contents variant, so re-add
them afterward if they must survive. `DUWS_fnc_strip_n` (`initPlayerLocal.sqf`) does this dispatch,
which is why the arsenal and quick-kit overdraw strip can claw back a whole kit, not just its guns.

## `addMagazine` needs a container; arm a containerless civilian with `addWeaponItem`

**`addMagazine` places the magazine into a worn container (uniform, vest, backpack). Several vanilla
civilian costumes carry no uniform container at all, so the call fails silently — the magazine goes
nowhere and returns without error. `addWeapon` afterwards then finds nothing in inventory to
auto-load, so the weapon is added but chambers empty: the unit holds a gun it cannot fire.**

This bit the informant manhunt, where the fleeing informant (a `selectRandom civ_array` body) drew a
pistol that never shot. Load the magazine straight into the weapon instead, which bypasses inventory:

```sqf
_unit addWeapon "hgun_Rook40_F";
_unit addWeaponItem ["hgun_Rook40_F", "16Rnd_9x21_Mag", true];
```

`addWeaponItem` loads the round into the weapon's muzzle regardless of whether the unit has a
container, so it works on any body class. The `addMagazine`-then-`addWeapon` order is only safe on
units known to wear a container (soldier loadouts); do not trust it for civilian-costume units.

## `time` and `daytime` are different clocks; a world-clock timer cannot be built on `time`

**`time` is real elapsed mission seconds — advanced by the simulation, scaled by `setAccTime`, but
untouched by the day/night multiplier (`setTimeMultiplier`, which this mission exposes as
`time_Multiplier`, 1–60×). `daytime` is the world clock in hours (0–24), which that multiplier speeds
up. So at anything above 1× they diverge: `daytime` runs `time_Multiplier` times faster than `time`.**

Every duration in the mission is meant in *in-game* time, but targets are still stored on the `time`
clock so the many `time > deadline` checks across the mission threads keep working. The `fnc_time_*`
module bridges the two: `fnc_time_roll [minSteps, maxSteps]` rolls an in-game duration in 10-minute
steps; `fnc_time_deadline` turns it into a `time` target by dividing by `time_Multiplier` (real
seconds = in-game seconds ÷ multiplier); `fnc_time_remaining [target]` scales the gap back up by the
multiplier; and `fnc_time_clock [target]` renders "HH:MM" off that. So a "3-hour" deadline is three
*in-game* hours at any multiplier — at 4× it fires in 45 real minutes, and the printed clock is
correct, not a 1× approximation.

The multiplier is baked in when the target is made (`fnc_time_deadline`). That is safe only because
`time_Multiplier` is set once at setup (`server_var_init.sqf` defaults it to 1; the enviro menu picks
it before start) and nothing re-applies `setTimeMultiplier` mid-run. A feature that let the multiplier
change mid-mission would make every already-set target drift — it would need `daytime`-based targets
instead: accumulate `daytime` deltas, adding 24 on a negative delta so the count survives midnight:

```sqf
private _elapsed = 0;         // in-game seconds
private _last = daytime;
while { _elapsed < _targetSecs } do {
    sleep 2;
    private _d = daytime - _last;
    if (_d < 0) then { _d = _d + 24 };   // midnight wrap
    _elapsed = _elapsed + _d * 3600;
    _last = daytime;
};
```

When formatting an hours value into a clock string, round to whole minutes before splitting h:mm —
`floor` on the raw float lands a minute short whenever the fractional hour sits just under an integer
(10.20 h × 60 = 611.99 → `floor` 611 → 10:11, not 10:12). `fnc_time_clock` does this.

## A road segment's `getDir` is not the direction of the road

**`getDir` on a `"ROAD"`/`"TRACK"` terrain object returns the model's own heading, which for most
road pieces is `0`, not the way the carriageway runs. A vehicle placed with `setDir (getDir _road)`
parks broadside across the road and blocks it.**

The direction of travel is the bearing to an adjacent segment, which `roadsConnectedTo` gives:

```sqf
private _cons = roadsConnectedTo _road;
private _dir = if (_cons isEqualTo []) then { getDir _road } else { _road getDir (_cons select 0) };
```

The `getDir _road` fallback covers a dead-end segment with nothing connected — rare, and any heading
is as good as another there. `fnc_civ_traffic` and the informant hunt's decoy cars both place on
roads this way.

Placing on a road is also where cars detonate on spawn: `createVehicle [..., "NONE"]` drops the
vehicle exactly where told, so a point holding a stone wall, a rock, or an already-parked car spawns
the new one clipping it and the collision impulse blows it up. Roadside **stone walls** are the usual
culprit for a car pulled onto the verge to clear a lane — the settle-and-reroll check passes a clip
that stays level, then re-enabling damage detonates it. Reject the point up front with
`nearestTerrainObjects [_p, ["WALL","FENCE","ROCK","TREE"], 4]` and `nearestObjects [_p, ["Car"], r]`
rather than trusting the settle to shove clear.

## A `remoteExec`'d `BIS_fnc_taskCreate` floods `objectFromNetId` every frame the map is open

**`BIS_fnc_taskCreate` `remoteExec`'d to every client serialises the task's owner and destination
across the wire as live references. BIS's map draw then re-resolves them by netId every frame the map
is open, and on the crossed references the resolve is handed an object (or the task itself), throwing
`[BIS_fnc_objectFromNetId]/[BIS_fnc_groupFromNetId] Error: type OBJECT/TASK, expected STRING` for the
task's whole life. Both endpoints throw: the owner (`west`, resolved to the local `player`) as
`type OBJECT ... in player1`, and the destination target as `type TASK ... in Task <id>`. The flood
jams the strategic map's task figure, tooltip, and clicks (including the side-mission picker).**

The last `BIS_fnc_taskCreate` argument is `visibleIn3D` (index 8), not a "sharedTarget" toggle;
flipping it does nothing to the throw. Passing no destination (`[]`) and setting the pin per client
with `setSimpleTaskDestination` does not help either — the pin only re-activates the same crossed
draw. The fix is to not broadcast: call `BIS_fnc_taskCreate` server-side and let the task framework
synchronise it to the owner side's clients, joiners included. A native create keeps each reference as
its own netId string, so a real position destination draws a clean map pin with no flood.
`fnc_missionTaskCreate` / `fnc_missionTaskEnd` create, retire and delete every side-mission task this
way; `fnc_night_horde_event` uses the same native calls.

## `uiNamespace` outlives a mission restart, but spawned loops do not

**Variables in `uiNamespace` survive from one mission to the next in the same game process; scripts
`spawn`ed by a mission are terminated when it ends. So a `uiNamespace` bool used to guard "this loop
is already running" strands set with no loop alive: the first mission of a session spawns the loop
and sets the flag, a restart kills the loop but leaves the flag, and every mission after skips the
respawn.** This silenced the whole subtitle system (`fnc_duws_dialogue_drain`, the sole consumer of
the `uiNamespace` dialogue queues) from the second mission of a session on — only the first run had a
live drain.

Guard on the loop's script handle, not a bool: `scriptDone` reads true once the loop is gone (a
restart) and false while it runs (a JIP re-init inside the same mission, which is the double-spawn the
guard exists to stop). `client_init.sqf` keeps the drain handle in `uiNamespace` and respawns on
`isNull || scriptDone`. The same trap waits for any once-per-session guard kept in `uiNamespace`; a
per-mission guard belongs in `missionNamespace`, which is torn down with the mission.

The persisted *data* is the other half: the dialogue queues also live in `uiNamespace` (deliberately —
they must not serialize into save games), so a restart leaves the previous mission's un-played lines
sitting there, and the freshly respawned drain flushes the whole backlog at once. A respawn must
therefore clear the queues it owns, not just start the loop. Per-mission state in `uiNamespace` needs
an explicit reset on restart; the engine won't do it.

## `BIS_fnc_strategicMapOpen` offsets an icon's click hotspot when the offer position carries a Z

**An offer handed to `BIS_fnc_strategicMapOpen` with a 3D `[x,y,z]` position draws its icon at the flat
`[x,y]` projection but places the icon's clickable hotspot using the full 3D point. A Z away from the
surface slides the hotspot off the drawn icon: a small `|Z|` leaves one corner of the icon dead, a
large one misses the icon entirely. The offer looks present but won't select, and nothing reaches the
RPT — the click never gets as far as the offer's activation code.**

The trap is a finder that snaps an offer onto a `getPos`-derived feature centre — a town, a prefab —
whose Z the picker never sanitises. `getPos` on a coastal town Location returns a below-surface Z
(observed −11 to −32 m), and every finder-relocated offer inherits it while `BIS_fnc_findSafePos`-placed
offers stay flat 2D. So the failure is intermittent by geography: the same mission type is fully
clickable in one town, dead in a corner in the next (the visible tell — part of the icon selects, part
does not), and wholly dead in a third.

**How to apply:** keep every strategic-map offer position 2D. `fnc_mission_findSite` flattens each
finder's returned position to `[x,y]` before it becomes an offer, so a snapping finder
(`fnc_informant_site`, `fnc_recon_observe_site`) cannot leak a Z. The threads derive their own ground
positions later and only ever measure the offer point with `distance2D`, so the Z was dead weight anyway.

## `doSuppressiveFire` needs line of sight and picks the heaviest weapon, so it levels a building

**`unit doSuppressiveFire target` does nothing when the unit cannot see the target, and when it does
fire it chooses whatever weapon the AI rates best for the job -- a rifleman carrying a launcher fires
the launcher.** Suppressing a building the squad is meant to keep intact then either produces no fire
at all (no LOS from the ring) or destroys the objective on the first shot (a rocket into the wall).

The two failures look unrelated in play -- "suppression does nothing" and "the building blew up" -- but
they are the same command behaving as documented: LOS-gated, and free to pick the launcher.

**How to apply:** to force small-arms suppression in a direction with no target or LOS, use
`unit forceWeaponFire [primaryWeapon unit, mode]` instead -- it fires the named weapon regardless of
LOS or target, and naming the primary weapon keeps it to the rifle so no launcher is ever selected.
Point the unit first with `doWatch pos`. Resolve `mode` from the weapon config
(`getArray (configFile >> "CfgWeapons" >> _w >> "modes") select 0`); a `["this"]` modes list means the
mode name is the weapon name. `fnc_rescue_squad_mission.sqf` suppresses the held building this way.

## `forceSpeed` is a ceiling on a native-driven hull but a setpoint on a `setDriveOnPath` one

**`forceSpeed`'s effect depends on who is steering. On a natively-driven hull (`doMove`, waypoints) the
path planner owns the throttle, so `forceSpeed` is only a ceiling: it caps the top speed and
`forceSpeed 0` halts absolutely, but it cannot make a stalled or hesitating driver go, and used to hold
follower spacing it fights the native steering into stop-start twitch. On a `setDriveOnPath` hull the
path itself drives and `forceSpeed` sets how fast along it -- a true setpoint that both closes a gap and
holds one. `limitSpeed` is the soft cap for the native case (the AI drives up to it on its own), and it
is km/h where `forceSpeed` is m/s.**

The wedge is assuming `forceSpeed` behaves the same both ways. A convoy that drove hulls with `doMove`
and capped them with `forceSpeed` for spacing scattered -- each hull pathfound its own route, and the
cap could not pull a hesitating hull forward, so the lead's pace governor eased to a halt waiting for a
column that never formed. Putting every hull on a committed path with `setDriveOnPath` makes
`forceSpeed` a working setpoint and the column holds. The reset is a second trap: `limitSpeed -1` does
**not** remove the limit (a negative value flies a helicopter in reverse); the default cap is
`2 * maxSpeed`, so "no limit" means a value past any vehicle's top speed. A hull capped with
`limitSpeed` (or one that inherited a cap from another system) and never reset crawls for the rest of
the mission.

A third trap hides in that setpoint: `forceSpeed 0` does not just halt a `setDriveOnPath` hull, it drops
it off the committed path back onto native idle. A later positive `forceSpeed` then behaves as the native
*ceiling* (above), which "cannot make a hesitating driver go", so the hull sits commanded-but-stationary
until its path is re-committed. This bites a convoy whenever the column bunches and the spacing controller
clamps a follower to `forceSpeed 0` (rear-end / no-overtake): the hull ahead pulls away, the gap reopens,
`forceSpeed` goes high -- and the follower never moves, because it is now a native-idle hull with a
ceiling, not a pathed hull with a setpoint. It stays dead until the recovery snap. The fix is to re-issue
`setDriveOnPath` to a wedged hull (commanded to move, `speed ~ 0` for a few ticks) rather than trust
`forceSpeed` alone to restart it; a hull driven natively across a gap escapes the trap for free because it
is re-issued its crumb path every few metres of lead travel, and the road hulls need the same soft re-issue
before escalating to a teleport.

**How to apply:** for a tight convoy, put every hull -- lead included -- on a committed path with
`setDriveOnPath` (`fnc_convoy_drive` gives them a self-generated road route from `fnc_convoy_path`, so
nothing is left to native route calculation), and hold the gap with `forceSpeed` (m/s, so `KMH()`
convert): catch up on a real gap, match the hull ahead in station, `forceSpeed 0` at rear-end range.
Where native pathing must stay (no path to commit to), spacing is `limitSpeed`, not `forceSpeed`. Reset
any cap with a large sentinel, never `-1`: `fnc_convoy_drive.sqf` defines `CV_NOLIMIT` (`1e10`) and
clears the limit at hull setup, the whole-column snap, and teardown, so `forceSpeed` alone governs and a
released hull runs uncapped.

## `waypointPosition [group, 0]` reads `[0,0,0]`: index 0 is an implicit placeholder

Every group carries an implicit waypoint at index 0, created with the group. Its
`waypointPosition` reads `[0,0,0]`, not the group's location, and user waypoints added with
`addWaypoint` land at index 1 and up. Code that drives the group off the native waypoint AI never
trips on this -- the engine advances `currentWaypoint` past index 0 on its own, so reading
`waypointPosition [_grp, currentWaypoint _grp]` yields a real point from the first tick.

The wedge is a driver that indexes waypoints ITSELF (because it no longer native-drives the leader, so
`currentWaypoint` never advances): starting its own index at 0 reads `[0,0,0]` forever. A convoy driver
that idled on a `[0,0,0]` target -- correctly refusing to drive to the map origin -- then sat still for
the whole mission, never reaching the real destination at index 1, because idling did not advance its
index past the placeholder.

**How to apply:** when self-managing a group's waypoint index, step past any waypoint whose
`waypointPosition` is `[0,0,0]` before using it, not just on index 0 -- a wrapped CYCLE index or a
completed final leg can also land on an empty slot. `fnc_convoy_drive.sqf` advances its `_legIdx` with
`while { ... waypointPosition [_group, _legIdx] isEqualTo [0,0,0] } do { _legIdx = _legIdx + 1 }` before
reading the target, and only truly idles when the index runs past the whole list (waiting on a waypoint
the mission appends later).

## A shell spawned at rest is inert: it needs impact velocity to detonate

`createVehicle` on an ammo/shell class (`Sh_82mm_AMOS` and the like) makes the projectile object but
does not fire it. Spawned with zero velocity, resting on a surface, its impact fuze never runs, so it
sits there live but inert -- no explosion. Re-placing it with `setPosATL`/`setPos` after creation makes
this worse, not better: the reposition zeroes the velocity again, so even a shell that would have fallen
and hit is pinned stationary. A scripted booby-trap that created the shell on the exact prop position and
then `setPosATL`'d it to that same point produced a dud every time.

**How to apply:** give the shell an impact instead of a resting place. Spawn it slightly above the target
(`+0.5` m) and drive it down with `setVelocity [0,0,-30]` so it strikes at once and detonates; do not
`setPosATL` it afterward. A plain fall from a couple of metres also works but risks spawning inside a
ceiling on an upper floor, so the small-offset-plus-downward-velocity form is safer indoors. Create it on
the server: the blast is then authoritative and its damage replicates to every client, unlike a
client-side `setDamage`.

## `setPos` Z counts building roofs; `setPosATL` / `setPosWorld` do not

`setPos [x, y, z]` measures z above the highest surface at that point -- and a building roof is a
surface. Place a prop or an emplacement with `setPos` on a point that overlaps a building footprint and
it lands z metres above the roof, not the ground. `setPosATL` measures above the terrain, ignoring
objects, and `setPosWorld` (paired with `getTerrainHeightASL`) is absolute terrain height, so both seat
the object on the ground whatever stands there. A side mission that placed its guns with the `setPos`
path stood them on the rooftops of any building its site happened to overlap, while its props -- placed
with `setPosATL` -- sat correctly on the ground a few metres away, so the composition looked split.

**How to apply:** for anything meant to sit on the ground, place it with `setPosATL [x, y, 0]` or with a
terrain-height `setPosWorld`, never bare `setPos`. `fnc_static_place`'s `"world"` mode is the grounded
path (terrain height + the row's own Z) and `"pos"` is the `setPos` one; the zone prefabs and hardpoints
use `"world"`, so any new composition-style placement should too. `setPos` is only right when the point
is known clear of buildings and a terrain-relative height is genuinely wanted.

## `getVariable` with a default returns `nil` on a null object, not the default

`_obj getVariable ["name", _default]` returns `_default` only when `_obj` is a live object missing that
variable. On a **null** object it returns `nil` regardless of the default supplied. A `select`/`findIf`
filter that walks `allUnits + vehicles` -- either can hand back a null reference -- and compares the
result (`_x getVariable ["k", -1] == _token`) then evaluates `nil == _token`, which throws a generic
error. The throw aborts the whole `select`, so a filter that looks total silently returns nothing: a
mission teardown that flagged its units this way flagged none, and nothing was ever cleaned up. The log
line that would have reported the count sits past the throw, so its absence is the tell.

**How to apply:** guard the element before the `getVariable`, short-circuited so it never runs on a null:
`(allUnits + vehicles) select {!isNull _x && {_x getVariable ["k", -1] == _token}}`. The same shape
protects any `findIf`/`count`/`select` over a live-entity census that reads a variable and compares it.

## `setHitPointDamage` never moves `getDammage`, and field repair only touches hit points

**A vehicle carries two decoupled damage stores: the overall hull value read by `damage`/`getDammage`,
and the per-part hit points read by `getHitPointDamage`/`getAllHitPointsDamage`. Writing one does not
recompute the other. `setDamage` writes the hull value (and cascades down to the parts); `setHitPointDamage`
writes one part and leaves the hull value untouched.** A repair loop that only calls `setHitPointDamage`
brings every part up but leaves `getDammage` exactly where it was — the health bar does not move.

The same split governs the engine's own field repair. An engineer repairing a vehicle in the field (no
repair vehicle or point nearby) restores **hit points only, capped** — to 40% integrity bare, ~60% with a
toolkit — and never clears the hull's `getDammage`. Only a repair vehicle/facility with a repair specialist
lifts the cap and repairs the hull fully. So a mission that spawns a derelict with `setDamage 0.8` and then
tests `damage _veh <= 0.5` to detect "the player repaired it" can never win by field repair: the parts come
up, `getDammage` stays 0.8. This is stock Arma, present mod-free.

**How to apply:** to detect field repair, test the hit points, not the hull — mean part damage
(`fnc_veh_comp_damage`, `server/misc/`) against the threshold. To fully repair from script use `setDamage 0`
(the enemy-recovery branch of the deny-armour mission does exactly this). To immobilise a spawned derelict,
kill the engine hit point *after* `setDamage` (`fnc_veh_disable_engine`) — a `setDamage` afterwards would
redistribute the part back to a drivable state.
