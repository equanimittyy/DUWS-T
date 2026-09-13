# Arma engine gotchas

Engine behaviours that aren't visible in the SQF itself and cost real debugging time.
Each entry states the rule, why the engine forces it, and how to apply it. Add an entry
when an Arma-specific trap — not a plain SQF bug — burns a debugging session. For where
the mission's subsystems live see [`architecture.md`](../architecture.md).

## `remoteExec` to your own machine still runs a frame later

`remoteExec` never runs inline, even targeting the local machine — it queues for the scheduled environment a frame later, and returns no handle. A server-side validate-then-act (`if (pool < cost) exitWith {}` then `[-cost] remoteExec ["fnc_pool_writer", 2]`) is therefore not atomic: a second request in the gap re-passes the check against the undebited pool.

**Fix:** on the server, `call` a server-side function to run inline; reserve `remoteExec [..., 2]` for genuinely remote callers. Send a verdict back to a client by `remoteExec`ing a reply function at the player, not by returning a value (`fnc_pool_try_spend`/`fnc_pool_spend`, `src/duws/server/warcom/fnc_economy_init.sqf`).

## `remoteExec` drops a structured-text (`parseText`) argument

A `TEXT` object (the result of `parseText`) does not serialize across `remoteExec`, so `parsedText remoteExec ["hintSilent", _pl]` arrives empty and the hint draws nothing — with no error logged, even to a local target (the argument still round-trips through the network layer, [§`remoteExec` to your own machine still runs a frame later](#remoteexec-to-your-own-machine-still-runs-a-frame-later)). A plain `STRING` argument crosses fine, which is why the same call site's string hints work and only the `parseText` one is blank.

**Fix:** send the markup as a `STRING` and `parseText` it on the receiver: `[_markup, { hintSilent parseText _this }] remoteExec ["call", _pl]`. The detection meter (`fnc_rescue_hostage_mission.sqf`) builds its bar string server-side and parses per-player on arrival.

## The JIP queue is append-only unless the message carries an ID you choose

`remoteExec`'s third parameter decides what a *later*-joining machine receives:

| Third parameter | Effect |
|---|---|
| absent / `false` | fire and forget, current machines only |
| `true` | append under an engine-generated ID — never referenceable, never removable |
| a string | queue under that ID; a repeat call replaces, `remoteExec ["", id]` deletes |
| an object | queue under the object's `netId`; dropped when the object is deleted |

A bare `true` is not wrong state (an entry naming a deleted object no-ops) but the backlog grows with the campaign and every joiner runs it all — one `addAction` per corpse ever produced. And **an object-keyed ID *is* that object's netId**, so two entries on one object evict each other silently: the sabotage laptop's second intel entry once evicted its own breach action, blocking JIP clients from finishing.

**Fix:** key every entry that repeats. One entry per object: pass the object, it self-cleans. Two that must both survive on one object: suffix a string each (`format ["fob_guards_%1", netId _fob]`). Let eviction happen only when the later entry is *meant* to supersede the earlier. Never queue a transient message (a one-off OSD or hint) at all.

## A scripted `#particlesource` renders only where it was set, unlike a config smoke object

A script-built particle source (`"#particlesource" createVehicle` + `setParticleClass`/`setParticleParams`) is a local visual — it exists only on the machine that ran the commands, so a server-side spawn shows on the host alone. A config-backed emitter (`test_EmptyObjectForSmoke`, `test_EmptyObjectForFireBig`) is the opposite: one global `createVehicle` renders everywhere because its emitter lives in config. The config helpers are a fixed few looks; any other column means a scripted source built on every machine.

**Fix:** `remoteExec` the builder to all present clients and key its JIP entry to the parent object (see [§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose)); compile the builder in `client_init.sqf` (the server runs it too), not a server-only file. There is no free teardown — deleting an object only *detaches* `attachTo` children — and neither the `effects` array nor `fnc_duws_keep` reaps a machine-local source. Have each machine watch its own parent and delete its own source: `waitUntil { isNull _parent }; deleteVehicle _src` (patrol-camp beacon, `fnc_camp_smoke.sqf`).

## Never refresh a config fire object — deleting a burning one puffs smoke

A `test_EmptyObjectForFireBig` (and siblings) burns as long as the object lives, so hold a fire by spawning once and deleting only when the effect ends. Do NOT churn it — `deleteVehicle` on a still-burning one leaves a dying-smoke puff, so respawning on an interval reads as smog, not fire. Spawn with the **command form** `"test_EmptyObjectForFireBig" createVehicle _pos`; the array/placement form creates the object dark (emitter never runs), and the two syntaxes are not interchangeable for these helpers.

**Fix:** spawn once at impact, run the damage loop over the burn window, delete the set when the window closes (napalm `fnc_arty.sqf`, `fnc_molotov_ignite.sqf` — the molotov once regressed to the array form and spawned invisible fires).

## Non-serializable handles must not live in the mission namespace

Never store a `DISPLAY`, `CONTROL`, `SCRIPT`, `LOCATION`, or other handle in a `missionNamespace` global — the mission namespace is saved and handles don't serialize, so the engine rejects the write (*"Variable X does not support serialization..."*) on assignment or at next save. Booleans/numbers/strings/arrays of those are fine. `disableSerialization` grants no exception — it only skips a script's local (`_underscore`) variables and mid-script saves.

**Fix:** keep display/control references in `uiNamespace` (never saved). Read with a default and null-check — `isNull (uiNamespace getVariable ["myDisplay", displayNull])`, which also detects a dialog closed elsewhere (faction selector, `fnc_factionSelector` in `src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## Nothing in SQF writes a file, and an extension cannot be shipped inside a mission PBO

The only durable write targets a mission reaches on its own are the profile-backed namespaces (`profileNamespace`, `missionProfileNamespace`) and the one-way clipboard (`copyToClipboard` writes, nothing reads back). There is no file-write command, and `callExtension` is out because the engine resolves an extension only from a loaded mod folder or the game install — never inside a PBO. Every file-persistence library is a compiled extension for this reason. Even the namespaces aren't unconditionally reliable: Antistasi defaults `missionProfileNamespace` **off on Linux servers** (`(productVersion # 6) isEqualTo "Linux"`).

**Fix:** treat `missionProfileNamespace` as the store, naming it and its flush in one function each so the `profileNamespace` fallback is a one-line change. Serialise with `toJSON` (Arma 3 2.18+) and key by name — a hashmap tolerates a field added later where a positional array misreads older saves. Only a dedicated server can add a real file store invisibly (`-serverMod` extension); SP and hosted cannot, since the host is the server. Reasoning: [`../campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#where-the-save-lives); shape: [`campaign_save_format.md`](campaign_save_format.md).

## A variable first assigned inside `while do` does not survive the loop

`while {...} do {...}` runs its block in its own scope; a variable first *assigned* in there is gone when the iteration ends, so reading it after the loop reads an undefined variable. Loop-neighbours declared by `params` in function scope *do* survive, so the broken one looks like a typo. `fnc_missionTargetPos.sqf` returned `_randomPos`/`_Building` undefined this way (the others came back because `params` declared them), handing every side mission a blank position — a blank map for years, its only trace an unattached `Error Undefined variable in expression: _randompos`.

**Fix:** `private _x = <empty value>` above the loop for anything the code after reads; `params` counts as that declaration. Same for `for do`, `switch do`, `if then`.

## `params` on a single-array argument destructures it, not binds it

`X call code` sets `_this` to `X`. When `X` is one array and the block opens with `params ["_a"]`, `params` walks the array and binds `_a` to `X select 0` — the first element, not the whole array. A callback whose single argument is itself an array (`[_pos, _dir, _centre] call _fn` read with `params [["_anchor", []]]`) gets `_anchor = _pos`, then reads `_pos`'s x as the position (`BIS_fnc_findSafePos`: `type SCALAR, expected ARRAY, on index 0`).

**Fix:** when a `call`/`spawn` block's entire argument is one array you want whole, use `private _a = _this`. Keep `params ["_a", "_b", ...]` for a list of distinct arguments to spread.

## A typed `params` template logs to the RPT on mismatch, then falls back

`params [["_v", default, [typeTemplate]]]` does not *silently* coerce a wrong-typed value — it writes a "Type X, expected Y" RPT error first, then uses the default. So a type template is wrong for a slot whose type legitimately varies: a `["_role", "", [""]]` meant to absorb a bool quietly instead logged one error per gun per site.

**Fix:** read a legitimately-varying slot untyped (`["_role", ""]`) and coerce by hand — `if !(_role isEqualType "") then { _role = "" }`.

## `exitWith` exits the nearest loop or call scope, not the enclosing if/then

Inside a loop, `if (cond) exitWith {...}` terminates the whole loop — `if/then`/`switch` are transparent to it. `exitWith` unwinds to the nearest scope made by a loop (`while`, `for`, `forEach`, `count`) or by `call`/`spawn`/`execVM`. So `if (a) then { if (b) exitWith {...} }` expecting to abandon only the inner block exits the loop instead — a loop meant to retry runs once and quits.

**Fix:** skip-and-retry an iteration with `continue` (or fall off the body's end); reserve `exitWith` for stopping the loop. The zone locator hit this ([`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#zone-and-civilian-siting-defects)).

## `ctrlCreate` on a config display ignores the mission's base classes entirely

`ctrlCreate ["RscButton", idc]` resolves the class against the parent display's config before `missionConfigFile`. On a `createDisplay "RscDisplayEmpty"` every control is the *engine's* base class, so mission overrides in `shared/includes/defines.hpp` never apply — engine frames are RobotoCondensed (reads too small), structured text left-aligned not centred, buttons grey not the mission's `{0.067,0.518,0.729,0.5}` blue.

**Fix:** nothing at the source can outrank a display's own config. Pin what matters after `ctrlCreate` (`ctrlSetFont`, `ctrlSetFontHeight`, `ctrlSetBackgroundColor`, `ctrlSetTextColor`) and put alignment in markup (`<t align='center'>`), as `client/dialog/fnc_HQ_faction_dialog.sqf` does once for the screen. Controls declared in `.hpp` and opened with `createDialog` inherit from `missionConfigFile` normally.

## A `createDisplay` screen takes no cursor, and shares no draw order with a dialog beside it

`createDisplay` renders controls but puts no mouse pointer on screen; `createDialog` does. A screen built the first way is clickable only while a dialog is open beside it — and the two are separate surfaces whose draw order is not their creation order. Growing the faction display's opaque panel down over `startup_hq_placement_dialog`'s two buttons took them off-screen with no error or log.

**Fix:** keep everything the player sees on one surface. `fnc_HQ_faction_dialog.sqf` owns every control and opens `shared/includes/hq_placement.hpp` empty, purely for the cursor. A second display is for input, never for pixels that must sit in known order against the first.

## Structured-text controls need a parsed object, not `ctrlSetText`

Set a `CT_STRUCTURED_TEXT` (type 13 / `RscStructuredText`) control with `ctrlSetStructuredText (parseText "<t ...>...</t>")`, never `ctrlSetText` — the latter stores the string verbatim, so `<t>` markup renders as literal on-screen text, silently. Only `parseText` turns markup into the object the control draws.

**Fix:** `_ctrl ctrlSetStructuredText (parseText _markup)` to set, `parseText ""` to clear (`fnc_factionSelector`, `src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## `ctrlSetStructuredText` has no IDC form, and the parse error voids the whole file

`ctrlSetStructuredText` exists only as `control ctrlSetStructuredText text` — there is no `[idc, text]` overload (unlike `ctrlSetText`/`ctrlEnable`/`ctrlShow`/`lb*`), and writing one fails at *compile* time. `compile preprocessFileLineNumbers` on such a file logs `Error Missing ;` then hands back a no-op block, so every function the file defines silently returns without running, and the caller falls over a mile from the cause. Registration files compile dozens of paths, so the one useful RPT line sits at server-init far above the symptom.

**Fix:** take the control first — `(_display displayCtrl 8603) ctrlSetStructuredText parseText _markup`; in an EH read the display the `onLoad` stashed (`uiNamespace getVariable ["duws_faction_confirm_display", displayNull]`). Patterns in `client/dialog/fnc_faction_confirm.sqf`, `fnc_faction_prompts.sqf`. When a setup screen never appears, grep the RPT for `Error Missing ;` first.

## Listbox rows show `<t>` markup literally; `addAction` titles render it

`lbAdd`/`lbSetText` store row text verbatim, so `<t color=...>...</t>` shows as literal tag characters; `addAction` titles are drawn as structured text and render the same markup. So a label fine as a scroll action (e.g. `STR_DUWS_T_HIRE_PMC`, colour baked in) breaks in a listbox. Row colour has its own channel, `lbSetColor [idc, index, [r,g,b,a]]`.

**Fix:** strip `<...>` tags before `lbAdd` and colour the row via `lbSetColor` (reusable menu `fnc_open_action_menu`, `src/duws/client/dialog/fnc_open_action_menu.sqf`).

## `lbSort` by IDC needs a direction, and the missing one aborts the whole fill

The array form is `lbSort [idc, "ASC" | "DESC"]`; `lbSort [idc]` throws "1 elements provided, 2 expected" — a runtime error, not a no-op. An uncaught error halts the rest of the code block, so a fill that sorts one list partway then populates more loses everything after the bad sort (later lists empty, headers not updated), reading as "the listboxes are broken".

**Fix:** always give `lbSort` its direction. Bare-IDC commands act on the top display, so a multi-list fill passes `[idc, "ASC"]` for each.

## `BIS_fnc_showSubtitle` is one slot: the next call wipes the line mid-read

A second `BIS_fnc_showSubtitle` replaces the screen immediately — there is no queue, and it reports neither hold duration nor clear time. `fnc_arty.sqf:36`/`:49` post two lines a frame apart, and supports are independent comm items with no shared lock, so two narrating at once is ordinary and only the second is read.

**Fix:** never call it from more than one place. `fnc_duws_dialogue` queues, `fnc_duws_dialogue_drain` (`src/duws/client/misc/`) holds the single call and spaces lines by `1.5 + 0.045 × length` seconds; a lint pins the call to that file. Erring short on the guessed duration is safe (release early → clean replace; late → blank screen).

## Duplicate `<Key ID>` in stringtable.xml resolve to one definition, silently

A `STR_` ID repeated in `src/stringtable.xml` loads without error, but the engine keeps one definition and the other copies are dead: editing a dead copy changes nothing, and reordering keys can flip which wins (IDs resolve globally across `<Container>` sections — the split is navigation only). When two copies differ in more than tag order, one string silently never displays.

**Fix:** keep the table deduplicated. When a string edit appears to do nothing in-game, grep for a second `<Key ID>` with the same ID and fold it into one copy.

## A config class opened with a body twice at one scope warns, and the RPT line points past it

Two `class Foo { ... }` blocks at the same scope in the merged `description.ext` (the include chain counts as one file) log `.Foo: Member already defined`. The engine merges them, but the reported line is the token *after* the second block, not the block itself — an `#include` opening `class CfgMagazines` colliding with an inline one reported `line 53`, which was the following `class CfgWeapons`. The class path (`.CfgMagazines`) is the real lead.

**Fix:** keep one bodied block per top-level config class across the whole include chain; when two owners both add members, fold them into one block. Read the class named, not the line cited.

## `format` discards surplus arguments, so a missing `%N` never errors

`format` matches placeholders positionally and drops any argument with no matching `%N` — no error, no warning. A string referencing fewer placeholders than passed renders plausible-but-wrong forever; a *duplicated* placeholder (`"%1 %2-%2"` on `[_name,_d1,_d2]`) hides best. The boat taxi carried eight `format` calls handing three args to placeholder-less strings (all three names undefined in that file), formatting nothing with no complaint. Localisation multiplies exposure — each language holds its own copy.

**Fix:** treat the placeholder set as a contract with *every* language variant. When editing a `%N` string, grep its `format[...]` call, count args, confirm the highest `%N` matches in each language tag.

## Config text is shown verbatim, so a `%N` in it reaches the player unsubstituted

A `$STR_` reference in config (`CfgDebriefing` titles/descriptions, action names, `displayName`) is resolved and displayed as-is — no call site hands it arguments, so a placeholder renders as literal `%1`. This bites when one key serves both a script and config: the campaign's losing text is formatted with the map name in a hint (`server/misc/fnc_capture_zones_task.sqf`) and shown on the outro card (`shared/includes/debriefing.hpp`); the moment the script gained a `%1`, the card read "%1 is in ruins".

**Fix:** a `%N`-bearing key belongs to script call sites only. When config needs the same sentence, give it its own placeholder-free key.

## `localize` on a finished sentence looks it up as a key and speaks nothing

`localize` only translates a stringtable ID; handed anything else it treats the whole string as a key, misses, logs `String <text> not found`, and returns no usable line — it is not a passthrough. `fnc_mission_finish` localises its line argument, so callers hand it a *key*; an escort mission that baked the town name into its close line and passed the finished sentence to finish went silent (rep and reward, later in finish, still ran and masked it).

**Fix:** a line needing a runtime `%N` is finished text — build and speak it at the call site (`fnc_duws_dialogue`) and hand finish `[]`. Reserve any `localize`-wrapping helper for bare keys.

## A code block sees no locals from where it was written unless it is `call`ed

SQF blocks are not closures; scoping is dynamic. A block sees the privates of whatever `call`ed it and nothing else — run it via `spawn`/`execVM`/an engine-invoked saved block and every enclosing private is gone, and where the engine invokes it with no arguments `_this` is empty too. `fnc_civ_garrison.sqf` `spawn`ed a block reading `_centre`/`_radius` from around it; both were nil in the new thread, so the town got no garrison (correct form: `[_i, _centre, _radius] spawn _fnc_fill` read with `params`, as `fnc_civ_handler.sqf` does). This is why the launcher blocks in `shared/includes/mission_types.hpp` each carry a hard-coded index (`BIS_fnc_strategicMapOpen` runs them argumentless) — an index is the one thing such a block can hold without capturing.

**Fix:** pass everything a `spawn`ed block needs through `_this`/`params`, or `call` it. When a fix would delete a global a deferred block reads, preserve the deferral, not just the value. Building text with `format`+`compile` works (and `setTriggerStatements` forces it) but costs the compiler — avoid where a literal index will do.

## A trigger statement is a string, so anything formatted into it is a float round trip

`setTriggerStatements` takes source text, not a closure — a captured local is written in with `format`, and a number through a string and back is not guaranteed to compare equal. It looks right in a log line; it fails only against `==`/`isEqualTo`/`in`. `fnc_createzone.sqf` formats `_zonePos` into the capture trigger, so `WARCOM_zones_controled_by_BLUFOR` holds a text-derived position while the zone's code holds the original — equality is a coin toss on surviving digits.

**Fix:** prefer `thisTrigger setVariable` over interpolation — the statement reads the object it is attached to, value never becomes text. Where a position must match one that went through a statement string, match by distance (`_a distance2D _b < 1`), not equality; zones are hundreds of metres apart. Such a match is an *identity* test, not a proximity one (the tolerance is float slop, unlike a real gameplay range) — comment the difference so the next reader doesn't fold it in with `fnc_site_poller`/`fnc_duws_bluforNear` ranges.

## `hint` renders beneath the open map, so map-phase prompts are invisible

A `hint`/`hintSilent` issued while the map is open (`forceMap`/`openMap`) draws into the hint box on the mission UI layer, *under* `findDisplay 12`. It fires (sound plays) but is never seen — so a "click on the map" instruction before an `onMapSingleClick` wait looks broken. `titleText`/`cutText` share the problem.

**Fix:** draw the prompt on the map display itself — a static `RscStructuredText` control on `findDisplay 12` set with `ctrlSetStructuredText` (static controls are click-transparent, so the `onMapSingleClick` still fires). `fnc_map_prompt` (`src/duws/client/dialog/fnc_map_prompt.sqf`); pass `""` to clear before `openMap [false, false]`.

## `onMapSingleClick` is one global slot: the next installer steals the previous one's click

There is exactly one map-click handler per machine; a second `onMapSingleClick` overwrites the first with no error and no read-back. Two features that each open the map and wait on a click (base fast-travel and the civilian-zone readout) collide — the second works, the first waits forever, reading as the first being broken.

**Fix:** arbitrate the slot by one owner name in `uiNamespace`. Claim with `["MODE", _handler] call fnc_mapclick_claim`, release with `["MODE"] call fnc_mapclick_release` (`server/misc/fnc_mapclick_init.sqf:25`, `:68`): claiming while another holds is refused *and* said to the player; re-claiming as holder succeeds (lets a multi-stage mode swap handlers); release restores the background listener (the player-marker system needs the clicked position all mission) and a release from a non-holder no-ops. Still spawn `waitUntil { !visibleMap }` to release on the player closing the map (`client/missions/fnc_map_readout_open.sqf:27-35`) — the engine gives no callback.

## A click handler's `_pos` belongs to the engine, not to the local of the same name beside it

Code handed to `onMapSingleClick` is a string the engine compiles and runs in its own scope, binding `_pos`/`_units`/`_shift`/`_alt` itself. An installing-scope local called `_pos` never reaches it. Three sites declare `_pos = [];` above a handler string mentioning `_pos` and none use it (`fnc_WARCOM_mapclick_assault.sqf:6`, `fnc_mapclickuav.sqf:6`, `fnc_mapclickarty.sqf:50`) — harmless, but a text search counts the name inside the string as a use, so they survive a dead-code pass.

**Fix:** treat a handler string as a separate scope; don't declare the engine-supplied variables, and substitute an installing-scope value via `format` or pass it through `_this`. Any tool counting local uses must blank string literals first.

## A mission event handler id is a per-event index, not a unique handle

`removeMissionEventHandler ["EntityCreated", _id]` addresses a *position* in that event's handler list, not a handle unique to yours — remove by a stored id later and you unhook whichever handler now sits there. `EntityCreated` has three sharers, one DUWS's (`fnc_scanEnemyGear.sqf`) plus two autodetect retexture handlers (`AUTODETECT_blufor.sqf`/`_opfor.sqf`) that never remove themselves, so nothing keeps the indices honest and a wrong id silently breaks faction detection (vehicles wearing wrong livery, hours from cause). Registration order isn't visible either.

**Fix:** prefer a handler that never needs removing, gated internally on a flag. Where removal is required, capture the id in the same scope that registered it, and treat any event type another system hooks as reason not to remove by id at all. Whether a savegame preserves these indices is unestablished — a further reason not to hold one across a save.

## Diary records display newest-first, so add them bottom-up

`createDiaryRecord` prepends: the record created last draws at the TOP. Record text is parsed as structured text (`<br/>`, `<t>`, `<font>` work), but in `stringtable.xml` the markup must be entity-escaped (`&lt;br/&gt;`) or the XML parser eats the tag.

**Fix:** keep entries in an array in display order and `reverse` once before the `forEach`, so the source reads the way the player sees it (`fnc_duws_help.sqf`). See also the diary `<font>` and escaping entries below.

## An unescaped `&`/`<`/`>` in a diary body blanks the body but leaves the title

Diary record text is structured-text XML, so a bare `&`, `<` or `>` anywhere in the body voids the whole body parse. The title is plain text and still shows, so the symptom is a tab that lists in the subject but renders empty. A header like `"FORCES, ECONOMY & WORLD"` compiles, the tab appears, and the `&` opens an entity that never closes.

**Fix:** escape body literals as `&amp;`/`&lt;`/`&gt;` — including any dynamic value spliced in (a faction name or callsign carrying `&`).

## `for "_i" from A to N step 1` runs `floor(N)+1` times, truncating a fractional bound

The counter advances in whole steps while `counter <= N`, so a fractional `N` (e.g. `1.5`) stops at `floor N` — `1.5` behaves identically to `1`, with no warning. A fractional multiplier fed straight into such a loop is silently rounded down.

**Fix:** resolve a fractional multiplier to an integer before the loop — e.g. `_n = floor _m; if (random 1 < (_m - _n)) then { _n = _n + 1 }` for probabilistic rounding — then loop `to _n`. OPFOR unit multipliers are kept integer for this reason; `DUWS_fnc_scaleComposition` (`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf`) rounds before it loops.

## Scheduled scripts share ~3 ms per frame, so a long loop runs at frame rate

Everything `spawn`/`execVM`'d runs in the scheduled environment, where the engine gives *all* such scripts ~3 ms per frame between them. A loop whose body costs more than that slice gets one iteration per frame, so its wall-clock is set by frame rate and script contention, not by work done. The terrain survey (`fnc_moreUrban_locations.sqf`) measured ~50 candidates/second flat across runs of 1144/3392/5909 — a rate tracking frame rate, the signature; the loop just appears to hang.

**Fix:** batch the work inside `isNil { ... }`, which runs unscheduled and uninterrupted and shares the calling scope for reads/writes. Bound each batch by a wall-clock deadline, not an iteration count, and yield between batches so the server still services clients. `sleep`/`waitUntil` cannot be used inside. Batching that survey to a 15 ms budget took it ~50 → ~259/second; accumulate time-in-batches vs wall-clock to tell scheduler-bound from genuinely expensive.

## A shared array written from two scheduled scripts is consistent only across a suspension-free section

Scheduled SQF is cooperative: one script runs at a time, and control passes only at a suspension point (`sleep`, `waitUntil`, a yielding `call`). A read-modify-write on a shared array is therefore atomic *only if no suspension falls between the read and the write*. OPCOM belief is written by the perception loop (`fnc_opcom_perception_run`, which runs all its sensors inline) and, concurrently, by a `remoteExec`'d debug OP burst (`DUWS_fnc_hardpointOPBurst` from the dev map-click, which lands in its own scheduled thread on the server); it stays consistent only because every belief stamp (`findIf`, then `pushBack`/`set` across the four parallel `DUWS_opcom_belief_*` arrays) runs suspension-free.

**Fix:** keep each belief write one unbroken block. A `sleep`/`waitUntil` between the `findIf` and its writes, or between the four array writes, lets the other script interleave mid-update and tear the index alignment the four arrays depend on.

## A shared global mutated as `x = x - c; publicVariable "x"` loses concurrent writes

`publicVariable` broadcasts an absolute value with no network lock, and each machine keeps its own copy. Two machines that read-modify-write a shared global both read the stale base, and the later broadcast overwrites the earlier — changes don't add up, and resource can be *created* (two clients spending against a 50 pool both write 30: net −20, not −40). Local `x = x + n` is atomic; the loss is the stale base a second machine read. SP has one machine, so it only surfaces in co-op, and a save persists the corruption.

**Fix:** never `publicVariable` a shared resource from a non-authoritative machine. Route every change through one server-side function taking a signed *delta* (`x = x + _delta; publicVariable "x"`); callers send `[_delta] remoteExec ["fn", 2]` and never touch the global. A delta can't carry a stale base. The *caller* still can't decide the spend (it reads a snapshot the server moved past) — both must be server-side (`fnc_cp_adjust`, sole writer of `commandpointsblu1`, `src/duws/server/warcom/fnc_economy_init.sqf`; it also refreshes the local counter when `hasInterface`, since the host's `publicVariableEventHandler` doesn't fire for its own broadcast). See [`economy.md`](../gameplay/economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

## A joining client is sent every `publicVariable`'d global, then its own init overwrites them

`publicVariable` is JIP-persistent: the engine delivers the last broadcast value to a joining client *before* the mission's own client init runs. A per-client init that then assigns the same global unconditionally clobbers the delivered value, silently — the joiner disagrees with the session, and the disagreement becomes everyone's the moment that client broadcasts back. Invisible on a host or in SP.

**Fix:** guard every client-side init of a broadcast global with `if (isNil "x") then {x = default};`. Assigning unconditionally is correct *only* for never-broadcast globals — so the decision to `publicVariable` and to initialise live in two files kept in step by hand; here they are not (`client/includes/supports_init.hpp` guards three flags and assigns three unconditionally while `fnc_request_support.sqf` broadcasts all six, [`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#open-defects)).

## Weather set on the server synchronises itself, so mirroring it into a global is dead state

`setOvercast`, `setFog` and `setDate` are artificially synchronised: run on the server, the engine propagates to every client and joiner. Copying the value into a broadcast global adds nothing and rots — the usual shape broadcasts a placeholder once at init then writes every cycle *without* re-broadcasting, so remote readers keep the placeholder while the sky says otherwise. Local machine always agrees with itself.

**Fix:** read the sky through `overcast` and `fogParams` (the engine's synchronised state on any machine); never mirror weather into a global. Only one script weather change runs at a time (starting `setOvercast` halts an in-flight `setFog`), so the engine's values also account for a cut-short transition. `setRain` is independent.

## Waypoint and flight commands are ignored unless the group is local to that machine

`addWaypoint`, `deleteWaypoint`, `flyInHeight`, `setMass` and `ropeCreate` take effect only where the group/object is local — issued elsewhere they fail silently. Locality follows the creator: a client-spawned group belongs to that client, and `remoteExec [..., 2]` then delivers to a machine that can't act. `fnc_helolift` had both faults (spawned the heli client-side then `remoteExec`'d waypoints to the server, and defined its server helpers inline in a client-only file so a dedicated server never assigned those names) — all invisible to a hosting player.

**Fix:** decide which machine owns an AI group before writing anything that commands it, spawn it there, route every order back to it (server ownership is the safe default for a mission-steered group). A `remoteExec`'d-by-name function must be in the registry so the receiving machine has it.

`allowDamage` is machine-local and does *not* travel with ownership: a vehicle made invulnerable on the server turns vulnerable the instant a client takes it (R3F's carry `setOwnerTo`s the object to the carrier), because the new owner never ran `allowDamage false`. Re-assert it on whichever machine holds the object at each step. The depot retrieve (`server/supports/fnc_garage_init.sqf` → `client/dialog/fnc_depot_place_r3f.sqf`) sets it server-side at spawn, again on the carrying client, and restores damage only after `setOwner 2` reclaims it.

## Practice targets ignore damage entirely; `HitPart` fires on the shooter, not the owner

The `TargetP_*` range targets don't process bullet damage — `Hit`/`HandleDamage` never fire whatever `allowDamage` is, so a server-side damage handler waits forever. `HitPart` does fire, but on the machine that fired the round, not where the object is local (the opposite of every other damage handler). An EH added only on the server stays silent for every client shot, and works for a hosting player.

**Fix:** add the handler on every machine with `remoteExec ["addEventHandler", 0]` and have its body send the result to the state owner; pass the object as the JIP parameter (see [§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose)). Killhouse (`server/killhouse/fnc_createKillhouse.sqf`) bounces each hit to `killhouse_srv_target_hit`.

## `setMarkerColor` accepts an inline `#(r,g,b,a)` string, not only a `CfgMarkerColors` class

A marker colour need not be a class name — a literal `"#(0.5,0,0.5,0.3)"` renders that colour, so a mission needing shades outside the stock `Color*` set needs no `CfgMarkerColors` block. It looks like `setObjectTexture` procedural syntax and matches nothing in the config tree, so existing code using it reads as broken but isn't (civilian town ellipses, `fnc_civ_init_Tomata.sqf`).

**Fix:** use the inline form for one-off shades; keep `CfgMarkerColors` for editor-picked colours. Set translucency with `setMarkerAlpha` (a marker created without explicit alpha sits at 1).

## A label needs a real icon marker type; the invisible `"Empty"` type paints no text

`setMarkerType "Empty"` (Eden's invisible/system marker) was meant to carry text with no icon — a text-only cell label — but the map draws nothing for it, silently: no icon and no text either. There is no icon-less marker that still renders its `setMarkerText`. So a labelled marker must use a real icon type from the marker table ([`external/arma3_markers.md`](../external/arma3_markers.md)) and accept the icon beside the text (the OPCOM coverage overlay uses `mil_triangle_noShadow`, `fnc_debug_opcom_grid_draw.sqf`).

**Fix:** for a text label on the map, pick a listed icon type and let the icon show; if a bare label is essential, draw it through the map control's `Draw` event handler (`drawText`) instead of a marker.

## `str` on a string adds literal quote characters, and this mission's marker names carry them

`str "12345678"` returns the source representation — eight digits wrapped in `"` characters. Zone markers are created as `createMarker [str(_markername), _zonePos]`, so the real name *includes those quotes*, and every later `setMarkerAlpha`/`setMarkerColor`/`setMarkerPos` must spell it the same way. `_markername` is already a `String` from `format`, so the `str` looks redundant, but dropping it on one side addresses a marker that doesn't exist (no error, zone stays invisible).

**Fix:** in `server/init_zones/`, treat `str(_name)` as part of the marker's identity and grep sibling accesses before touching either half (`fnc_createzone.sqf:45,59`, addressed in `fnc_zone_reveal.sqf`/`fnc_captured.sqf`). Names built without `str` are addressed without it — the rule is per-marker.

## `diag_tickTime` counts from process start and is not restored by a savegame

`diag_tickTime` is Arma's uptime (already thousands at mission start, zero on relaunch, not saved); `time` is mission time (near zero at start, saved). Neither is "seconds since this mission started". A cooldown on `diag_tickTime` survives every test but locks for the previous session's whole length after an autosave resume, and its "never used" default must be *negative*. A third clock, the campaign date, is what a *skippable* cooldown must use: `skipTime` moves neither `time` nor `diag_tickTime`, but `dateToNumber date` (fraction of year; ×8760 = hours) does move with resting and Zeus. `setTimeMultiplier` scales the date *and* `time` but not `diag_tickTime` (same split as `sleep` vs `uiSleep`). Don't fold the year into the figure — 32-bit float precision at millions-range exceeds a short cooldown; work within the year and treat a deadline more than one full cooldown ahead as expired.

**Fix:** pick one clock per cooldown and keep sentinel, stamp and every check on it. Campaign date where resting/acceleration should shorten the wait; `time` where a savegame must carry it and neither may shorten (`fnc_mission_cooldown_left.sqf`); `diag_tickTime` only where it should die with the session. Repair only a stamp *ahead* of its clock — clear it and let the default apply (`server/server_init.sqf:434`).

## An `Acts_` ambient animation survives death, so the corpse stands and shrugs off hits

A unit put in an `Acts_*`/`acts_*` ambient animation with a raw `switchMove` stays in it when it dies — no death transition, no ragdoll, body upright — so incoming fire produces no visible reaction and it reads as invulnerable though `alive` is already `false`. Scripts see the opposite (`Killed`, `!alive` fire correctly), so the divergence is purely visual. `BIS_fnc_ambientAnim`/`...Combat` install their own break handlers, so a hand-rolled `switchMove` behaves differently.

**Fix:** with a raw `switchMove`, add a `Killed` handler that clears the move — `[_unit, ""] remoteExec ["switchMove", 0]` (broadcast; `switchMove`/`playMoveNow` are local). Broadcast and JIP-key the *pose* too (a server-side pose dresses only the host), and drop that JIP entry in the `Killed` handler (`remoteExec ["", _key]`) or a late joiner gets the pose for a corpse. A posed unit left `allowDamage false` never reaches the bug, so the handler is load-bearing only once the unit is killable — pair the changes (HQ officer/engineer, `server/init_hq/fnc_BluHQinit.sqf`). **For a held stance (not a gesture), prefer `setUnitPos "MIDDLE"`/`"DOWN"`** — a living idle, global for a server-owned unit, no broadcast/JIP/death handler; reset with `"AUTO"`. A raw `switchMove` into an `acts_` crouch idle can freeze in a visibly wrong half-crouch.

## `side` of a dead unit is civilian, so an enemy-corpse test must not read `side`

Once a unit dies the engine reports it on side `civilian`, whatever it fought as — so `side _corpse == east` is false on every OPFOR body, and any prompt/loot/cleanup gated on it silently never fires. A `Killed` handler running `side _unit` at the instant of death still catches the fighting side, which is why a check that works in the handler breaks on a settled corpse. Caching side at spawn re-exposes it to a body-swapping GC (AGC mod rebuilds a distant corpse and drops its variables).

**Fix:** identify an enemy corpse by config side, not live side: `getNumber (configFile >> "CfgVehicles" >> typeOf _corpse >> "side") == 0` (0 east, 1 west, 2 independent, 3 civilian) — a pure config read, death-stable and corpse-swap-safe (`client/search/fnc_intel_search_action.sqf`).

## `knowsAbout` is a decaying knowledge scalar, not a current-visibility flag

`side knowsAbout target` returns a 0–4 aggregate that rises while the target is sensed and *decays over seconds-to-minutes* after contact breaks. It is not "visible now", is unrelated to the target's position, and is side-wide (stays high while *any* unit remembers the target). Sampling the target's live position on `knowsAbout > threshold` keeps reporting the *current* position all through the memory tail — so a stored "last seen" follows an unobserved target and a teleport drags the stamp along. OPCOM's sensor bloomed force at a player's HQ after fast-travel this way. The scalar reads the same flat-high value whether watching a mover or remembering a ghost, so an edge/derivative gate does **not** fix it.

**Fix:** don't reconstruct "seen now" from `knowsAbout`. Read the engine's own last-seen: `unit nearTargets range` returns `[pos, type, side, cost, object, age]` per observer — `age` is seconds since the observer last pinned the position (~0 while sensing, growing once contact breaks; *not* a timestamp, don't subtract from `time`). `unit targetKnowledge target` carries the same per (observer,target). Both are per-observer — aggregate over a bounded observer set, never a side-wide call. `server/warcom/opcom/belief/fnc_opcom_sense.sqf` stamps a fresh-age group at the observer's *remembered* position (element 0, not the live position) and lets an unsensed group decay.

## A `Killed` handler added on the server does not fire for a client-local unit

A unit EH runs only on the machine that added it, and `Killed` fires there when the unit is local to it. Add a server-side `Killed` for a client-local unit (a player, or an AI in a player's group in co-op) and it may never reach the server. Hidden in SP (one machine, every unit local). Server-spawned units (OPFOR garrison, mission civilian) are server-local, so the pattern is safe for them (`DUWS_fnc_garrisonReserveWatch`, `server/init_zones/fnc_garrison_reserve.sqf:192-211`); a player's own death handler is added on that player's client (`modules/AIS/Core/fn_aisInitPlayer.sqf`).

**Fix:** to react on the server to a client-local unit's death, add the handler where the unit is local (client init, then `remoteExec` the fact to the server) or, for a whole side, *poll* server-side. OPCOM's belief prune (`server/warcom/opcom/belief/fnc_opcom_belief_prune.sqf`) resolves each believed group by `netId` every tick (`groupFromNetId`) and drops it when none is alive — catching wipe, merge-drain and deleted group with one server-side test.

## `enableSimulation` is local, so a server-side freeze leaves clients simulating

`enableSimulation` affects only the machine it runs on; `enableSimulationGlobal` (server-only) reaches everybody. A unit/prop frozen server-side then `setPosWorld`'d at an absolute Z sits still on the server while every client keeps simulating it, fails to resolve it onto ground, and renders it falling permanently (server position updates re-park it in the air). Invisible in a host-only test.

**Fix:** use `enableSimulationGlobal` for anything a client also renders, including the transient placement freeze (the window is short but the client never gets the matching re-enable). `fnc_duws_deploy` (`server/misc/fnc_composition_stream_init.sqf`): global simulation, local `allowDamage` (server-local damage resolves server-side, and broadcasting per prop costs a JIP entry each).

## An unsimulated object does not fall, so placing one in the air parks it there

Physics runs only while simulation is on. `setPosWorld`/`setPosATL` on a sim-disabled object puts it exactly where told and leaves it — no fall, no settle, no ground contact, no error. Compositions carry the flag in their stow record (`fnc_duws_stow` writes `simulationEnabled _x`, `fnc_duws_deploy` replays it), so an object frozen at build time comes back frozen a campaign later. Anything that places by lift-and-drop then performs the lift and never gets the drop.

**Fix:** never assume an object you didn't just create is simulated. Where placement depends on falling, assert `enableSimulationGlobal true` (global, per [§`enableSimulation` is local](#enablesimulation-is-local-so-a-server-side-freeze-leaves-clients-simulating)) *after* the position is written, so the fall starts from there (`DUWS_fnc_dropStatic`, `server/init_zones/fnc_zone_stream_init.sqf`).

## `createVehicle` of an `Item_*` class makes a simulated holder that PhysX flings off a surface

Spawning loot by its `Item_*` ground class (`createVehicle "Item_MobilePhone"`) yields a `WeaponHolderSimulated`, a PhysX body ejected off a table/shelf on the next step. `enableSimulationGlobal false` only freezes it wherever it floated (per [§an unsimulated object does not fall](#an-unsimulated-object-does-not-fall-so-placing-one-in-the-air-parks-it-there)). A `GroundWeaponHolder` has no PhysX — created in the air it stays, won't fall or bounce, and left unfrozen keeps its inventory openable (still lootable). Fill it on the create frame (an empty holder self-deletes in ~1 s); cargo takes the *bare* inventory class (`addItemCargoGlobal` for `CfgWeapons`, `addMagazineCargoGlobal` for `CfgMagazines`), not the `Item_*` body.

**Fix:** place pickup-able loot through `fnc_place_settled`'s `_asLoot` mode (`server/placement/fnc_place_settled.sqf`); set-dressing never picked up can stay a plain `Land_*` prop. `server/debug/fnc_debug_spawn_intel.sqf` shows which intel classes have an `Item_*` body and which cargo slot each takes.

## `moveInGunner` into a simulated static leaves the turret dead; seat it frozen, then thaw

A static crewed *after* its simulation is enabled keeps a gunner who never traverses — fires only down its placed heading. The turret AI is brought up as the gun transitions unsimulated→simulated with a gunner aboard; a gunner added to an already-running gun never gets that pass. Symptom is a crewed, upright, undamaged gun shooting straight ahead (`simulationEnabled` reads `true` either way — the base is simulated, only the turret is inert). The natural thaw-then-seat order is wrong; seat-then-thaw is right.

**Fix:** seat every static while frozen, then thaw — `DUWS_fnc_seatStatic` (`server/init_zones/fnc_zone_stream_init.sqf`) is the single seat step (re-freeze, `moveInGunner`, thaw), called by `DUWS_fnc_crewCompositionStatics` (prefab) and `DUWS_fnc_manStatics` (stream re-crew, hardpoints). A crewed gun that fires but won't rotate is this bug until proven otherwise.

## A hidden terrain object comes back the moment its damage state changes

A terrain object can't be deleted (`deleteVehicle` no-ops silently), so clearing ground means `hideObjectGlobal`. The engine replaces a building with a fresh, *unhidden* object when its damage state changes (via the `BuildingChanged` event, args old+new, carrying no hidden flag), so any explosion near a cleared site re-pops the buildings through whatever was built on top.

**Fix:** hide a building only where one must go, and register it. A prefab zone centre takes its buildings with it (`init_zones/fnc_createzone.sqf`) and holds the register plus a `BuildingChanged` handler that re-hides replacements; HQ/FOB clearing goes through `fnc_clear_foliage.sqf` filtered to `TREE`/`SMALL TREE`/`BUSH` (no register needed). A hide is permanent and unrestorable — pay it where a composition must fit, not to stop a tree clipping a tent. `BuildingChanged` is local (only the machine that simulated the damage fires it), so a server-only re-hide misses a distant client's blast (escalation, `fnc_escalation.sqf`, works around this with a per-machine watch; the zone re-hide's exposure is unfixed).

## `+` (copy) deep-copies nested HashMaps, so mutating a `+copy` element updates nothing

Unary `+` (copy) on an array recurses into nested containers, and since Arma 3 v2.02 that includes HashMaps — `+[myHashMap]` yields a clone of the map, not a reference to it. Iterating `forEach (+_store)` and calling `_x set [...]` on each element writes to a throwaway clone discarded at scope end; the stored map is untouched. HashMaps are reference types, so plain assignment, `select`, `apply` and a direct `forEach` all keep the reference — only `+`/`copy` clones. The OPCOM per-tick mover (`fnc_opcom_task_step`) iterated `+DUWS_opcom_taskings`, so every tasking's `pos`/`leg`/`grp` write vanished and no unit ever moved or went live — silent, no error.

**Fix:** iterate a HashMap store directly (`forEach DUWS_opcom_taskings`) whenever the loop mutates elements. Reach for a snapshot only against structural change (adding/removing array elements mid-loop), and make it one that preserves references — `apply {_x}` copies the outer array while keeping the same maps — never `+`. The sqf-vm suite predates HashMaps and cannot catch this.

## A unary command binds tighter than `+`, so `sleep 2 + random 5` sleeps a flat 2 s

Every unary command (`sleep`, `count`, `random`, `floor`, `str`) sits above `+`/`-`/`*` and the comparisons, taking only the token to its right. `sleep 2 + random 5` parses as `(sleep 2) + (random 5)` — a flat 2 s, randomised part discarded, `+` handed Nothing, result discarded, no RPT line.

**Fix:** parenthesise whenever a unary command is followed by arithmetic — `sleep (2 + random 5)`. Staggered-wake loops hide this: a delay meant to spread a garrison's units collapses to one they all share.

## Conditional `count` is `{code} count array`; reversed operands throw, not miscount

Binary `count` takes the block on the LEFT — `{alive _x} count _units`. Written the other way, `_units count {alive _x}` is a type error (Code expected left) that aborts and unwinds the whole function — it does not return a wrong number. `findIf` is the opposite order (`_array findIf {code}`), and reaching for that shape is the slip. A reversed `count` in `DUWS_fnc_hardpointClearCheck` errored every tick before its clear line, so a mortar/artillery battery never read as destroyed (`Error count: Type Array, expected Code`, unattached). That branch reads live objects, so the sqf-vm suite can't exercise it and the lint checks brackets, not arity.

**Fix:** copy the shape from a known-good line (`{alive _x} count _roster`). Treat any server clear/stream branch touching live objects as untestable by the suite, and read its RPT after play-testing.

## `reverse` returns Nothing, so it cannot be inlined — and `deleteWaypoint` shifts indices

`reverse` reverses in place and evaluates to Nothing — `forEach (reverse _xs)` is handed Nothing, the body never runs, no error names `reverse`. This bites next to `deleteWaypoint` (`[group, index]`, deleting one renumbers later ones down): a forward pass over `waypoints _group` deletes only every other waypoint, so a civilian's circuit is half-cleared and the group walks off mid-conversation.

**Fix:** bind, reverse as its own statement, then iterate — `private _wps = waypoints _group; reverse _wps; { deleteWaypoint _x } forEach _wps;` (or `for "_i" from (count _wps - 1) to 0 step -1`). `fnc_civ_panic.sqf` and `fnc_civ_moveToPlayerServer` (`server/civilian/fnc_civ_state_init.sqf`) do the bind-then-reverse form.

## A waypoint statement never runs if the group cannot reach the waypoint

`setWaypointStatements` fires only on actual completion. A waypoint the group can never reach (an exit past the map edge, a position closed to its movement type) is never completed, so a `waitUntil` on the flag it sets blocks forever. `fnc_intro_heli.sqf`'s despawn waited on such a flag — its flyaway waypoint sits `15000` m out on a random bearing, off-map for many placements, and AI aircraft turn back at the boundary, leaving the helicopter orbiting the base all session (`allowDamage false` removed the `!alive` escape).

**Fix:** treat a waypoint statement as best-effort notification, never the sole completion signal. Gate deletion on something the engine can't withhold — distance travelled plus a hard time cap (`fnc_helotaxi.sqf`).

## `moveInGunner` reports nothing when it fails, and the man is left standing where he spawned

`moveInGunner` returns no value and raises no error — a static whose gunner memory point is in the ground refuses the seat, knowable only by reading it back (`gunner _gun isEqualTo _unit`). The man stands beside his gun, alive, on the roster and counted toward the zone's peak, so the zone is weaker than its count, capture is denied by a defender defending nothing, and the log records full strength. `moveInDriver`/`moveInCargo`/`moveInTurret` are the same.

**Fix:** seat, read back, retry — dropping the gun a little higher each pass (a gun landing *onto* its ground takes a seat one sunk *into* it refuses). `DUWS_fnc_seatStatic`/`DUWS_fnc_manStatics` (`server/init_zones/fnc_zone_stream_init.sqf`) do read-back and retry; after the last drop the man is deleted with a `WARN` naming the gun, leaving the emplacement as usable scenery.

## A physics body spawned clipping geometry takes a lethal collision impulse, not a nudge

`createVehicle` with `"CAN_COLLIDE"` (or placement radius `0`), or a lift-and-drop `setPosWorld`+thaw, places a simulated body into whatever solid already occupies the point; the first simulated frame resolves the overlap with a separating impulse large enough to throw the body clear and cook it off. It reads as a vehicle exploding for no reason the instant it spawns. `CAN_COLLIDE` is what holds it on an exact mark (the empty-position specials nudge to a gap); a radius-0 placement behaves the same. Healing after the fact (`setDamage 0` once settled) races the frame and loses. This is why the depot retrieves via a map click through `createVehicle [..., 5, "NONE"]` (`server/supports/fnc_garage_init.sqf`) rather than forcing a pad centre.

**Fix:** spawn with `enableSimulationGlobal false` in the same frame as the `createVehicle` (before any suspension, so no physics tick runs first), pose it (`setDir`, then re-seat with `setPosATL` because the rotation displaces it), zero `setVelocity`, then thaw a beat later — frozen it takes no impulse, released from rest a shallow clip depenetrates gently. As a backstop hold `allowDamage false` across the settle, set *after* restoring any stored damage (`allowDamage false` suppresses `setDamage`), then restore `allowDamage true`. Same freeze-pose-thaw as HQ hard placement (`init_hq/fnc_placeHQUnits.sqf`); `fnc_civ_traffic` (parked cars) and `DUWS_fnc_manStatics` (`server/init_zones/fnc_zone_stream_init.sqf`) wrap the gun drop this way.

A body left frozen (never thawed — static furniture) will not take a `setPosASL`; seat it *before* freezing and reposition a returned frozen piece with `setPosWorld`. And when the seat runs under scheduled code (a `remoteExec`'d placer), a physics tick can be scheduled between the `createVehicle` and the freeze even with no explicit suspension — wrap create→seat→freeze in `isNil { … }` so the block runs unscheduled and no tick interleaves (`fnc_place_settled.sqf`).

## A static weapon that goes over throws its gunner out and refuses a new one

A gun knocked onto its side ejects the man and refuses a new one while it lies there, leaving the defender standing beside it, alive, on whatever roster counted him as a gun. The seat test can't tell an orientation fault from a clearance one (both refuse), so the retry that recovers a sunk gun never recovers a fallen one, and lifting between attempts makes it worse. Orientation is carried by `vectorUp` alone. The fall lands in the *seconds after* placement (a live physics body settling onto teleported-into ground), so code that inspects guns immediately sees a clean rebuild the player then walks up to and finds flat.

**Fix:** test the tilt, never the seat — `(vectorUp _gun) select 2` against **vertical** (not the ground normal, which reads backwards on slopes). Correct with `setVectorDirAndUp` on a `vectorDir` flattened into the horizontal plane (a gun on its nose has a dir into the ground; that against a vertical up leaves no orientation). A lean short of the eject angle still keeps its gunner, so crew only a gun that came to rest genuinely standing (dot near vertical) and re-drop one that didn't — nudged on x/y (`findEmptyPosition`) to hunt ground it stands on. `DUWS_fnc_dropStatic` stands and drops; the settle wait that makes the result readable is one per round in `DUWS_fnc_manStatics`; `DUWS_fnc_seatStatic` does the square (`setVectorUp [0,0,1]`) and seat (all `server/init_zones/fnc_zone_stream_init.sqf`). None works without the others.

## `doStop` outlives the orders it was issued against, and new waypoints do not release it

A unit under `doStop` ignores its group's waypoints until given a move order of its own — deleting waypoints and adding a fresh set does not clear the stop (the circuit is issued, visible to `waypoints`, never walked). Invisible because stop and re-order live in different functions: `fnc_civ_moveToPlayerServer` ends on `doStop`, and every conversation routes through `fnc_civ_resume`→`fnc_civ_wp_Tomata`, which only rebuilds the circuit — each civilian is its own leader, so anyone spoken to stood put for the town's occupancy (reads as a stuck `CYCLE`).

**Fix:** pair every `doStop` with an explicit release where orders are re-issued — `_unit doMove (waypointPosition _first)` is both a move order and the leg the group was about to walk, so it costs nothing on never-stopped paths. `setDriveOnPath` is **not** a release: a preceding `doStop` still holds the hull halted (in `fnc_convoy_drive` a `doStop` before each `setDriveOnPath`, added on the wrong belief that formation overrides the path — it doesn't, see [§setDriveOnPath commits a driver to the path](#setdriveonpath-commits-a-driver-to-the-path-and-ignores-waypoints-formation-and-combat) — froze one hull per column). If `setDriveOnPath` will drive the hull, issue it alone.

## A lone MOVE waypoint is not a wait: the group completes it on arrival and drifts, so each leg of a staged journey needs its own waypoint

A single MOVE waypoint is reached, marked complete, and — with nothing queued behind it — the group reverts to idle/formation behaviour and drifts off the spot (in SAFE it mills, in AWARE it wanders after the leader's recalculated position). So a journey that stages through a wait cannot be one MOVE to the far end: a live land unit ordered straight to its ferry pickup walks to the shore, completes, and leaves before the transport arrives. Every leg — the walk in, the wait, the walk out — has to be its own waypoint, and the waiting leg must be a type that holds, not a MOVE that completes.

**Fix:** give the wait point a `"HOLD"` waypoint after the MOVE leg (`(_grp addWaypoint [_pos, 0]) setWaypointType "HOLD"`); HOLD never auto-completes, so the group pins there until something else moves it. Release it when the next leg begins — clear the group's waypoints or issue the boarding/move order directly — because HOLD does not clear itself and will otherwise compete with the next order. `DUWS_fnc_opcom_reOrderLive` stages a live land rider at its near shore this way, and the ferry pickup drops the HOLD before `orderGetIn` (`server/warcom/opcom/taskings/fnc_opcom_stream.sqf`, `fnc_opcom_ferry.sqf`).

## A group in COMBAT behaviour ignores a commanded move order

An AI group whose behaviour has gone `COMBAT` owns its movement through the danger FSM — a MOVE waypoint or `doMove` is deprioritised or ignored. `setBehaviour "AWARE"` is overridden the instant it takes fire; `setCombatMode "BLUE"` + `disableAI "AUTOTARGET"` stops firing but not cover-seeking; only `setBehaviour "CARELESS"` moves it reliably, and CARELESS walks it into fire in the open. A commanded fighting withdrawal is not achievable.

**Fix:** never design a retreat or mid-fight reposition that commands an engaged live group to a safe spot. Let a committed group fight to a decision and reclaim it for movement only once out of combat.

## `lock true` stops a player boarding, not an AI disembarking

`vehicle lock true` blocks the player getting in/out and blocks AI getting *in*, but does not keep an aboard AI *inside*: it still bails when the group goes COMBAT, or the vehicle halts/stalls/is disabled. Three layers hold an HVT commander in his car: `lock true`, `setUnloadInCombat [false, false]` (combat bail), and a `GetOutMan` handler reseating him — `if (alive _unit && alive _veh) then { _unit moveInCargo _veh }` (`moveInCargo` re-enters past the lock; `alive _veh` lets a destroyed car eject normally).

**Fix:** to keep an AI in a vehicle, don't rely on `lock` alone — stop the combat bail with `setUnloadInCombat [false, false]` and enforce with a `GetOutMan` reseat, reseating only while the vehicle is alive.

## `land "GET IN"`/`"GET OUT"` is a sticky mode with no completion event

`aircraft land "GET IN"` (or `"GET OUT"`) makes an AI helicopter descend and *stay* grounded — the mode persists until explicitly cancelled, and the engine fires no "landed" callback, so nothing tells you it touched down and a fresh move waypoint may be deprioritised while the land order still stands. Two consequences for a poll-driven caller (a server tick loop, where a `waitUntil` spawn is not allowed): detect grounding by reading `getPosATL _heli select 2` under a small threshold (~4 m, as `fnc_helotaxi` does), not an event; and lift the aircraft again with `_heli land "NONE"` **before** issuing the next waypoint, or it can sit on the pad. Door animation is model-specific — the `door_L`/`door_R` sources `fnc_helotaxi` animates exist only on some airframes, so `animateDoor` silently no-ops on others; never depend on it across the faction mods DUWS auto-detects.

**Fix:** drive a landing across ticks, not in a blocking `waitUntil` — issue `land` once within range, poll `getPosATL` z for grounded, act, then `land "NONE"` and re-task. OPCOM's live ferry pickup/drop (`DUWS_fnc_opcom_ferryStepLive`, `fnc_opcom_ferry.sqf`) does exactly this, and gates a stall timer to the landing phase so a long approach never times the crossing out mid-air.

## `cmd [...] remoteExec ["call", 0]` broadcasts the return value, not the command

A unary command binds tighter than binary `remoteExec`, so `titleText [...] remoteExec ["call", 0]` runs `titleText` on the calling machine and broadcasts what it evaluated to (Nothing) — every other machine gets an empty payload. The missing piece is braces: `{titleText [...]} remoteExec ["call", 0]`. Without them the statement still reads as a broadcast and runs locally, so it survives review and host/SP testing; only a dedicated server or a second client exposes it.

**Fix:** name the command rather than wrapping code — but `remoteExec` hands an argument *list*, so a unary command whose one argument is itself an array needs a second bracket pair: `[["In memory of...", "PLAIN", 3]] remoteExec ["titleText", 0]`. Written flat the command gets only the first element and throws on type, so the by-name form fails silently too if nesting is dropped (`src/duws/server/misc/fnc_intro_heli.sqf`).

## `titleText`'s speed argument fades the new card in; it never fades the old one out

`titleText [_text, _type, _speed]` times the card being *posted*. Posting an empty string to clear replaces the visible card instantly then spends `_speed` seconds fading in nothing — the text snaps off, looking like a fade that didn't take. `titleFadeOut _duration` is the only command that fades what is on screen; it takes a plain number, so `remoteExec` needs one bracket pair — `[2] remoteExec ["titleFadeOut", 0]`.

**Fix:** clear a title card with `titleFadeOut`; keep the empty-string form only for swapping one card for another with no gap (`fnc_intro_heli.sqf`).

## `BIS_fnc_typeText`'s second and third arguments are screen coordinates, not timings

Signature is `[lines, x, y, format]`. A hold or typing speed passed in those slots is read as a position, so the card types itself off-screen — `[..., 1, 2]` puts it two full screens below the bottom. The timing lever is per line: each entry is `[text, format, delay]`, the delay being how long that line sits before the next. Callers: `client/misc/fnc_bottom_right_message.sqf:221` passes `-safezoneX`, `0.85` to pin bottom-right; `server/warcom/fnc_init_OPFOR_WARCOM.sqf:75` passes the line array alone and lands centred.

**Fix:** pass the line array alone unless moving the card, and put a hold in the line's own third element (a one-line card with no delay drops the line the instant the last character lands — reads as a flicker and invites the trailing-argument "fix" that hides it).

## `localize` resolves on the machine that runs it, so a broadcast string carries the sender's language

`localize` reads the executing machine's stringtable. Resolving a key server-side and broadcasting the result sends the *server's* language to everyone; broadcasting a code block that localizes on arrival lets each client resolve its own:

```sqf
[localize "STR_X"] remoteExec ["hint", 0];                  // everyone reads the server's language
[{hint localize "STR_X"}] remoteExec ["BIS_fnc_Spawn", 0];  // each client resolves its own
```

A dedicated server takes its language from its own config, so the first form can hand every player a language none chose (invisible in SP and on a host).

**Fix:** this mission resolves server-side nearly everywhere (every `fnc_duws_dialogue` call site is handed already-`localize`d text), so the `BIS_fnc_Spawn` hint sites are the exception. Don't fold them into the first form without deciding one language for everyone — the DE/ES/ZH tags stop reaching anyone on a dedicated server the moment you do.

## `player1` is an editor unit, so `remoteExec`ing to it addresses slot 1 and nobody else

A `remoteExec` object target runs only where that object is local. `player1` is a unit placed in `mission.sqm`, not a synonym for "the player" — it resolves to whoever holds slot 1 (the Game Master seat). SP hides it; a second co-op player exposes it. Fourteen side-mission announcements were readable by one player in a four-player session this way.

**Fix:** `player1` is right only for the Game Master seat (manual zone/HQ placement, GM-gated rows). Anything the team reads takes `[0,-2] select isDedicated`, evaluated where the call is made — `isDedicated` is false on every client, so the idiom only excludes an interfaceless server when the call site is server-side (client-side broadcasts keep a plain `0`).

## A comm-menu item id goes stale the moment the item is used

`BIS_fnc_addCommMenuItem` returns an id `BIS_fnc_removeCommMenuItem` needs back, but a `CfgCommunicationMenu` class with `removeAfterExpressionCall = 1` is deleted the instant the player calls it — the re-adding script gets a *new* id, so any id stored at purchase points at nothing (and whether other items' ids survive a removal is undocumented). Thirteen of twenty comm classes are declared that way; the two High Command aircraft were the only rows with a sell-back and the only two keeping their id current.

**Fix:** never call the two BIS functions directly. `fnc_support_comm_add`/`fnc_support_comm_drop` (`client/supports/fnc_supports_init.sqf`) own a per-player class→id record, every re-add routes through the add, and each `expression` field opens with `['<class>'] call fnc_support_comm_used` so the engine's deletion is observable. Removal tears the slate down in **descending id order** (correct whether ids are handles or indices) and rebuilds from the record; the record doubles as the presence test.

## A `CfgNotifications` description is clipped, not wrapped, past roughly 60 characters

The notification card's description box is fixed-size; longer text is cut off mid-sentence with no ellipsis and no error. The Mobile HQ release card's 87-char body reached the player as "...Any squad leader can designate a new" — tail gone. The ceiling is a pixel width (moves with the proportional font; the *title* budget is tighter), so **60 characters is the figure this mission writes to** (was 75; a 73-char line still clipped).

**Fix:** keep every `BIS_fnc_showNotification` body at or under 60 characters, counting a `format` placeholder at its longest substitution; titles are short noun phrases. Anything needing more room is not a notification — a briefing belongs in the task description (scrolls), an explanation in a `hint` (wraps), never both ([`player_text_style_guide.md`](../gameplay/player_text_style_guide.md#notification-card-dialogue-and-the-hint-box)).

## SQF identifiers are case-insensitive, so `_Varname` and `_VarName` are one variable

Variable and function names ignore case — `_Varname = "MHQ1"` then a read of `_VarName` is one variable. Harmless at runtime (`fnc_MHQ_select.sqf:38-40` mixes them and works), but the cost lands on anything reasoning about source as text: a case-sensitive search reports the write dead and the reads undefined. Command names too (`IF`, `ForEach`, `SetPos`).

**Fix:** fold case on both sides whenever a tool compares SQF identifiers, or a dead-code/rename pass produces confident false positives. By eye, treat two spellings as one variable.

## `getUnitLoadout` pads weapon arrays, so length is not presence

A weapon slot in `getUnitLoadout` is always seven elements when carried — `[classname, suppressor, pointer, optics, [mag, count], [mag2, count2], bipod]` — absent attachments `""`, absent magazines `[]`. So `count _weapon > 3` tests for a *weapon*, never an optic, and `_weapon # 4 # 0` indexes an empty array on a launcher with no magazine. Reading an absent attachment compounds it: `configFile >> "CfgWeapons" >> "" >> ...` resolves to no classes, `configClasses` returns `[]`, and **`selectMax []` returns nil** — assigning nil *undefines* the variable, surfacing lines later as "Undefined variable in expression". A continuous-zoom scope reaches the same `selectMax []` a second way (has `OpticsModes`, no `discreteDistance`).

**Fix:** test the slot, not the length; guard the flattened array, not just the modes list.

## The diary ignores `<t>`; structured-text colour there comes from `<font>`

`createDiaryRecord` bodies are structured text, but only a subset of `parseText` tags render in the map's Notes. `<t>` is **not** one — silently dropped with its `color`/`size`, so the text shows uncoloured. Diary records colour via `<font color='#RRGGBB'>`; `<br/>` and `<img>` render in both. A `<t color=...>` copied from a dialog string compiles, shows, and stays uncoloured (reads as "colour code wrong", not "wrong tag"). One further mismatch: `<font size='N'>` is absolute pixels where `<t size='N'>` is a multiplier — copying `size='1.15'`/`'2'` across renders ~1-2px text.

**Fix:** colour diary bodies with `<font color='#RRGGBB'>`; drop or repixel any `size` copied from a `<t>` string.

## Seat and crew queries (`fullCrew`, `crew`) need a spawned object, not a classname

`fullCrew` takes a vehicle Object — handed a classname String it throws `Type String, expected Object`. A capability check in a menu build has only the classname, and when the throw lands inside a `call`ed classifier the function returns nil, so a gate built on that verdict *fails open*: the below-tier test errors instead of refusing and the purchase proceeds.

**Fix:** count seats from config — `getNumber (_cfg >> "hasDriver") + getNumber (_cfg >> "transportSoldier") + count ("true" configClasses (_cfg >> "Turrets"))`. `isKindOf`/`getNumber`/`configClasses` take a classname; the seat/crew *object* commands do not (`DUWS_fnc_vehTier`, `src/duws/shared/functions/fnc_ap_gate.sqf`).

## `setPos*` seats the model origin, not the model's base, so a swapped class of different height sinks

`setPosWorld`/`setPosATL`/`createVehicle` placement put the object's model **origin** `[0,0,0]` at the named height — not its lowest point. Two guns whose origins sit different distances above their bases end at different base heights from the same command. A composition authors each weapon's Z against an Eden placeholder (baking the placeholder's origin-above-base into the number); when auto-detect swaps in the faction's gun (a ZU-23 for vanilla static AA) the Z is reused, driving the taller-origin gun's base underground (a shorter one floats). The drop-and-settle only rescues guns it later crews and lifts from the buried position, so a deep sink never recovers; a roof gun has no settle at all.

**Fix:** base offset is `(boundingBoxReal _obj select 0) select 2` (how far the lowest point sits below the origin, ≤ 0). To seat a swapped class's base where the placeholder's sat, shift by `baseZ(placeholder) - baseZ(resolved)`. `fnc_static_baseZ` probes and caches per class; `fnc_static_place` applies the shift only when the class changed (both `src/duws/shared/functions/fnc_static_roles.sqf`), so an unmodded faction is untouched.

## `buildingPos` slots sit above the floor, so a prop seated at that Z by hand floats

`BIS_fnc_buildingPositions`/`buildingPos` return authored unit-placement points, not the floor collision surface — their Z sits a variable gap above the walkable floor (per building and per slot, so not subtractable like a class base offset), so an object placed straight onto that Z, even base-corrected, hangs.

**Fix:** drop the *carrier* simulated and let PhysX fall it the small gap onto the real floor, then `enableSimulationGlobal false` — batch it (place all carriers, one `sleep`, freeze the lot). Do **not** drop a prop that rides on the carrier (a laptop on a table): a PhysX body at the carrier's origin clips it and takes an ejection impulse (see [§A physics body spawned clipping geometry](#a-physics-body-spawned-clipping-geometry-takes-a-lethal-collision-impulse-not-a-nudge)); left to settle it lands on the floor, not the top. Seat the carried prop at rest once the carrier is frozen (create above the top, zero velocity, freeze) via `fnc_place_settled` (`src/duws/server/placement/fnc_place_settled.sqf`). Callers: `sabotage_laptop/fnc_sabotage_laptop_mission.sqf`, `destroy_patrol_camp/fnc_destroy_patrol_camp_mission.sqf`.

## A shell spawned at rest is inert: it needs impact velocity to fuze

`createVehicle` on an ammo/shell class (`Sh_82mm_AMOS` and kin) makes the projectile object but does not fire it — an impact fuze has nothing to arm at rest, so it sits live but inert. Re-placing it with `setPosATL`/`setPos` after creation makes it worse: the reposition re-zeroes the velocity, so a scripted booby-trap that created the shell on the prop then `setPosATL`'d it to the same point produced a dud every time.

**Fix:** spawn it just above the target (`+0.5` m) and drive it down with `setVelocity [0,0,-30]` so it strikes at once; do not `setPosATL` afterward. The small-offset-plus-downward-velocity form is safer indoors than a plain fall (which can spawn inside a ceiling). Create it on the **server** so the blast is authoritative and its damage replicates, unlike a client-side `setDamage`. Callers: `fnc_sabotage_laptop_decoy.sqf`, `fnc_random_event_car_bomb.sqf`.

## Z-placement frame: `setPos` counts roofs, `setPosATL`/`getPos [dist,dir]` measure from terrain, `setPosWorld` is absolute

Three placement frames differ in what Z is measured from:

- `setPos [x,y,z]` — z above the *highest surface* at the point, and a building roof is a surface. A gun/prop placed with `setPos` on a point overlapping a building footprint lands z metres above the roof.
- `setPosATL` (and the `object getPos [dist, dir]` overload) — z above *terrain*, ignoring floors/roofs/objects. Re-seating a unit standing on an upper floor with either snaps it to ground-floor height below.
- `setPosWorld` (with `getTerrainHeightASL`) / `getPosASL` — absolute ASL.

A side mission placing guns with `setPos` stood them on rooftops its site overlapped while its `setPosATL` props sat on the ground nearby (composition looked split); a carry/drop helper set an informant down with `setPosATL (_carrier getPos [1.2, dir])` and teleported him to the ground floor beneath the carrier.

**Fix:** for anything meant to sit on the ground, use `setPosATL [x,y,0]` or a terrain-height `setPosWorld`, never bare `setPos` (`fnc_static_place`'s `"world"` mode; zone prefabs and hardpoints use it). To place a unit at a floor-relative point, work in the world/ASL frame (`modelToWorldWorld`+`setPosWorld`, or `getPosASL`); better, when a body is already at the wanted world spot, `detach` and let it settle rather than any setPos (`DUWS_fnc_unitDrop`, `src/duws/server/misc/fnc_unit_carry.sqf`).

The spawn commands read the frame the same way: `BIS_fnc_spawnVehicle` (and array-form `createVehicle`) take a 3D position's z as height above *terrain* (ATL), so handing them a `getPosASL` point floats the hull by ≈ the terrain elevation. A 2D `[x,y]` grounds it (what `BIS_fnc_findSafePos` returns). `BIS_fnc_spawnGroup` grounds infantry regardless, which is why only vehicles float. OPCOM banks a stowed tasking's point as `getPosASL` for the belief grid, so its ground-vehicle de-virt strips z before spawning (`server/warcom/opcom/taskings/fnc_opcom_stream.sqf`).

## An empty group is never freed, and each side caps at 144 groups

`createGroup` claims a slot that lives until explicitly freed — nothing reaps an empty group unless it was made with `createGroup [side, true]` or handed to `deleteGroup`. Each side caps at 144; once reached, `createGroup`/`BIS_fnc_spawnGroup` return `grpNull` silently and no new AI spawns. The napalm strike leaked an empty WEST group per fire object (`[_bomb] joinSilent createGroup WEST` groups a projectile, never a unit, so the group stays empty), 32 per call — a handful of calls exhausted the side, after which every group-spawning path failed with no error, campaign-wide (`client/supports/fnc_arty.sqf`).

**Fix:** create transient groups with `createGroup [side, true]`, or `deleteGroup _g` once the last member is gone; grouping a non-unit leaks a slot immediately. When AI stops spawning mid-campaign with a clean RPT, read `count allGroups`.

## A script marker is never garbage-collected, so every exit path must delete its own

`createMarker` makes a marker that lives until `deleteMarker` names it — never reaped on unit death, GC, or (within a session) mission end. The fire-mission strikes drop two target markers up front; a jet-shootdown early-out (`if (!_veh_alive) exitWith {...}`) returned without reaching the tail cleanup, so every air strike lost before its drop left two grey ellipses on the map for good (`client/supports/fnc_arty.sqf`).

**Fix:** pair every `createMarker` with a `deleteMarker` that *each* exit path reaches — clean inside every `exitWith` after creation, or funnel all paths through one cleanup. Wrecks and corpses differ (the engine's GC reaps those).

## AI cargo bails a vehicle on contact by default; `setUnloadInCombat [false, false]` holds them

AI riding as cargo disembarks on its own the moment the vehicle enters combat (takes fire, spots an enemy, takes damage) — engine behaviour, nothing in the SQF shows it, so a trucked squad empties into the open hundreds of metres short. `vehicle setUnloadInCombat [allowCargo, allowTurret]` is the switch; the default `[true, true]` is auto-bail, `[false, false]` suppresses it.

**Fix:** set it once after the men are aboard — it disables only the *automatic* dismount, so script then owns every dismount and must provide one (`moveOut`, not an ordered get-out: a dead/dying/moving vehicle refuses the order). A truck reinforcement dismounts from a monitor firing on arrival, truck death, or a ride-time ceiling (`server/init_zones/fnc_garrison_reserve.sqf`). **`lock true` is the harder hold, for when the occupant must never leave** — it blocks entry/exit for the whole lifecycle, rides through a group re-join, and doesn't impede AI driving (`target_hvt/fnc_target_hvt_mission.sqf`); but never lock where the men must be able to flee a dying vehicle.

## `setDriveOnPath` commits a driver to the path and ignores waypoints, formation and combat

A hull under `setDriveOnPath [positions]` drives that exact polyline and nothing else — overrides waypoints and formation, and the driver won't manoeuvre or break to fight (turrets still engage). The point of a convoy that must arrive (`fnc_convoy_drive`: lead navigates, followers replay its driven track so none pathfinds a corner into a wall), but exactly wrong where hulls must fight. Hand a hull back to native AI with an empty path (`_veh setDriveOnPath []`) and drop any `forceSpeed` cap (`DUWS_convoy_release`). Two consequences: a hull whose driver moves to a new group keeps its old path order until cleared (so the taking-over loop clears the path first), and the lead must be the **frontmost** hull (followers trace its breadcrumb trail; Arma migrates leadership on death, and a rear leader reverses the column into a jam — the loop keeps leadership frontmost with `selectLeader` and hysteresis).

**Fix:** `selectLeader` is safe only because one loop owns each group; two loops sharing a group flip leadership every tick (which is why the deny tank now *joins* the convoy loop, not a second one).

## `group` of a vehicle object does not reliably name the crew's group

`group _vehicle` is defined for men, not a vehicle hull — on a crewed vehicle it doesn't dependably return the crew's group.

**Fix:** work from the men — `fnc_convoy_drive` walks `units _group` and takes each man's vehicle where he is its driver, so the hull list is built from group membership, never by asking a hull which group it's in (a hull whose driver left the group drops out for free next tick).

## A runtime error inside a `call`ed function halts the whole calling script, not just the callee

An unhandled runtime error in a `call`ed helper unwinds the entire call chain and stops the scheduled script at the call site — every statement after the `call` never runs, and the RPT names only the innermost file/line (the helper), so nothing hints the caller died too. A mission thread that `call`s a setup helper before its win/fail monitor: if the helper throws, the monitor never spawns and the mission can't be won or failed. `setUnloadInCombat` bit this way — it takes an **Object** (the vehicle), not a Group (the wiki's `groupName` wording misleads); passing a group throws `Type Group, expected Object`, killing the whole convoy-setup thread before its monitor existed.

**Fix:** apply `setUnloadInCombat` per-vehicle in a `forEach _vehicles`, never to the group. Treat any `call` before a load-bearing loop as able to take the whole script with it — keep such setup type-safe.

## `removeItem` cannot remove a worn uniform, vest, backpack, headgear or goggles

`removeItem "class"` only reaches loose items (magazines, attachments, container contents, assigned kit); the worn container/head/eyewear slots have their own no-argument commands, so `removeItem` on a worn uniform is a silent no-op. Code that strips gear generically through `removeItem` leaves clothing behind while looking like it worked.

**Fix:** dispatch the five worn slots — `removeUniform`, `removeVest`, `removeBackpack`, `removeHeadgear`, `removeGoggles` (each takes no class, so guard on the worn class, `uniform player == _cls`). The container commands discard contents (no keep-contents variant — re-add afterward). `DUWS_fnc_strip_n` (`initPlayerLocal.sqf`).

## `addMagazine` needs a container; arm a containerless civilian with `addWeaponItem`

`addMagazine` places the magazine into a worn container; several vanilla civilian costumes carry no uniform container, so the call fails silently and `addWeapon` then finds nothing to auto-load — the unit holds a gun it can't fire (the informant manhunt's fleeing informant drew a pistol that never shot).

**Fix:** load the magazine straight into the weapon, bypassing inventory:

```sqf
_unit addWeapon "hgun_Rook40_F";
_unit addWeaponItem ["hgun_Rook40_F", "16Rnd_9x21_Mag", true];
```

`addWeaponItem` works on any body class; the `addMagazine`-then-`addWeapon` order is safe only on units known to wear a container.

## `time` and `daytime` are different clocks; a world-clock timer cannot be built on `time`

`time` is real elapsed mission seconds (scaled by `setAccTime`, untouched by the day/night multiplier); `daytime` is the world clock in hours, sped up by `setTimeMultiplier` (this mission's `time_Multiplier`, 1–60×). Above 1× they diverge — `daytime` runs `time_Multiplier`× faster. Durations are meant in-game but targets are stored on `time` so the many `time > deadline` checks work: the `fnc_time_*` module bridges them (`fnc_time_deadline` divides an in-game duration by the multiplier to a `time` target; `fnc_time_remaining`/`fnc_time_clock` scale back up), so a "3-hour" deadline is three in-game hours at any multiplier. Safe only because `time_Multiplier` is set once at setup and nothing re-applies `setTimeMultiplier` mid-run — a mid-mission change would need `daytime`-based targets (accumulate `daytime` deltas, adding 24 on a negative delta for midnight):

```sqf
private _elapsed = 0; private _last = daytime;
while { _elapsed < _targetSecs } do {
    sleep 2;
    private _d = daytime - _last;
    if (_d < 0) then { _d = _d + 24 };
    _elapsed = _elapsed + _d * 3600; _last = daytime;
};
```

**Fix:** when formatting hours into a clock string, round to whole minutes before splitting h:mm — `floor` on the raw float lands a minute short when the fractional hour sits just under an integer (10.20 h × 60 = 611.99 → 10:11, not 10:12). `fnc_time_clock` does this.

## A road segment's `getDir` is not the direction of the road

`getDir` on a `"ROAD"`/`"TRACK"` object returns the model's own heading (usually `0`), not the way the carriageway runs, so `setDir (getDir _road)` parks a vehicle broadside. Direction of travel is the bearing to an adjacent segment:

```sqf
private _cons = roadsConnectedTo _road;
private _dir = if (_cons isEqualTo []) then { getDir _road } else { _road getDir (_cons select 0) };
```

**Fix:** use `roadsConnectedTo` for the bearing (`fnc_civ_traffic`, decoy cars). Placing on a road is also where cars detonate on spawn — `createVehicle [..., "NONE"]` drops the vehicle exactly where told, so a point holding a wall, rock or parked car spawns it clipping and the impulse blows it up (roadside stone walls are the usual culprit). Reject the point up front with `nearestTerrainObjects [_p, ["WALL","FENCE","ROCK","TREE"], 4]` and `nearestObjects [_p, ["Car"], r]`, don't trust the settle to shove clear.

## A `remoteExec`'d `BIS_fnc_taskCreate` floods `objectFromNetId` every frame the map is open

`BIS_fnc_taskCreate` `remoteExec`'d to every client serialises the task's owner and destination as live references; BIS's map draw re-resolves them by netId every frame the map is open, and on crossed references throws `[BIS_fnc_objectFromNetId]/[BIS_fnc_groupFromNetId] Error: type OBJECT/TASK, expected STRING` for the task's whole life — jamming the strategic map's task figure, tooltip and clicks (including the side-mission picker). The last argument is `visibleIn3D` (index 8), not a share toggle; passing `[]` + `setSimpleTaskDestination` doesn't help.

**Fix:** don't broadcast — call `BIS_fnc_taskCreate` server-side and let the task framework synchronise it to the owner side's clients (a native create keeps each reference as its own netId string, so a position destination draws clean). `fnc_missionTaskCreate`/`fnc_missionTaskEnd` do this with a position destination. Two related problems: `fnc_night_horde_event.sqf:56` passes `objNull` as destination (still a resolved reference — fix is `[]`; only bites in RAVAGE mode); and a curator/Zeus session as `game_master` throws a *look-alike* flood (discrete bursts tied to spot events, names live OPFOR units) that is not the mission's fault — unassigning `game_master` stops it.

## `uiNamespace` outlives a mission restart, but spawned loops do not

Variables in `uiNamespace` survive from one mission to the next in the same process; `spawn`ed scripts are terminated when the mission ends. So a `uiNamespace` bool guarding "this loop is already running" strands set with no loop alive — a restart kills the loop but leaves the flag, and every mission after skips the respawn. This silenced the whole subtitle system (`fnc_duws_dialogue_drain`) from the second mission of a session on.

**Fix:** guard on the loop's script handle, not a bool — `scriptDone` reads true once the loop is gone (a restart) and false while it runs (a JIP re-init in the same mission). `client_init.sqf` keeps the drain handle in `uiNamespace` and respawns on `isNull || scriptDone`. The persisted *data* is the other half: the dialogue queues also live in `uiNamespace` (so they don't serialize into saves), so a restart leaves the previous mission's un-played lines and the respawned drain flushes the backlog — a respawn must clear the queues it owns. A per-mission guard belongs in `missionNamespace` (torn down with the mission).

## `BIS_fnc_strategicMapOpen` offsets an icon's click hotspot when the offer position carries a Z

An offer handed to `BIS_fnc_strategicMapOpen` with a 3D `[x,y,z]` position draws its icon at the flat `[x,y]` projection but places the clickable hotspot using the full 3D point — a Z away from the surface slides the hotspot off the icon (small `|Z|`: one dead corner; large: misses entirely). The offer looks present but won't select, nothing reaches the RPT. The trap is a finder snapping an offer onto a `getPos`-derived centre whose Z the picker never sanitises (`getPos` on a coastal town Location returns a below-surface Z, −11 to −32 m), so the failure is intermittent by geography.

**Fix:** keep every strategic-map offer position 2D. `fnc_mission_findSite` flattens each finder's returned position to `[x,y]` before it becomes an offer, so a snapping finder (`fnc_informant_site`, `fnc_recon_observe_site`) can't leak a Z; the threads derive ground positions later and only ever measure the offer with `distance2D`.

## `BIS_fnc_findSafePos` returns the blacklist centre on failure, not `[]`

When `BIS_fnc_findSafePos` exhausts its attempts it returns the map origin, not a failure signal — `[0,0]` with the common `[[0,0],[0,0]]` blacklist, `[0,0,0]` with none. Either is a real-looking position (open sea off Altis' SW corner), and a caller treating any non-`[]` return as success accepts it. A side mission using `surveyKind "map"` sampled a coastal dot, got `[0,0]`, cleared every downstream gate (far from zones, far from co-offers, ~10 km from HQ within reach), and started in the water — the "draw another" path never fired because `[0,0]` was not `[]`.

**Fix:** after every `findSafePos` whose result feeds placement, reject the origin explicitly — `if (((_p select 0) == 0) && {(_p select 1) == 0}) then { /* no fit */ }`. No valid position on a real map is exactly `[0,0]`; don't rely on an `isEqualTo []` no-fit check (this function never returns `[]`).

## `doSuppressiveFire` needs line of sight and picks the heaviest weapon, so it levels a building

`unit doSuppressiveFire target` does nothing when the unit can't see the target, and when it fires it chooses the AI's best-rated weapon — a rifleman carrying a launcher fires the launcher. Suppressing a building the squad must keep intact then either produces no fire (no LOS) or destroys the objective (a rocket into the wall); both are the command behaving as documented.

**Fix:** force small-arms suppression with `unit forceWeaponFire [primaryWeapon unit, mode]` — it fires the named weapon regardless of LOS/target, and naming the primary keeps it to the rifle. Point the unit first with `doWatch pos`; resolve `mode` from `getArray (configFile >> "CfgWeapons" >> _w >> "modes") select 0` (a `["this"]` list means the mode name is the weapon name). `fnc_rescue_squad_mission.sqf`.

## `forceSpeed` is a ceiling on a native-driven hull but a setpoint on a `setDriveOnPath` one

On a natively-driven hull (`doMove`, waypoints) the path planner owns the throttle, so `forceSpeed` is only a ceiling — it caps top speed and `forceSpeed 0` halts, but can't make a stalled driver go, and used for spacing it fights native steering into stop-start twitch. On a `setDriveOnPath` hull the path drives and `forceSpeed` is a true setpoint (closes and holds a gap). `limitSpeed` is the soft cap for the native case (km/h; `forceSpeed` is m/s). Two more traps: `limitSpeed -1` does **not** remove the limit (a negative flies a helicopter in reverse) — "no limit" is a value past any top speed; and `forceSpeed 0` drops a `setDriveOnPath` hull off the path back onto native idle, so a later positive `forceSpeed` behaves as the native ceiling and the hull sits commanded-but-stationary until its path is re-committed (bites a convoy whenever the spacing controller clamps a follower to `forceSpeed 0`).

**Fix:** for a tight convoy put every hull (lead included) on a committed path with `setDriveOnPath` and hold the gap with `forceSpeed` (m/s); where native pathing must stay, space with `limitSpeed`. Reset any cap with a large sentinel, never `-1` (`fnc_convoy_drive.sqf` defines `CV_NOLIMIT` = `1e10`). Re-issue `setDriveOnPath` to a wedged hull (`speed ~ 0` for a few ticks) rather than trusting `forceSpeed` to restart it.

## `waypointPosition [group, 0]` reads `[0,0,0]`: index 0 is an implicit placeholder

Every group carries an implicit waypoint at index 0, whose `waypointPosition` reads `[0,0,0]`; user waypoints land at index 1 and up. Native-driven groups never trip on this (the engine advances `currentWaypoint` past 0 on its own). The wedge is a driver that indexes waypoints ITSELF (because it no longer native-drives the leader, so `currentWaypoint` never advances): starting at 0 reads `[0,0,0]` forever, so a convoy driver idled on the map origin and never reached the real destination at index 1.

**Fix:** when self-managing a waypoint index, step past any waypoint whose `waypointPosition` is `[0,0,0]` before using it (not just index 0 — a wrapped CYCLE or completed final leg can also land empty). `fnc_convoy_drive.sqf` advances `_legIdx` with `while { ... waypointPosition [_group, _legIdx] isEqualTo [0,0,0] } do { _legIdx = _legIdx + 1 }` and idles only when the index runs past the whole list.

## `getVariable` with a default returns `nil` on a null object, not the default

`_obj getVariable ["name", _default]` returns `_default` only when `_obj` is a *live* object missing that variable; on a **null** object it returns `nil` regardless. A `select`/`findIf` over `allUnits + vehicles` (either can hand back a null) that then compares (`_x getVariable ["k", -1] == _token`) evaluates `nil == _token`, which throws and aborts the whole `select` — so a filter that looks total silently returns nothing (a teardown that flagged its units this way flagged none).

**Fix:** guard the element first, short-circuited so `getVariable` never runs on a null — `(allUnits + vehicles) select {!isNull _x && {_x getVariable ["k", -1] == _token}}`.

## `setHitPointDamage` never moves `getDammage`, and field repair only touches hit points

A vehicle carries two decoupled stores: the hull value (`damage`/`getDammage`) and per-part hit points (`getHitPointDamage`). `setDamage` writes the hull (cascading to parts); `setHitPointDamage` writes one part and leaves the hull untouched — so a repair loop of only `setHitPointDamage` moves no health bar. The engine's field repair (no repair vehicle/point) restores **hit points only, capped** (~40% integrity / ~0.6 hit-point damage with a toolkit) and never clears the hull, so a mission testing `damage _veh` for "player repaired it" can never win by field repair. Stock Arma, mod-free.

**Fix:** detect field repair by testing hit points, not the hull — mean part damage (`fnc_veh_comp_damage`, `server/misc/`) against a threshold just above the ~0.6 cap. The structural `HitHull`/`HitBody` points do *not* field-repair (they hold spawn damage and pull the mean up), so the gate stays reachable only while field-repairable parts outnumber them ~3:1 — watch odd/modded hit-point layouts. Full script repair is `setDamage 0`; to immobilise a derelict, kill the engine hit point *after* `setDamage` (`fnc_veh_disable_engine`).

## A civilian-class unit made hostile by `createUnit` into an enemy group still reads Civilian in Zeus

A CIVILIAN-faction man created with `group createUnit [...]` straight into an EAST/WEST group doesn't reliably take that side — the curator/Zeus layer still lists and colours it Civilian (the side its config carries), so a game master sees a civilian where the mission has an enemy, and the unit won't open fire even set to COMBAT.

**Fix:** create it, then `[_unit] joinSilent (createGroup [EAST, true])` — re-grouping registers the live side for the curator icon and engagement while keeping the civilian costume. VBIED driver (`fnc_random_event_car_bomb.sqf`) and informant manhunt (`informant/fnc_informant_mission.sqf`).

## The `"Horn"` action is a player keybind; an AI honks by firing the horn as a vehicle weapon

`vehicle action ["Horn", vehicle]` (or on the driver) sounds the horn only for a player — "Horn" is an action-menu entry an AI has no entry in, so it's a silent no-op on an AI driver. The horn is really a vehicle weapon (`CarHorn`/`SportCarHorn`/`TruckHorn`, in the hull's `weapons[]`), so an AI beeps it by firing (the VBIED's run-in horn stayed silent for driving it through `action`).

**Fix:** read the hull's horn out of `weapons _veh` (class name contains `Horn`) and fire it with `_veh forceWeaponFire [_horn, _horn]` — a global effect on a local argument, so run it where the hull is local (a server-spawned event vehicle → the server, everyone hears it, no `remoteExec`). `BIS_fnc_fire` also works and adds the weapon first, but a civilian car already carries its horn.

## An AI driver will not run over a man on foot; it brakes and steers around, stopping short

A `doMove` at a player's position doesn't make an AI car ram them, even under CARELESS / `combatMode "BLUE"` / `speedMode "FULL"` — the pathfinder treats a person as an obstacle to avoid and a destination as a place to arrive, halting a few metres off, so a suicide car detonating on proximity never reaches its target on foot. Tightening arm range or fuse doesn't help.

**Fix:** accept the standoff — drive in on the pathfinder and detonate on proximity within arm range plus a short fuse (`fnc_random_event_car_bomb.sqf`). The alternative (scripting the last stretch with `disableAI "PATH"` + `setVelocity`) forces a hit but slides/snaps unnaturally. If you ever drive a hull by `setVelocity`: ramp the speed in a *script variable*, never by re-reading `vectorMagnitude velocity` — PhysX damps an externally set velocity on a wheeled hull within the tick, so the read-back returns near zero and the ramp collapses.

## A building door locks by variable, not command, and there is no per-door hit event

A house door is locked against the engine's "Open" action by setting `bis_disabled_Door_<N>` to `1` (clear to `0` to unlock) — there is no `lockDoor`. Opening a leaf is `animateDoor ["Door_<N>_rot", 1|0]`, a LOCAL effect (must run on every machine drawing the house). No event fires when a specific door is shot — only `HitPart`, on the whole object and the shooter's machine. Door count and source names vary by model, so a lock loop sets `bis_disabled_Door_1..N` over a bounded range and animates `Door_<N>_rot`; a mission depending on the mechanic must filter candidate houses to those defining `Door_1_rot` (`isClass (configFile >> "CfgVehicles" >> typeOf _h >> "AnimationSources" >> "Door_1_rot")`). Leaving `bis_disabled_Door_*` set outlives the mission (terrain houses are never deleted), so clear it to `0` on every end path or strand the town with unopenable doors.

**Fix:** for "shoot the door open", add a `HitPart` handler on all machines (see [§Practice targets ignore damage](#practice-targets-ignore-damage-entirely-hitpart-fires-on-the-shooter-not-the-owner)), then unlock every `bis_disabled_Door_*` and `remoteExec` the `animateDoor` sweep to `0` (all machines) from the server. Raid-safehouse (`server/missions/mission_threads/raid_safehouse/`): `fnc_raid_safehouse_arm` adds the `HitPart`, `fnc_raid_safehouse_breach` does the server-side unlock, the thread clears the lock variables on win/fail/cleanup.

## A `Draw3D` / `onEachFrame` block captures no local variables from where it was added

Code handed to `addMissionEventHandler ["Draw3D", {...}]` (and `onEachFrame`) runs in a fresh scope every frame, not the scope it was written in — a `private` from the enclosing function is `nil` inside at draw time (no closure). So a drawer needs everything reachable without a captured local: a mission-namespace global read inside, or a literal inlined. `fnc_draw_world_icons.sqf` puts its row table in the global `DUWS_icon3d_rows`; the furnish overlay (`client/debug/fnc_debug_furnish_view.sqf`) reads its mode from a global and inlines its palette. A palette left as an outer `private _palette` compiles clean and then draws nothing (or errors on the `nil`).

**Fix:** store per-draw state in `missionNamespace` globals set before the handler is added, or inline constants in the block. Tear down by the id `addMissionEventHandler` returns (`removeMissionEventHandler ["Draw3D", _id]`), never with a bare `onEachFrame {}` (which clears every stacked handler in the mission).

## An array cached with `setVariable` is a shared reference; a consumer that mutates it corrupts the cache

SQF arrays are reference types — `setVariable`, `pushBack` and plain assignment store the *reference*; only `+` deep-copies. So an array stashed on an object with `setVariable` and read back by a consumer that mutates it (or its nested arrays) writes through to the cache. The furnish grid (`fnc_furnish_grid.sqf`) caches its per-storey cell array on the building; the placer (`fnc_furnish_building.sqf`) stamps `occupied` on each cell — without a copy, a second furnish reads every cell already occupied and places nothing.

**Fix:** any function that reads a `setVariable` cache and writes into the returned structure must deep-copy first (`+value`). Grouping cached cells with `pushBack` copies only references, so mutating a grouped cell still writes through — the deep copy up front is what breaks the link.

## A command applied to an argument inside a `remoteExec` target trips a spurious `Missing ]`

`[msg] remoteExec ["hint", clientOwner _x]` — a command applied to an argument (`clientOwner _x`) directly in the target slot — makes the in-engine SQF parser reject the whole enclosing function with `Missing ]`, its caret on the target token, though the brackets balance. sqf-vm's parser accepts it, so the unit tests pass and the break surfaces only in the game `.rpt` at function-compile time — and a function that fails to compile is never defined, so the feature silently does nothing (a whole side mission failed to generate, no runtime error). It's not that computed targets are forbidden: `remoteExec ["addAction", [0,-2] select isDedicated, _hostage]` compiles (a bracketed/binary target is fine) — it's the bare command-applied-to-argument in that slot.

**Fix:** hoist the target to a local first — `private _owner = clientOwner _x; [msg] remoteExec ["hint", _owner];` — as every working call in the codebase does. More broadly, a green sqf-vm run is necessary but not sufficient: read the `.rpt` after a build.

## A non-existent command reads as two adjacent values and reports `Missing ;`, not "unknown command"

`_x disableSimulation true` — `disableSimulation` is not a command (the freeze is `enableSimulation false`), so the parser sees a value (`_x`), an unknown identifier, then another value with no operator between them, and reports `Missing ;` on the token after the phantom command. The error names a syntax fault, never the wrong name, so a plausible-looking typo'd or misremembered command sends you hunting for a missing semicolon that isn't the real problem. As with any compile-time break, a file that fails to parse never runs its body — and when that body's top level assigns a `DUWS_fnc_*` (this file defines `DUWS_fnc_opcom_advance` at its head), the function is silently left undefined, so every unrelated caller throws `Undefined variable` and the whole subsystem stalls with no hint at the true file.

**Fix:** when the RPT points `Missing ;` at a command call, first check the command exists and is spelled right, before trusting the semicolon story. sqf-vm accepts the bad token as an identifier, so this too clears the unit tests and surfaces only in the game `.rpt`. Read the RPT after a build.

## `setRain` shows nothing unless overcast is at least 0.5

Rain only renders over an overcast of 0.5 or higher; `setRain 1` under a clear sky shows nothing. `setRain` is otherwise independent of the overcast transition and can be set alongside it, but the 0.5 floor is hard, so a rain control decoupled from overcast in a UI can still come out dry — that is the engine, not a bug.

**Fix:** floor the overcast at 0.5 whenever rain is wanted, then set and force the overcast before setting rain: `if (_rain > 0) then { _overcast = _overcast max 0.5 }; 0 setOvercast _o; forceWeatherChange; 0 setRain _r;` (fnc_rest_heal.sqf). Setting rain after the forced overcast puts the sky in place first. Do it behind a black screen — the `0`-time force snaps the sky in one frame, which reads as a glitch if seen. The rest menu couples its overcast and rain sliders on the same 0.5 floor so the player never sets a dry combo.
