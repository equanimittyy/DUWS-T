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
(`src/duws/server/misc/fnc_economy_init.sqf`) are the two halves of that handshake.

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
carried its own `addAction` and, in hardcore, a second intel entry, and the second evicted the
sabotage action, so a joining client could not finish the mission. The laptop carries one entry
again — searching moved onto the player's own action — but the collision returns the moment
anything puts a second entry back on it.

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

Neither namespace is unconditionally reliable, either. Antistasi — which has both in
production — defaults `missionProfileNamespace` **off on Linux servers**, detected with
`(productVersion # 6) isEqualTo "Linux"`, and prints the reason on the control: *"This may
not work correctly on Linux servers due to an Arma bug."* So which namespace is in use is a
runtime decision on a platform the mission does not control.

**How to apply:** treat `missionProfileNamespace` as the store, but name it and its flush
command in one function each so the `profileNamespace` fallback is a one-line change rather
than a sweep. Serialise the payload with `toJSON` (Arma 3 2.18+) and key it by name — a
hashmap tolerates a field being added later, where an array of positions silently misreads
every older save. A dedicated server is the one deployment that can add a real file store
invisibly, because a `-serverMod` extension is not announced to clients and needs nothing
installed player-side; singleplayer and hosted sessions cannot, since the host is the server.
Reasoning: [`../campaign_persistence_plan.md`](../campaign_persistence_plan.md#where-the-save-lives).
Container shape: [`../campaign_save_format.md`](../campaign_save_format.md).

## A variable first assigned inside `while do` does not survive the loop

**`while {...} do {...}` runs its block in a scope of its own. A variable that gets its first
assignment in there is created in that scope and is gone when the iteration ends — so reading it
after the loop is reading an undefined variable, whatever the last iteration put in it.**

The trap is that a loop usually has other variables that *do* survive, which makes the broken one
look like a typo rather than a scoping rule. `server/missions/fnc_missionTargetPos.sqf` returned
five values from after its loop; `_targetpos`, `_Posfound` and `_failSafe` came back because
`params` had declared them in the function's scope, and `_randomPos` and `_Building` came back
undefined because nothing had. Every side mission was then handed an undefined position for its
area marker, its objective icon and its task destination — and `createMarker` at an undefined
position draws nothing and reports nothing, so the only symptom was a blank map for years. The
`.rpt` did carry `Error Undefined variable in expression: _randompos`, unattached to any
subsystem name, which is why it was never read as a mission bug.

**How to apply:** `private _x = <empty value>` above the loop for anything the code after it reads.
`params` counts as that declaration, which is why a params-declared variable behaves differently
from its neighbours in the same block. The same applies to `for do`, `switch do` and `if then`.

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
[`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#zone-and-civilian-siting-defects).

## `ctrlCreate` on a config display ignores the mission's base classes entirely

**`ctrlCreate ["RscButton", idc]` resolves the class against the parent display's own config
before `missionConfigFile`. On a display made from `createDisplay "RscDisplayEmpty"` — a
`configFile` display — that means every control is the *engine's* `RscButton`, `RscFrame` and
`RscStructuredText`, and the mission's overrides in `shared/includes/defines.hpp` never apply.**

The trap is that the two sets differ in ways a screenshot does not obviously blame on the class:
the engine's frames are RobotoCondensed, which is narrower than PuristaMedium and reads as text
that is simply too small, and its structured text is left-aligned where the mission's is centred.
Only the buttons make it unmistakable — the mission paints them
`{0.067, 0.518, 0.729, 0.5}` blue and the engine's come up grey.

**How to apply:** there is nothing to fix at the source; a mission class cannot outrank a
display's own config. Pin what matters after `ctrlCreate` — `ctrlSetFont`, `ctrlSetFontHeight`,
`ctrlSetBackgroundColor`, `ctrlSetTextColor` — and put structured-text alignment in the markup
(`<t align='center'>`) rather than trusting the class. `client/dialog/fnc_HQ_faction_dialog.sqf`
does this in one place for the whole screen, and anything added there has to join it. Controls
declared in a `.hpp` and opened with `createDialog` are unaffected: those inherit from
`missionConfigFile` normally.

## A `createDisplay` screen takes no cursor, and shares no draw order with a dialog beside it

**A display made with `createDisplay` renders controls but does not put a mouse pointer on
screen; `createDialog` does. A screen built the first way is clickable only while a dialog
happens to be open beside it — and the two are separate surfaces whose draw order is not the
order they were created in.**

The trap is that both halves stay invisible while the two surfaces occupy different ground. The
faction setup screen has always been an `RscDisplayEmpty` full of `ctrlCreate` controls with
`startup_hq_placement_dialog` open underneath it, and its combos have always worked — so nothing
said the dialog was carrying the cursor for both. Growing the display's opaque background panel
down over the dialog's two buttons then took them off the screen outright: no error, no log line,
just a green panel where the buttons had been.

**How to apply:** keep everything the player sees on one surface. `client/dialog/fnc_HQ_faction_dialog.sqf`
owns every control on that screen and opens `shared/includes/hq_placement.hpp` empty, purely for
the cursor. A second display is for input, never for pixels that have to sit in a known order
against the first.

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

## A code block sees no locals from where it was written unless it is `call`ed

**SQF blocks are not closures. Scoping is dynamic: a block sees the privates of whatever `call`ed
it, and nothing else. Run it any other way — `spawn`, `execVM`, a saved block the engine invokes
later — and every private in scope where it was written is gone. Where the engine invokes a block
with no arguments, `_this` is empty too, and a global is the only channel left.**

`spawn` is the half that looks safe and is not, because the block is usually written and started
in the same function a line apart. `fnc_civ_garrison.sqf` built its garrison in a local block
reading `_centre` and `_radius` from around it and then `spawn`ed that block: both were nil in the
new thread, so `BIS_fnc_findSafePos` was handed nothing and the town got no garrison. The symptom
is a spawner that quietly places nothing, not an error naming the variable. `fnc_civ_handler.sqf`
shows the correct form a file away — `[_i, _centre, _radius] spawn _fnc_fill`, read back with
`params`.

This is why several globals in the mission look gratuitous and are not. `BIS_fnc_strategicMapOpen`
runs each mission's block with no arguments, so a block cannot be handed the position and name the
search picked for it — the seventeen launcher blocks in `shared/includes/mission_types.hpp` each
carry a hard-coded index instead, and `client/missions/fnc_mission_launch.sqf` turns that index
back into a slot in the `DUWS_missionSlots` global. An index is the one thing such a block can hold
without capturing anything.

The failure is silent rather than loud: a private referenced from a deferred block is simply
undefined at run time, so the block does nothing or throws into a log nobody is reading, while the
same code called inline works perfectly.

**How to apply:** pass everything a `spawn`ed block needs through `_this` and read it with
`params`, or `call` the block instead where it has no reason to run in parallel. When a fix would
delete a global that a deferred block reads, the deferral has to be preserved, not just the value —
replace the global with another global, or with something the block can carry literally. Building
the block text with `format` and `compile` also works and is what `setTriggerStatements` forces
(below), but it costs the compiler and is worth avoiding where a literal index will do.

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
`fnc_site_poller` or `fnc_duws_bluforNear`, where the distance *is* the question and the number is
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

The trap is two independent features that each open the map and wait on a click — base fast
travel and the civilian-zone readout were both reached from the HQ, a pace apart. Nothing warns
you: the second feature works perfectly and the first simply never completes, which reads as the
first feature being broken rather than as a collision.

**How to apply:** the slot is arbitrated by one owner name in `uiNamespace`, not by a flag per mode.
Claim it with `["MODE", _handler] call fnc_mapclick_claim` and hand it back with
`["MODE"] call fnc_mapclick_release` (`server/misc/fnc_mapclick_init.sqf:25`, `:68`). Claiming while
another mode holds the slot is refused *and* said to the player, so a collision surfaces as a message
rather than as a feature that never completes; re-claiming as the current holder succeeds, which is
what lets a multi-stage mode swap handlers between stages. Release restores the background listener
rather than clearing to `""`, because the player-marker system needs the clicked position for the
whole mission, and a release from anyone but the holder is a no-op, so a mode that clears itself both
inside its handler and on the way out cannot disarm whoever claimed in between. A
`waitUntil { !visibleMap }` spawn is still required to release on the player closing the map
(`client/misc/fnc_map_readout_open.sqf:27-35`): the engine gives no callback for it, and a mode
abandoned that way would hold the slot for the rest of the mission. `DUWS_mapReadoutOpen` survives in
that file but only stops the readout being opened twice; it is not a claim on the slot.

## A click handler's `_pos` belongs to the engine, not to the local of the same name beside it

**Handler code handed to `onMapSingleClick` is a string the engine compiles and runs in a scope of
its own, binding `_pos`, `_units`, `_shift` and `_alt` itself. A local called `_pos` in the scope
that installs the handler never reaches it, however connected the two look on the page.**

Three sites declare one and none of them uses it: `client/warcom/fnc_WARCOM_mapclick_assault.sqf:6`,
`client/supports/fnc_mapclickuav.sqf:6` and `client/supports/fnc_mapclickarty.sqf:50` each open with
`_pos = [];` above a handler string that mentions `_pos`. The arty site goes a step further and
passes its local to `format` as `%1` in a template that only substitutes `%2` onwards. All three are
harmless at runtime, and all three are invisible to a text search, which counts the name inside the
string as a use — which is how they survive a dead-code pass that removes the ordinary unused locals
sitting beside them.

**How to apply:** treat a handler string as a separate scope and do not declare the variables the
engine supplies to it; if a handler genuinely needs a value from the installing scope, substitute it
in through `format` or pass it as `_this` via the binary form of the command. Any tool that counts
where a local is used has to blank string literals first, or every one of these reads as live.

## A mission event handler id is a per-event index, not a unique handle

**`removeMissionEventHandler ["EntityCreated", _id]` addresses a position in the list of handlers
registered for that event type, not a handle unique to yours. Store an id and remove it later and
you are betting that the position still means what it meant when you registered — a bet you lose
silently, by unhooking whichever handler now sits there.**

`EntityCreated` is the live case in this mission. Three handlers share it and only one is DUWS's own:
`server/misc/fnc_scanEnemyGear.sqf` reads gear off new enemies, and
`shared/factions/MODERN/AUTODETECT_blufor.sqf` and `AUTODETECT_opfor.sqf` (or
`AUTODETECT_RANDOM_opfor.sqf`) retexture vehicles and redress their crew. Neither autodetect handler
ever removes itself, so nothing in the tree keeps those indices honest, and a wrong id would disable
part of faction detection with no error and nothing in the log — a failure that surfaces as vehicles
quietly wearing the wrong livery, hours from its cause.

The registration order is not obvious from any one file either: the autodetect handlers are added by
`fnc_factions_check` at `server/server_init.sqf:31`, and the gear scan roughly fifteen seconds later
from its own spawn, so the two are separated by boot timing rather than by anything a reader can see.

**How to apply:** prefer a handler that never needs removing, gated internally on a flag, over one
removed by id. Where removal is genuinely required, make sure the id was captured in the same scope
that registered it and cannot outlive the registration — and treat any event type another system
also hooks as reason not to remove by id at all. Whether a savegame preserves these indices is not
established; that is a further reason not to hold one across a save.

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
[`economy.md`](economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

**How to apply:** never `publicVariable` a shared resource from a non-authoritative
machine. Route every change through one server-side function that takes a signed *delta*
and applies it (`x = x + _delta; publicVariable "x"`); callers send the delta via
`[_delta] remoteExec ["fn", 2]` and never touch the global directly. The server serialises
the deltas as ordinary atomic statements, so nothing is lost regardless of who fires when
— a delta cannot carry a stale base the way an absolute can. Command points use exactly
this: `fnc_cp_adjust` (`src/duws/server/misc/fnc_economy_init.sqf`) is the sole writer of
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

There is a third clock, and a cooldown the player is meant to be able to *skip* has to be on it:
the campaign date. `skipTime` moves neither `time` nor `diag_tickTime`, so a cooldown on either is
untouched by the rest mechanic and by a Zeus dragging the clock to midnight. `dateToNumber date` is
the fraction of the year elapsed and does move with them; multiplied by 8760 it reads as hours.

`setTimeMultiplier` splits the three differently: it scales the campaign date *and* `time`, but not
`diag_tickTime`. That is the same split as `sleep` versus `uiSleep`, because `sleep` is built on
mission time — which is why nothing that must hold a real-world duration can use either of them.

Do not fold the year into that figure. SQF numbers are 32-bit floats, so a stamp in the millions
has a unit of precision worth more than a short cooldown. Working within the year instead means the
stamp is stale once the in-game year rolls over — treat a deadline more than one full cooldown
ahead as expired, or the roll-over wedges the thing for the rest of the campaign.

**How to apply:** pick one clock per cooldown and keep the sentinel, the stamp, and every check
on it. Prefer the campaign date where resting or time acceleration should shorten the wait; `time`
where a savegame must carry the cooldown and neither resting nor a Zeus may shorten it, as
`shared/functions/fnc_mission_cooldown_left.sqf` does; `diag_tickTime` only where the cooldown is
meant to die with the session. The one genuine
anomaly worth repairing is a stamp *ahead* of its clock — clear it and let the function's own
default apply, as the monitor in `server/server_init.sqf:434` does. A stamp far in the past is just
an action nobody has used.

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
`server/misc/fnc_composition_stream_init.sqf` is the reference: global simulation, local `allowDamage`, the
latter because damage on a server-local object is resolved server-side anyway and broadcasting
it per prop would cost a JIP entry each.

## A hidden terrain object comes back the moment its damage state changes

**A terrain object cannot be deleted, so clearing ground means `hideObjectGlobal`. The engine
replaces a building with a fresh object when its damage state changes, and the replacement is
not hidden — so any explosion near a cleared site re-pops the buildings that were cleared from
it, straight through whatever was built on top.** `deleteVehicle` returns without complaint on a
terrain object, so a pass that deletes what it finds silently leaves every map building standing
and unmarked.

The replacement arrives through the `BuildingChanged` mission event, whose arguments are the old
object and the new one. Nothing carries the hidden flag across for you.

**How to apply:** hide a building only where one genuinely has to go, and register it when you do.
The mission clears ground in three places, and they split on this. A prefab zone centre takes the
buildings with it (`init_zones/fnc_createzone.sqf`) — the prefab is dropped whole onto a centre
picked for being dense, so a house left standing lands inside it — and that pass holds the register
plus the `BuildingChanged` handler that re-hides each replacement in the old one's place. The HQ
footprint and a FOB perimeter go through `server/misc/fnc_clear_foliage.sqf` instead, filtered to
`TREE`/`SMALL TREE`/`BUSH` and needing no register, because nothing it hides is a building.

The split is a trade, not a hierarchy: a hide is permanent and unrestorable, so a cleared town keeps
invisible houses for the rest of the campaign. That is worth paying where a composition has to fit
and not worth paying to stop a tree clipping a tent. The same caveat as escalation applies:
`BuildingChanged` is a local event, so whether a dedicated server sees it for damage a client caused
is unconfirmed ([KNOWN_ISSUES.md](../../KNOWN_ISSUES.md)).

## A unary command binds tighter than `+`, so `sleep 2 + random 5` sleeps a flat 2 s

**`sleep 2 + random 5` parses as `(sleep 2) + (random 5)`, not `sleep (2 + random 5)`. The
delay is a flat 2 seconds, the randomised part is discarded, and nothing appears in the RPT.**

Every unary command — `sleep`, `count`, `random`, `floor`, `str` — sits above `+`, `-`, `*` and
the comparisons in SQF's precedence table, so it takes only the token immediately to its right
as its argument. `count _array + 1` is `(count _array) + 1`, which is normally what was meant;
`sleep 2 + random 5` is the same shape and is not. The `+` then receives Nothing as its left
argument. As a bare statement the result is discarded, so the failure is silent — a play-test
RPT carrying this construct in a garrison loop logged no error of any kind for it.

**How to apply:** parenthesise whenever a unary command is followed by arithmetic —
`sleep (2 + random 5)`. Staggered-wake loops are where this hides, and it is worth catching
there specifically: a delay meant to spread a garrison's units across frames collapses to one
delay they all share, which is the thundering herd the stagger existed to prevent.

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
`fnc_civ_panic.sqf` and the `fnc_civ_moveToPlayerServer` block in
`server/misc/fnc_civ_state_init.sqf` both do the bind-then-reverse form.

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

## `moveInGunner` reports nothing when it fails, and the man is left standing where he spawned

**`moveInGunner` returns no value and raises no error. A static weapon whose gunner memory point
is inside the ground or clutter it was placed on refuses the seat, and the only way to know is to
read the seat back off the gun: `gunner _gun isEqualTo _unit`.**

The failure is quiet in the worst way, because the man is not lost — he is standing beside his gun,
alive, on the garrison roster and counted toward the zone's peak. So the zone is weaker than its own
count says, capture is denied by a defender who is not defending anything, and the log records a
garrison that deployed at full strength. A deploy line counts what was *raised*, not what was
*ordered*, so nothing in the RPT separates a stranded pair from one still walking into position.

The same applies to `moveInDriver` / `moveInCargo` / `moveInTurret`: none of them report.

**How to apply:** never treat the command as the end of the operation. Seat, read the seat back,
and retry — lifting the gun slightly each pass, since a gun dropped *onto* its ground takes the
seat a gun sunk *into* it refuses. `DUWS_fnc_manStatic`
(`server/init_zones/fnc_zone_stream_init.sqf`) does three passes and then deletes the man rather
than leaving him standing, logging a `WARN` naming the gun; the emplacement stays as scenery the
player can use.

## A static weapon that goes over throws its gunner out and refuses a new one

**A gun knocked onto its side does not keep the man on it — the engine ejects him — and it refuses a
new one for as long as it lies there. The emplacement is gone and its defender is standing beside it,
alive, on whatever roster counted him as a gun.**

The seat is what most code tests, and it cannot tell an orientation fault from a clearance one: a gun
on its side and a gun sunk into its ground both simply refuse. So the retry that recovers the second
never recovers the first, and lifting the gun between attempts makes it worse — a fallen gun dropped
15 cm lands fallen. Orientation is carried by `vectorUp` alone; nothing else reports it.

**The fall lands in the seconds after placement, not during it.** A rebuilt static keeps its
simulation, so it is a live physics body settling onto ground it was teleported into, and it goes
over as it settles. Code that places the composition and immediately inspects its guns therefore
sees nothing wrong: every gun is standing, every gun crews, and the RPT records a clean rebuild
that the player then walks up to and finds flat. Correct after a settle wait or not at all.

**How to apply:** test the tilt, never the seat — `(vectorUp _gun) select 2`, against vertical.
Vertical rather than the ground's own normal, which reads backwards on steep terrain: a gun standing
on a 50° slope scores below any sane threshold and would be laid over to match the hill, while one
lying on that same hill scores above it and would be left down. Correct with `setVectorDirAndUp` on
a `vectorDir` flattened into the horizontal plane — a gun that went over its nose has a dir pointing
into the ground, and that against a vertical up leaves the engine two near-parallel vectors and no
orientation it can derive. `DUWS_fnc_uprightStatic` and the settle wait in `DUWS_fnc_zoneRaiseWorker`
(`server/init_zones/fnc_zone_stream_init.sqf`) are the two halves; neither works without the other.

## `doStop` outlives the orders it was issued against, and new waypoints do not release it

**A unit under `doStop` ignores its group's waypoints until it is given a move order of its own.
Deleting the group's waypoints and adding a fresh set does not clear the stop — the new circuit
is issued, is visible to `waypoints`, and is simply never walked.**

This is invisible at the call site because the stop and the re-order live in different functions.
`fnc_civ_moveToPlayerServer` (`src/duws/server/misc/fnc_civ_state_init.sqf`) ends on `doStop` so a
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

## `titleText`'s speed argument fades the new card in; it never fades the old one out

**`titleText [_text, _type, _speed]` times the card being *posted*. Posting an empty string to
clear the screen therefore replaces the visible card instantly and then spends `_speed` seconds
fading in nothing — the text snaps off rather than dissolving, and the call looks like a fade
that was written and simply did not take.**

`titleFadeOut _duration` is the only command that fades what is currently on screen. It takes a
plain number, so `remoteExec` needs one pair of brackets rather than the two a titleText payload
needs — `[2] remoteExec ["titleFadeOut", 0]`.

**How to apply:** clear a title card with `titleFadeOut`, and keep the empty-string form only for
the case it actually fits — swapping one card for another with no gap between them. The intro's
memorial card in `src/duws/server/misc/fnc_intro_heli.sqf` is the worked example.

## `BIS_fnc_typeText`'s second and third arguments are screen coordinates, not timings

**The signature is `[lines, x, y, format]`. A hold or a typing speed passed in those two slots is
read as a position, so the card types itself off the edge of the screen and the call reports
nothing wrong.** `[..., 1, 2]` puts it two full screens below the bottom — indistinguishable from
the function never having run.

The timing lever is per line, not per call: each entry of the line array is
`[text, format, delay]`, and the delay is how long that line sits before the next one types or
the block fades. Read the two callers together and the shape is unambiguous —
`client/misc/fnc_bottom_right_message.sqf:221` passes `-safezoneX` and `0.85` to pin the date and
time OSD to the bottom right, and `server/warcom/fnc_init_OPFOR_WARCOM.sqf:75` passes the line
array alone and lands centred.

**How to apply:** pass the line array alone unless you actually mean to move the card, and put a
hold in the line's own third element. A one-line card with no delay is the case that misleads:
the default drops the line the instant the last character lands, which reads as a flicker and
invites exactly the trailing-argument "fix" that then hides it altogether.

## `localize` resolves on the machine that runs it, so a broadcast string carries the sender's language

**`localize` reads the stringtable of the machine executing it. Resolving a key server-side and
broadcasting the result sends the *server's* language to every client; broadcasting a code block
that localizes on arrival lets each client resolve its own.**

The two forms look interchangeable and are not:

```sqf
[localize "STR_X"] remoteExec ["hint", 0];                  // server resolves: everyone reads the server's language
[{hint localize "STR_X"}] remoteExec ["BIS_fnc_Spawn", 0];  // each client resolves its own
```

A dedicated server takes its language from its own config, so the first form can hand every player
a language none of them chose. It is invisible in single-player and on a hosted server, where the
machine doing the resolving is a player's own.

**How to apply:** this mission resolves server-side nearly everywhere — every `fnc_duws_dialogue`
call site is handed text that has already been `localize`d — so the `BIS_fnc_Spawn` hint sites are
the lone exception rather than the convention. Do not fold them into the first form without
deciding that one language for everyone is what you want: the German, Spanish and Chinese tags stop
reaching anyone on a dedicated server the moment you do.

## `player1` is an editor unit, so `remoteExec`ing to it addresses slot 1 and nobody else

**A `remoteExec` target that is an object runs only where that object is local. `player1` is a unit
placed in `mission.sqm`, not a synonym for "the player", so it resolves to whoever holds slot 1 —
the Game Master seat.**

Nothing at the call site says so, and single-player hides it completely: there you *are* player1, so
a hint addressed to it behaves exactly like a hint addressed to everyone. Only a second player in
co-op exposes it, and nothing reaches the `.rpt`. That is how fourteen side-mission announcements
came to be readable by one player in a four-player session while three other mission threads sent
the identical hint to `0`.

**How to apply:** `player1` is right only where the thing genuinely belongs to the Game Master seat
— manual zone placement, HQ placement, the game-master-gated action rows. Anything the team is meant
to read takes `[0,-2] select isDedicated`. Note that the `select` is evaluated where the call is
made: `isDedicated` is false on every client, so the idiom only excludes an interfaceless server
when the call site itself is server-side, which is why client-side broadcasts keep a plain `0`.

## A comm-menu item id goes stale the moment the item is used

**`BIS_fnc_addCommMenuItem` returns an id that `BIS_fnc_removeCommMenuItem` needs back, but a
`CfgCommunicationMenu` class with `removeAfterExpressionCall = 1` is deleted by the engine as
soon as the player calls it. The script that re-adds it gets a *new* id, so any id stored at
purchase time points at nothing — and whether the other items' ids survive a removal is
undocumented, because nothing says if an id is a stable handle or an index into a compacting
array.**

Thirteen of DUWS_T's twenty comm classes are declared that way, and every one of them re-adds
itself from its own script when its mission finishes or its cooldown expires
(`client/supports/fnc_helolift.sqf`, `fnc_mapclickuav.sqf`, both taxis, and the rest). Those
re-adds used to discard the returned id, which was invisible while nothing ever removed an item:
the two High Command aircraft were the only rows with a sell-back, and they were the only two
that kept their id current. The first feature that has to remove any other item finds it cannot.

**How to apply:** never call the two BIS functions directly. `fnc_support_comm_add` and
`fnc_support_comm_drop` (`client/supports/fnc_supports_init.sqf`) own a per-player
class → id record, every re-add site routes through the add, and each of the thirteen
`expression` fields opens with `['<class>'] call fnc_support_comm_used` so the engine's own
deletion is observable at all. Removal then tears the whole slate down in **descending id
order** — correct whether ids are handles or indices — and rebuilds it from the record, so the
ids that come back are certainly current. The record doubles as the presence test: an entry
exists exactly while the player is holding that item, which is what lets one check refuse to
refund a support that is away on a mission.

## A `CfgNotifications` description is clipped, not wrapped, past roughly 60 characters

**The notification card's description box is a fixed size. Text longer than fits is cut off
mid-sentence with no ellipsis and no error, so an over-long body reads as a sentence the mission
forgot to finish.**

It was found on the Mobile HQ release card, whose body ran to 87 characters and reached the player
as "The vehicle is an ordinary truck again. Any squad leader can designate a new" — the tail
vanished exactly where the important half was. Nothing in the RPT records it, and it is invisible
in the stringtable, where the string looks perfectly ordinary.

The exact ceiling is a pixel width rather than a character count, so it moves with the proportional
font: a line of `l`s survives longer than a line of `W`s, and the *title* field has a budget of its
own that is far tighter still. **60 characters is the figure this mission writes to.** It was 75,
and a 73-character side-mission line still clipped in play — 75 sat close enough to the observed cut
that a wide string crossed it anyway, which is exactly the margin a character count is supposed to
buy. 60 is under the narrowest clip seen rather than beside it.

**How to apply:** keep every `BIS_fnc_showNotification` body at or under 60 characters, counting a
`format` placeholder at its longest substitution. Titles are short noun phrases regardless. Anything
that genuinely needs more room is not a notification: a briefing belongs in the task description,
which scrolls, and an explanation belongs in a `hint`, which wraps. Which surface a given message
belongs on is a separate decision, and it is one or the other rather than both --
[`player_facing_text.md`](player_facing_text.md#which-surface-a-message-goes-to-and-never-both).

## SQF identifiers are case-insensitive, so `_Varname` and `_VarName` are one variable

**Variable and function names ignore case. `_Varname = "MHQ1"` followed by a read of `_VarName`
is one variable written and read back, not a write to one name and a read of an undefined
second one.**

At runtime this is harmless and invisible, which is why mixed spellings survive in the source:
`client/dialog/fnc_MHQ_select.sqf:38-40` writes `_Varname` and reads `_VarName` twice, and works.
The cost lands on anything that reasons about the source as text. A case-sensitive search for
where a variable is used reports the write as dead and the reads as undefined, and both
conclusions are wrong — the same trap applies to command names, since the engine accepts `IF`,
`ForEach` and `SetPos` as readily as their usual casing.

**How to apply:** fold case on both sides whenever a tool compares SQF identifiers — a dead-code
or rename pass that skips this produces confident false positives. Reading by eye, treat two
spellings of a name as the same variable rather than assuming a bug; changing one to match the
other is a readability edit with no behavioural effect.
