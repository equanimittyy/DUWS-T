# Arma engine gotchas

Engine behaviours that aren't visible in the SQF itself and cost real debugging time.
Each entry states the rule, why the engine forces it, and how to apply it. Add an entry
when an Arma-specific trap — not a plain SQF bug — burns a debugging session. For where
the mission's subsystems live see [`architecture.md`](../architecture.md).

## `remoteExec` to your own machine still runs a frame later

`remoteExec` never runs inline, even to the local machine — it queues a frame later and returns no handle, so a server-side validate-then-act (`if (pool < cost) exitWith {}` then `[-cost] remoteExec ["fnc_pool_writer", 2]`) is not atomic: a second request in the gap re-passes the check against the undebited pool. Fix: `call` a server-side function to run inline; reserve `remoteExec [..., 2]` for genuinely remote callers, and reply to a client by `remoteExec`ing a function at the player rather than returning a value (`fnc_pool_try_spend`/`fnc_pool_spend`, `src/duws/server/warcom/fnc_economy_init.sqf`).

## `remoteExec` drops a structured-text (`parseText`) argument

A `TEXT` object (from `parseText`) does not serialize across `remoteExec` — `parsedText remoteExec ["hintSilent", _pl]` arrives empty with no error, even to a local target (see [§`remoteExec` to your own machine still runs a frame later](#remoteexec-to-your-own-machine-still-runs-a-frame-later)); a plain `STRING` argument crosses fine. Fix: send the markup as a `STRING` and `parseText` it on the receiver — `[_markup, { hintSilent parseText _this }] remoteExec ["call", _pl]` (`fnc_rescue_hostage_mission.sqf`).

## The JIP queue is append-only unless the message carries an ID you choose

`remoteExec`'s third parameter decides what a *later*-joining machine receives:

| Third parameter | Effect |
|---|---|
| absent / `false` | fire and forget, current machines only |
| `true` | append under an engine-generated ID — never referenceable, never removable |
| a string | queue under that ID; a repeat call replaces, `remoteExec ["", id]` deletes |
| an object | queue under the object's `netId`; dropped when the object is deleted, which an intact terrain building never is |

A bare `true` backlog grows forever, and an object-keyed ID *is* that object's netId, so two entries on one object evict each other silently — the sabotage laptop's second intel entry once evicted its own breach action. Fix: key every entry that repeats — one entry per object self-cleans; two on one object need a suffixed string each (`format ["fob_guards_%1", netId _fob]`). Never queue a transient message (a one-off OSD or hint) at all.

## A scripted `#particlesource` renders only where it was set, unlike a config smoke object

A script-built particle source (`"#particlesource" createVehicle` + `setParticleClass`/`setParticleParams`) is local — it renders only on the machine that ran it, so a server-side spawn shows on the host alone. A config-backed emitter (`test_EmptyObjectForSmoke`, `test_EmptyObjectForFireBig`) is global instead. Fix: `remoteExec` the builder to all clients, JIP-key it to the parent object (see [§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose)), and compile it in `client_init.sqf`, not a server-only file. There is no free teardown (deleting an object only *detaches* `attachTo` children, and neither the `effects` array nor `fnc_duws_keep` reaps a machine-local source), so have each machine watch its parent and delete its own: `waitUntil { isNull _parent }; deleteVehicle _src` (`fnc_camp_smoke.sqf`).

## Never refresh a config fire object — deleting a burning one puffs smoke

A `test_EmptyObjectForFireBig` burns as long as it lives; deleting a still-burning one leaves a dying-smoke puff, so respawning on an interval reads as smog, not fire. Spawn with the **command form** `"test_EmptyObjectForFireBig" createVehicle _pos` — the array/placement form creates it dark (emitter never runs). Fix: spawn once at impact, run the damage loop over the burn window, delete only when it closes (napalm `fnc_arty.sqf`; the molotov, `fnc_molotov_ignite.sqf`, once regressed to the array form and spawned invisible fires).

## An Eden module in a composition is a logic a placer cannot build

A module placed in Eden (`ModuleEffectsFire_F`, and every other `Module*`) sits in a composition like any prop, but it is a logic entity with a brain and `createVehicle` refuses those — *"Vehicles with brain cannot be created using 'createVehicle'!"*. `fnc_composition_rows` keeps only `Object` entities, so the module never becomes a row and the effect it carried never appears, which reads as a prop that lost its flame rather than a class that was never built. Swapping the module for a config-backed object is the cheap route, but note the command form is then mandatory (see [§Never refresh a config fire object](#never-refresh-a-config-fire-object--deleting-a-burning-one-puffs-smoke)) — the placer's array form creates it dark. Fix: keep modules out of a composition, and rebuild what they did from a real class.

## Non-serializable handles must not live in the mission namespace

Never store a `DISPLAY`, `CONTROL`, `SCRIPT`, `LOCATION`, or other handle in a `missionNamespace` global — the namespace is saved and handles don't serialize, so the engine rejects the write (*"Variable X does not support serialization..."*). Booleans/numbers/strings/arrays are fine; `disableSerialization` grants no exception (it only skips local `_underscore` variables). Fix: keep display/control references in `uiNamespace` (never saved), read with a default and null-check — `isNull (uiNamespace getVariable ["myDisplay", displayNull])` — which also detects a dialog closed elsewhere (`fnc_factionSelector`, `src/duws/shared/factions/MODERN/fn_factionAutoDetect.sqf`).

## Nothing in SQF writes a file, and an extension cannot be shipped inside a mission PBO

The only durable write a mission reaches on its own is the profile-backed namespaces (`profileNamespace`, `missionProfileNamespace`) and the one-way `copyToClipboard` — there is no file-write command, and `callExtension` resolves only from a loaded mod folder or the game install, never inside a PBO. Antistasi defaults `missionProfileNamespace` **off on Linux servers** (`(productVersion # 6) isEqualTo "Linux"`). Fix: treat `missionProfileNamespace` as the store with a one-line `profileNamespace` fallback; serialise with `toJSON` (Arma 3 2.18+) and key by name (a hashmap tolerates a field added later; a positional array misreads older saves). Only a dedicated server can add a real file store (`-serverMod` extension) — SP and hosted cannot, since the host is the server. Reasoning: [`../campaign_persistence_plan.md`](../../plans/campaign_persistence_plan.md#where-the-save-lives); shape: [`campaign_save_format.md`](campaign_save_format.md).

## A variable first assigned inside `while do` does not survive the loop

`while {...} do {...}` runs its block in its own scope — a variable first *assigned* there is gone once the loop ends, so reading it after reads undefined; a `params`-declared neighbour survives, so the broken one looks like a typo. `fnc_missionTargetPos.sqf` returned `_randomPos`/`_Building` undefined this way for years, handing every side mission a blank position, its only trace an unattached `Error Undefined variable in expression: _randompos`. Fix: `private _x = <empty value>` above the loop for anything read after; `params` counts. Same for `for do`, `switch do`, `if then`.

## `params` on a single-array argument destructures it, not binds it

`X call code` sets `_this` to `X`; when `X` is one array and the block opens `params ["_a"]`, `params` binds `_a` to `X select 0` — the first element, not the whole array. `[_pos, _dir, _centre] call _fn` read with `params [["_anchor", []]]` gets `_anchor = _pos`, then reads its x as a position (`BIS_fnc_findSafePos`: `type SCALAR, expected ARRAY, on index 0`). Fix: when a `call`/`spawn` block's whole argument is one array wanted intact, use `private _a = _this`; keep `params ["_a", "_b", ...]` only for a list of distinct arguments.

## A typed `params` template logs to the RPT on mismatch, then falls back

`params [["_v", default, [typeTemplate]]]` doesn't *silently* coerce a wrong-typed value — it writes a "Type X, expected Y" RPT error first, then uses the default, so a template is wrong for a slot whose type legitimately varies (a `["_role", "", [""]]` meant to absorb a bool logged one error per gun per site). Fix: read a varying slot untyped (`["_role", ""]`) and coerce by hand — `if !(_role isEqualType "") then { _role = "" }`.

## `exitWith` exits only the innermost block, not the script

`if (cond) exitWith {...}` leaves only the code block that holds it. Nested in an `if/then` block or a `switch` case, it ends that block and the script continues after it; nested in an `if/then` block inside a loop, the loop keeps iterating. A guard nested this way does not stop the script: the operative recruit's CP check sat in a `switch` case, so a refused purchase hinted "no CP" and then deployed the operative unpaid. Fix: put a guard that must stop the script at the script's top level (`fnc_operator_recruit.sqf`), or set a flag inside the block and test it with `exitWith` at top level.

## `ctrlCreate` on a config display ignores the mission's base classes entirely

`ctrlCreate ["RscButton", idc]` resolves the class against the parent display's config before `missionConfigFile`; on `createDisplay "RscDisplayEmpty"` every control is the *engine's* base class, so overrides in `shared/includes/defines.hpp` never apply (wrong font, structured text left-aligned not centred, buttons grey not the mission's `{0.067,0.518,0.729,0.5}` blue). Fix: nothing at the source can outrank a display's own config — pin what matters after `ctrlCreate` (`ctrlSetFont`, `ctrlSetFontHeight`, `ctrlSetBackgroundColor`, `ctrlSetTextColor`) and put alignment in markup (`<t align='center'>`), as `client/dialog/fnc_HQ_faction_dialog.sqf` does. Controls declared in `.hpp` and opened with `createDialog` inherit normally.

## A `createDisplay` screen takes no cursor, and shares no draw order with a dialog beside it

`createDisplay` renders controls but puts no mouse pointer on screen; `createDialog` does. A screen built the first way is clickable only while a dialog is open beside it, and the two surfaces share no draw order — growing the faction display's panel over `startup_hq_placement_dialog`'s buttons can take them off-screen with no error. Fix: keep everything the player sees on one surface; `fnc_HQ_faction_dialog.sqf` owns every control and opens `shared/includes/hq_placement.hpp` empty purely for the cursor.

## Structured-text controls need a parsed object, not `ctrlSetText`

Set a `CT_STRUCTURED_TEXT` control with `ctrlSetStructuredText (parseText "<t ...>...</t>")`, never `ctrlSetText` — the latter stores the string verbatim, so `<t>` markup renders as literal text, silently. Fix: `_ctrl ctrlSetStructuredText (parseText _markup)` to set, `parseText ""` to clear (`fnc_factionSelector`).

## `ctrlSetStructuredText` has no IDC form, and the parse error voids the whole file

`ctrlSetStructuredText` exists only as `control ctrlSetStructuredText text` — no `[idc, text]` overload (unlike `ctrlSetText`/`ctrlEnable`/`ctrlShow`/`lb*`) — and writing one fails at *compile* time: `compile preprocessFileLineNumbers` logs `Error Missing ;` then a no-op block, so every function the file defines silently returns without running — a mile from the cause, and buried under dozens of registration paths. Fix: take the control first — `(_display displayCtrl 8603) ctrlSetStructuredText parseText _markup`; in an EH read the display the `onLoad` stashed (`uiNamespace getVariable ["duws_faction_confirm_display", displayNull]`, `client/dialog/fnc_faction_confirm.sqf`, `fnc_faction_prompts.sqf`). When a setup screen never appears, grep the RPT for `Error Missing ;` first.

## Listbox rows show `<t>` markup literally; `addAction` titles render it

`lbAdd`/`lbSetText` store row text verbatim, so `<t color=...>...</t>` shows as literal tag characters; `addAction` titles are drawn as structured text and render the same markup fine — so a label fine as a scroll action (e.g. `STR_DUWS_T_HIRE_PMC`, colour baked in) breaks in a listbox. Fix: strip `<...>` tags before `lbAdd` and colour the row via `lbSetColor [idc, index, [r,g,b,a]]` (`src/duws/client/dialog/fnc_open_action_menu.sqf`).

## `lbSort` by IDC needs a direction, and the missing one aborts the whole fill

The array form is `lbSort [idc, "ASC" | "DESC"]`; `lbSort [idc]` (missing the direction) throws "1 elements provided, 2 expected" — a runtime error that halts the rest of the block, so a fill sorting one list partway loses everything after. Fix: always give `lbSort` its direction; bare-IDC commands act on the top display, so a multi-list fill passes `[idc, "ASC"]` for each.

## `BIS_fnc_showSubtitle` is one slot: the next call wipes the line mid-read

A second `BIS_fnc_showSubtitle` replaces the screen immediately — no queue, no reported hold/clear time (`fnc_arty.sqf:36`/`:49` post two lines a frame apart) — so two supports narrating at once means only the second is read. Fix: never call it from more than one place; `fnc_duws_dialogue` queues, `fnc_duws_dialogue_drain` (`src/duws/client/misc/`) holds the single call and spaces lines by `1.5 + 0.045 × length` seconds.

## Duplicate `<Key ID>` in stringtable.xml resolve to one definition, silently

A `STR_` ID repeated in `src/stringtable.xml` loads without error, but the engine keeps one definition — editing the dead copy changes nothing, and reordering keys can flip which wins (IDs resolve globally across `<Container>` sections). Fix: keep the table deduplicated; when an edit does nothing in-game, grep for a second `<Key ID>` and fold it into one copy.

## A config class opened with a body twice at one scope warns, and the RPT line points past it

Two `class Foo { ... }` blocks at the same scope in the merged `description.ext` log `.Foo: Member already defined`; the engine merges them, but the reported line is the token *after* the second block, not the block itself — an `#include` opening `class CfgMagazines` colliding with an inline one reported `line 53`, which was the following `class CfgWeapons`. Fix: keep one bodied block per top-level config class across the include chain; read the class named (`.CfgMagazines`), not the line cited.

## `format` discards surplus arguments, so a missing `%N` never errors

`format` drops any argument with no matching `%N` — no error — so a string with fewer placeholders than args renders plausible-but-wrong forever, and a *duplicated* placeholder (`"%1 %2-%2"` on `[_name,_d1,_d2]`) hides best. The boat taxi's eight `format` calls handed args to placeholder-less strings with no complaint; localisation multiplies exposure. Fix: treat the placeholder set as a contract with *every* language variant — grep the `format[...]` call, count args, confirm the highest `%N` matches in each language tag.

## `format` does not print a literal `%` written in its string

A bare `%` in a `format` string is dropped: the shop price line `"%1 money (%2% discount)"` rendered `20 discount`, with no error. Fix: pass the sign as an argument — `"(%2%3 discount)"` on `[_price, _pct, "%", _money]` (`client/dialog/fnc_vendor_catalogue.sqf`, `client/missions/fnc_recon_observe_layer.sqf`).

## Config text is shown verbatim, so a `%N` in it reaches the player unsubstituted

A `$STR_` reference in config (`CfgDebriefing`, action names, `displayName`) is resolved and displayed as-is — no call site hands it arguments, so a shared key that gains a `%N` in a script use (the defeat notification in `server/misc/fnc_capture_zones_task.sqf`) renders literal `%1` on the config side (the outro card, `shared/includes/debriefing.hpp`). Fix: a `%N`-bearing key belongs to script call sites only; give config its own placeholder-free key.

## `localize` on a finished sentence looks it up as a key and speaks nothing

`localize` only translates a stringtable ID; handed anything else it treats the string as a key, misses, logs `String <text> not found`, and returns nothing. `fnc_mission_finish` localises its line argument, so a caller handing it a finished sentence goes silent. Fix: a line needing a runtime `%N` is finished text — build and speak it at the call site (`fnc_duws_dialogue`) and hand finish `[]`.

## `GIF pre stack size violation` means `if` got no value

`if` needs a Boolean on the stack; a condition that returns nothing leaves the stack empty, and the engine logs this cryptic line instead of a type error. The usual source is a function that returns nothing. `fnc_pos_near_enemy.sqf` wrapped its body in `fnc_pos_near_enemy = {...}` while `server_fnc_init.sqf` compiled the file into that same name, so the first call on each machine only ran the assignment and returned nothing, and the FOB request died on its first check. Fix: a file loaded with `compile preprocessFileLineNumbers` is the function body itself — never assign the function's own name inside it.

## A code block sees no locals from where it was written unless it is `call`ed

SQF blocks are not closures — a block sees the privates of whatever `call`ed it and nothing else; run it via `spawn`/`execVM` and every enclosing private is gone. `fnc_civ_garrison.sqf` `spawn`ed a block reading `_centre`/`_radius` from around it; both were nil in the new thread, so the town got no garrison (correct form: `[_i, _centre, _radius] spawn _fnc_fill` read with `params`, as `fnc_civ_handler.sqf` does). This is why the launcher blocks in `shared/includes/mission_types.hpp` each carry a hard-coded index — an index is the one thing such a block can hold without capturing. Fix: pass everything a `spawn`ed block needs through `_this`/`params`, or `call` it; when a fix would delete a global a deferred block reads, preserve the deferral, not just the value.

A `call`ed block also sees the innermost private of a name, not its writer's: a function between the writer and the call that declares the same name shadows it. A candidate block handed to `fnc_hardpoint_lay` that read a `_pool` of its own would get `fnc_hardpoint_best_ground`'s weighted-site `_pool` instead. Fix: name a block's captured locals so that no function on its call path declares the same name (`fnc_hardpoint_place.sqf`, above `fnc_hardpoint_site_flank`).

## A trigger statement is a string, so anything formatted into it is a float round trip

`setTriggerStatements` takes source text, not a closure — a captured local written in with `format` round-trips a number through a string, which is not guaranteed to compare equal (fails only against `==`/`isEqualTo`/`in`). `fnc_createzone.sqf` formats `_zonePos` into the capture trigger, so `WARCOM_zones_controled_by_BLUFOR` holds a text-derived position while the zone code holds the original. Fix: prefer `thisTrigger setVariable` over interpolation. Where a position must match one that went through a statement string, match by distance (`_a distance2D _b < 1`), not equality — an *identity* test, not a proximity one, so comment the difference from `fnc_site_poller`/`fnc_duws_bluforNear` ranges.

## `hint` renders beneath the open map, so map-phase prompts are invisible

A `hint`/`hintSilent` issued while the map is open (`forceMap`/`openMap`) draws into the hint box, *under* `findDisplay 12` — it fires but is never seen, so a "click on the map" instruction before `onMapSingleClick` looks broken. `titleText`/`cutText` share the problem. Fix: draw the prompt on the map display itself — a static `RscStructuredText` control on `findDisplay 12` set with `ctrlSetStructuredText` (static controls are click-transparent, so `onMapSingleClick` still fires): `src/duws/client/dialog/fnc_map_prompt.sqf`; pass `""` to clear before `openMap [false, false]`.

## `hint` takes no duration, so a longer readout must be re-issued

`hint` and `hintSilent` have no duration argument, and no command reads or sets the time before the engine fades the box. A long readout can fade before the reader finishes it. Fix: hold it with `hintSilent` re-issues of the same text inside the fade window, because each re-issue restarts the fade. Stop the re-issues when a newer readout replaces the text, or an old readout paints over the new one (`src/duws/server/debug/fnc_debug_ledger_hint.sqf`).

## `onMapSingleClick` is one global slot: the next installer steals the previous one's click

There is exactly one map-click handler per machine; a second `onMapSingleClick` overwrites the first with no error — two features that each open the map and wait on a click collide, and only the second ever fires. Fix: arbitrate the slot by one owner name in `uiNamespace` — claim with `["MODE", _handler] call fnc_mapclick_claim`, release with `["MODE"] call fnc_mapclick_release` (`server/misc/fnc_mapclick_init.sqf:25,68`); claiming while another holds is refused and said to the player, release restores the background listener. Spawn `waitUntil { !visibleMap }` to release on the player closing the map (`client/missions/fnc_map_readout_open.sqf:27-35`) — the engine gives no callback.

## A click handler's `_pos` belongs to the engine, not to the local of the same name beside it

Code handed to `onMapSingleClick` is a string the engine compiles in its own scope, binding `_pos`/`_units`/`_shift`/`_alt` itself — an installing-scope local of the same name never reaches it: three sites declare `_pos = [];` above a handler string mentioning `_pos` and none use it (`fnc_WARCOM_mapclick_assault.sqf:6`, `fnc_mapclickuav.sqf:6`, `fnc_mapclickarty.sqf:50`), harmless but confusing to a dead-code search, which counts the name inside the string as a use. Fix: treat a handler string as a separate scope; substitute an installing-scope value via `format` or `_this`, and blank string literals before any tool counts local uses.

## A mission event handler id is a per-event index, not a unique handle

`removeMissionEventHandler ["EntityCreated", _id]` addresses a *position* in that event's handler list, not a unique handle — remove by a stored id later and you unhook whichever handler now sits there. `EntityCreated` has three sharers (`fnc_scanEnemyGear.sqf` plus two autodetect retexture handlers, `AUTODETECT_blufor.sqf`/`_opfor.sqf`, that never remove themselves), so a wrong id silently breaks faction detection. Fix: prefer a handler that never needs removing, gated on a flag; where removal is required, capture the id in the same scope that registered it, and don't remove by id at all on an event type another system also hooks.

## Diary records display newest-first, so add them bottom-up

`createDiaryRecord` prepends — the record created last draws at the TOP. Record text is structured text, but in `stringtable.xml` the markup must be entity-escaped (`&lt;br/&gt;`) or the parser eats the tag. Fix: keep entries in an array in display order and `reverse` once before the `forEach` (`fnc_duws_help.sqf`).

## An unescaped `&`/`<`/`>` in a diary body blanks the body but leaves the title

Diary record text is structured-text XML, so a bare `&`, `<` or `>` anywhere in the body voids the whole body parse — the title still shows (plain text), so the symptom is a tab that lists but renders empty (a header like `"FORCES, ECONOMY & WORLD"` compiles, the tab appears, and the `&` opens an entity that never closes). Fix: escape body literals as `&amp;`/`&lt;`/`&gt;`, including any dynamic value spliced in (a faction name or callsign carrying `&`).

## `for "_i" from A to N step 1` runs `floor(N)+1` times, truncating a fractional bound

`for "_i" from A to N step 1` advances while `counter <= N`, so a fractional `N` stops at `floor N` — `1.5` behaves identically to `1`, with no warning. Fix: resolve a fractional multiplier to an integer before the loop (`_n = floor _m; if (random 1 < (_m - _n)) then { _n = _n + 1 }` for probabilistic rounding), then loop `to _n`; `DUWS_fnc_scaleComposition` (`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf`) does this.

## Scheduled scripts share ~3 ms per frame, so a long loop runs at frame rate

Everything `spawn`/`execVM`'d runs in the scheduled environment, where the engine gives *all* such scripts ~3 ms per frame between them — a loop body costing more than that slice gets one iteration per frame, so its wall-clock tracks frame rate, not work done (the terrain survey (`fnc_moreUrban_locations.sqf`) measured a flat ~50 candidates/second regardless of run size — the signature of a scheduler-bound loop that only appears to hang). Fix: batch the work inside `isNil { ... }`, which runs unscheduled and uninterrupted and shares the calling scope (`sleep`/`waitUntil` cannot be used inside). Bound each batch by a wall-clock deadline, not an iteration count, and yield between batches; a 15 ms budget took the survey to ~259/second.

## A `remoteExec`'d function runs as a new scheduled script, so a timed request loop stacks copies

`remoteExec` of a function spawns it on the receiver as its own scheduled script, and nothing waits for the previous copy to finish. A loop that requests on a fixed period (`remoteExec` then `sleep 5`) therefore starts a new copy each period even while the last one still runs. When one run takes longer than the period, the copies share the ~3 ms slice (see [§Scheduled scripts share ~3 ms per frame](#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)), so each copy runs slower and more copies start. The pile-up does not recover. The OPCOM overlay draw (`fnc_debug_opcom_grid_draw`) grew to 13 concurrent copies and stopped updating for two minutes. Fix: keep one request in flight. Set a pending flag before the request, clear it at the end of the reply, and wait on the flag with a timeout before the next request (`client/debug/fnc_debug_opcom_view.sqf`).

## A shared array written from two scheduled scripts is consistent only across a suspension-free section

Scheduled SQF is cooperative — control passes only at a suspension point (`sleep`, `waitUntil`, a yielding `call`), so a read-modify-write on a shared array is atomic *only if no suspension falls between the read and the write*. OPCOM belief is written by the perception loop (`fnc_opcom_perception_run`) and, concurrently, a `remoteExec`'d debug burst (`DUWS_fnc_hardpointOPBurst`) on its own thread; it stays consistent only because every belief stamp (`findIf` then `pushBack`/`set` across four parallel `DUWS_opcom_belief_*` arrays) runs suspension-free. Fix: keep each belief write one unbroken block — a `sleep`/`waitUntil` inside it lets the other script interleave and tear the index alignment the arrays depend on.

## A shared global mutated as `x = x - c; publicVariable "x"` loses concurrent writes

`publicVariable` broadcasts an absolute value with no network lock, and each machine keeps its own copy — two machines that read-modify-write a shared global both read the stale base, and the later broadcast overwrites the earlier, so changes don't add up (resource can even be *created*: two clients spending 30 against a shared pool of 50 nets −20, not −40). Local `x = x + n` is atomic; the loss is the stale base a second machine read. SP has one machine, so this only surfaces in co-op, and a save persists the corruption. Fix: never `publicVariable` a shared resource from a non-authoritative machine — route every change through one server-side function taking a signed *delta* (`x = x + _delta; publicVariable "x"`), callers sending `[_delta] remoteExec ["fn", 2]` and never touching the global (`fnc_cp_adjust`, sole writer of `commandpointsblu1`; it also refreshes the local counter when `hasInterface`, since the host's `publicVariableEventHandler` doesn't fire for its own broadcast). See [`economy.md`](../gameplay/economy.md#authority-the-server-decides-a-purchase-not-the-buyer).

## A joining client is sent every `publicVariable`'d global, then its own init overwrites them

`publicVariable` is JIP-persistent — the engine delivers the last broadcast value to a joining client *before* the mission's own client init runs, so a per-client init that then assigns the same global unconditionally clobbers it, silently. Invisible on a host or in SP. Fix: guard every client-side init of a broadcast global with `if (isNil "x") then {x = default};` — assigning unconditionally is correct only for never-broadcast globals, so keep the decision to `publicVariable` and to initialise in step by hand (`client/includes/supports_init.hpp` guards three flags and assigns three unconditionally while `fnc_request_support.sqf` broadcasts all six, [`../../KNOWN_ISSUES.md`](../../../KNOWN_ISSUES.md#open-defects)).

## Weather set on the server synchronises itself, so mirroring it into a global is dead state

`setOvercast`, `setFog` and `setDate` are artificially synchronised — run on the server, the engine propagates to every client and joiner, so copying the value into a broadcast global adds nothing and rots (the usual shape broadcasts a placeholder once then writes every cycle *without* re-broadcasting). Fix: read the sky through `overcast` and `fogParams` on any machine; never mirror weather into a global. `setRain` is independent.

## Waypoint and flight commands are ignored unless the group is local to that machine

`addWaypoint`, `deleteWaypoint`, `flyInHeight`, `setMass` and `ropeCreate` take effect only where the group/object is local — issued elsewhere they fail silently, and locality follows the creator (a client-spawned group belongs to that client, so `remoteExec [..., 2]` delivers to a machine that can't act). `fnc_helolift` spawned its heli client-side then `remoteExec`'d waypoints to the server, and defined server helpers in a client-only file — invisible to a hosting player. Fix: decide which machine owns an AI group before commanding it, spawn it there, route every order back to it; a `remoteExec`'d-by-name function must be in the registry so the receiving machine has it.

`allowDamage` is machine-local and does *not* travel with ownership — a vehicle made invulnerable on the server turns vulnerable the instant a client takes it (R3F's carry `setOwnerTo`s the object to the carrier), because the new owner never ran `allowDamage false`. Fix: re-assert it on whichever machine holds the object at each step (`server/supports/fnc_garage_init.sqf` → `client/dialog/fnc_depot_place_r3f.sqf` sets it server-side at spawn, again on the carrying client, restores only after `setOwner 2` reclaims it). R3F's carry-end handler (`R3F_LOG_FNCT_PVEH_fin_deplacement_objet`) also runs `allowDamage true` on every machine when a carry ends, so a guard that must outlast the carry is set again after it (`fnc_depot_place_finish` holds it over the thaw's settle).

## Practice targets ignore damage entirely; `HitPart` fires on the shooter, not the owner

The `TargetP_*` range targets don't process bullet damage — `Hit`/`HandleDamage` never fire whatever `allowDamage` is, so a server-side damage handler waits forever. `HitPart` does fire, but on the machine that *fired the round*, not where the object is local — the opposite of every other damage handler, so a server-only EH stays silent for every client shot. Fix: add the handler on every machine with `remoteExec ["addEventHandler", 0]` and send the result to the state owner, passing the object as the JIP parameter (see [§The JIP queue is append-only](#the-jip-queue-is-append-only-unless-the-message-carries-an-id-you-choose)); killhouse (`server/killhouse/fnc_createKillhouse.sqf`) bounces each hit to `killhouse_srv_target_hit`.

## `setMarkerColor` accepts an inline `#(r,g,b,a)` string, not only a `CfgMarkerColors` class

A marker colour need not be a class name — a literal `"#(0.5,0,0.5,0.3)"` renders that colour, so shades outside the stock `Color*` set need no `CfgMarkerColors` block (looks like `setObjectTexture` syntax, so existing code using it reads as broken but isn't — civilian town ellipses, `fnc_civ_init_Tomata.sqf`). Fix: use the inline form for one-off shades, `CfgMarkerColors` for editor-picked ones; set translucency with `setMarkerAlpha` (default sits at 1).

## A label needs a real icon marker type; the invisible `"Empty"` type paints no text

`setMarkerType "Empty"` (Eden's invisible/system marker) was meant to carry text with no icon, but the map draws nothing for it, silently — there is no icon-less marker that renders `setMarkerText`. Fix: pick a real icon type from the marker table ([`external/arma3_markers.md`](../external/arma3_markers.md)) and accept the icon beside the text (the OPCOM coverage overlay uses `mil_triangle_noShadow`, `fnc_debug_opcom_grid_draw.sqf`); if a bare label is essential, draw it via the map control's `Draw` EH (`drawText`) instead of a marker.

## `str` on a string adds literal quote characters, and this mission's marker names carry them

`str "12345678"` returns the source representation — quote characters included. Zone markers are created as `createMarker [str(_markername), _zonePos]`, so the real name *includes those quotes*, and every later `setMarkerAlpha`/`setMarkerColor`/`setMarkerPos` must spell it the same way; dropping the `str` on one side addresses a marker that doesn't exist (no error, zone stays invisible). Fix: in `server/init_zones/`, treat `str(_name)` as part of the marker's identity and grep sibling accesses before touching either half (`fnc_createzone.sqf:45,59`, addressed in `fnc_zone_reveal.sqf`/`fnc_captured.sqf`). Names built without `str` are addressed without it — the rule is per-marker.

## `diag_tickTime` counts from process start and is not restored by a savegame

`diag_tickTime` is Arma's uptime (thousands at mission start, zero on relaunch, not saved); `time` is mission time (near zero at start, saved) — neither is "seconds since this mission started". A cooldown on `diag_tickTime` locks for the previous session's whole length after an autosave resume, so its "never used" default must be *negative*. A third clock, the campaign date, is what a *skippable* cooldown must use: `skipTime` moves neither `time` nor `diag_tickTime`, but `dateToNumber date` (×8760 = hours) moves with resting and Zeus; `setTimeMultiplier` scales the date *and* `time` but not `diag_tickTime` (same split as `sleep` vs `uiSleep`). Don't fold the year into the figure — 32-bit float precision at millions-range exceeds a short cooldown. Fix: pick one clock per cooldown — campaign date where resting should shorten the wait; `time` where a savegame must carry it and neither may shorten (`fnc_mission_cooldown_left.sqf`); `diag_tickTime` only where it should die with the session. Repair only a stamp *ahead* of its clock — clear it and let the default apply (`server/server_init.sqf:441`).

Where a wait must survive a savegame **and** shorten on a rest, no single clock serves: use `time` plus a broadcast accumulator of skipped seconds, `DUWS_timeSkew` (serializable, bumped by every `skipTime` in `server/dialog/fnc_rest_heal.sqf`). Build deadlines on `fnc_campaign_now` (`time + DUWS_timeSkew`) and `fnc_time_expired`, never raw `time` — any new `skipTime` must bump `DUWS_timeSkew` in the same breath or every deadline desyncs. `daytime` moves 1:1 with the campaign clock, so a baked "until HH:MM" (`fnc_time_clock`) stays correct across rests without recomputation.

## An `Acts_` ambient animation survives death, so the corpse stands and shrugs off hits

A unit in an `Acts_*`/`acts_*` ambient animation via raw `switchMove` stays in it when it dies — no death transition, no ragdoll, body upright, so incoming fire produces no visible reaction though `alive` is already `false` (scripts see `Killed`, `!alive` correctly; the divergence is purely visual). `BIS_fnc_ambientAnim`/`...Combat` install their own break handlers, so a hand-rolled `switchMove` differs. Fix: add a `Killed` handler that clears the move — `[_unit, ""] remoteExec ["switchMove", 0]` (broadcast; `switchMove`/`playMoveNow` are local). Broadcast and JIP-key the *pose* too, and drop that JIP entry in the `Killed` handler (`remoteExec ["", _key]`) or a late joiner gets the pose on a corpse; the handler is load-bearing only once the unit is killable (`allowDamage false` units never reach the bug — HQ officer/engineer, `server/init_hq/fnc_BluHQinit.sqf`). **For a held stance, prefer `setUnitPos "MIDDLE"`/`"DOWN"`** — a living idle, global for a server-owned unit, no broadcast/JIP/death handler needed; reset with `"AUTO"`. A raw `switchMove` into an `acts_` crouch idle can freeze in a visibly wrong half-crouch.

## `side` of a dead unit is civilian, so an enemy-corpse test must not read `side`

Once a unit dies the engine reports it on side `civilian`, whatever it fought as — `side _corpse == east` is false on every OPFOR body, so any check gated on it silently never fires (a `Killed` handler running `side _unit` at the instant of death still catches the fighting side, which is why that shape breaks only on a settled corpse). Caching side at spawn re-exposes it to a body-swapping GC (AGC mod rebuilds distant corpses). Fix: identify an enemy corpse by config side — `getNumber (configFile >> "CfgVehicles" >> typeOf _corpse >> "side") == 0` (0 east, 1 west, 2 independent, 3 civilian) — death-stable and corpse-swap-safe (`client/search/fnc_intel_search_action.sqf`).

## An `addAction` outlives its owner, and a `_this == player` condition shows the body's copy to the respawned player

An action added to the player stays on the body after death. In a condition string, `_this` is the unit viewing the action, not the object that carries it, so a `_this == player` gate is true for the respawned player standing near the old body: the scroll menu lists the earplugs and the debug menu twice. The engine also keeps polling the conditions of actions on any object near a player, so each body left carrying them adds its conditions to that poll for the rest of the campaign. Fix: `removeAllActions player` in `onPlayerKilled.sqf`, and add fresh actions in `onPlayerRespawn.sqf`.

## A captive unit's `side` reads civilian, but its `side group` does not

`setCaptive true` makes `side _unit` report `civilian`, but the unit stays in its group, and `side group _unit` still reports the group's side. Both disguises set the player captive (`server/disguise/fnc_disguiseAsEnemy.sqf`, `server/civilian/fnc_disguiseAsCivilian.sqf`). The site poller built its BLUFOR pre-gate on `side _x == WEST`, so a lone disguised player never woke an OPFOR zone, hardpoint or town garrison, and a site that was already awake stowed around the player when its grace ran out. Fix: filter BLUFOR presence on `side group _x`, which captive state does not change (`server/misc/fnc_site_stream_init.sqf`).

The reverse also holds: a `side group` test sees straight through a disguise, and so does a group scan such as `allGroups select { side _x == west }`. A BLUFOR test that must respect a disguise, such as an OPFOR sensor, must check the disguise itself.

## `knowsAbout` is a decaying knowledge scalar, not a current-visibility flag

`side knowsAbout target` returns a 0–4 aggregate that rises while sensed and *decays over seconds-to-minutes* after contact breaks — it is not "visible now", unrelated to position, and side-wide. Sampling live position on `knowsAbout > threshold` keeps reporting the *current* position through the whole memory tail, so a "last seen" follows an unobserved target and a teleport drags the stamp along (OPCOM's sensor bloomed force at a player's HQ after fast-travel this way; the scalar reads flat-high whether watching a mover or a ghost, so an edge/derivative gate does **not** fix it). Fix: read the engine's own last-seen instead — `unit nearTargets range` returns `[pos, type, side, cost, object, age]` per observer, `age` being seconds since last pinned (not a timestamp; the engine re-fixes on its own sensor cycle every few seconds, so `age` sawtooths even on an actively-watched target — a freshness gate must be at least that cycle: `OPCOM_TICK_PERIOD` (5 s) works, 2 s reads an in-view player as unseen on most ticks, `missions/mission_threads/rescue_hostage/fnc_rescue_hostage_mission.sqf`). `unit targetKnowledge target` carries the same, per observer — aggregate over a bounded observer set, never side-wide. `server/warcom/opcom/belief/fnc_opcom_sense.sqf` stamps a fresh-age group at the observer's *remembered* position (not live) and lets an unsensed group decay.

## A `Killed` handler added on the server does not fire for a client-local unit

A unit EH runs only on the machine that added it, and `Killed` fires there when the unit is local — a server-side `Killed` for a client-local unit (a player, or AI in a player's group) may never reach the server, hidden in SP where every unit is local. Server-spawned units are server-local, so this pattern is safe for them (`DUWS_fnc_garrisonReserveWatch`, `server/init_zones/fnc_garrison_reserve.sqf:158-180`); a player's own death handler is added on that player's client (`modules/AIS/Core/fn_aisInitPlayer.sqf`). Fix: to react server-side to a client-local unit's death, add the handler where it's local and `remoteExec` the fact to the server, or *poll* server-side for a whole side — OPCOM's belief prune (`server/warcom/opcom/belief/fnc_opcom_belief_prune.sqf`) resolves each believed group by `netId` every tick (`groupFromNetId`) and drops it when none is alive.

## `enableSimulation` is local, so a server-side freeze leaves clients simulating

`enableSimulation` affects only the machine it runs on; `enableSimulationGlobal` (server-only) reaches everybody. A unit/prop frozen server-side then `setPosWorld`'d sits still on the server while every client keeps simulating it and renders it falling permanently — invisible in a host-only test. Fix: use `enableSimulationGlobal` for anything a client also renders, including a transient placement freeze; `fnc_duws_deploy` (`server/misc/fnc_composition_stream_init.sqf`) pairs global simulation with local `allowDamage` (server-local damage resolves server-side, and broadcasting per prop costs a JIP entry each).

## An unsimulated object does not fall, so placing one in the air parks it there

Physics runs only while simulation is on — `setPosWorld`/`setPosATL` on a sim-disabled object puts it exactly where told and leaves it: no fall, no settle, no error. Compositions carry the flag in their stow record (`fnc_duws_stow` writes `simulationEnabled _x`), so an object frozen at build time comes back frozen a campaign later. Fix: never assume an object you didn't just create is simulated; where placement depends on falling, assert `enableSimulationGlobal true` (per [§`enableSimulation` is local](#enablesimulation-is-local-so-a-server-side-freeze-leaves-clients-simulating)) *after* the position is written (`DUWS_fnc_dropStatic`, `server/init_zones/fnc_zone_stream_init.sqf`).

## `createVehicle` of an `Item_*` class makes a simulated holder that PhysX flings off a surface

Spawning loot by its `Item_*` ground class (`createVehicle "Item_MobilePhone"`) yields a `WeaponHolderSimulated`, a PhysX body ejected off a table/shelf on the next step; `enableSimulationGlobal false` only freezes it wherever it floated (per [§an unsimulated object does not fall](#an-unsimulated-object-does-not-fall-so-placing-one-in-the-air-parks-it-there)). A `GroundWeaponHolder` has no PhysX and stays where placed, but an empty one self-deletes in ~1 s; cargo takes the *bare* inventory class (`addItemCargoGlobal` for `CfgWeapons`, `addMagazineCargoGlobal` for `CfgMagazines`), not the `Item_*` body. Fix: place pickup-able loot through `fnc_place_settled`'s `_asLoot` mode (`server/placement/fnc_place_settled.sqf`); set-dressing never picked up can stay a plain `Land_*` prop. `server/debug/fnc_debug_spawn_intel.sqf` shows which intel classes have an `Item_*` body and which cargo slot each takes.

## `moveInGunner` into a simulated static leaves the turret dead; seat it frozen, then thaw

A static crewed *after* its simulation is enabled keeps a gunner who never traverses (fires only down its placed heading) — the turret AI comes up only as the gun transitions unsimulated→simulated with a gunner aboard, so a gunner added to an already-running gun never gets that pass (`simulationEnabled` reads `true` either way — only the turret is inert); seat-then-thaw is right, thaw-then-seat is wrong. Fix: seat every static while frozen, then thaw — `DUWS_fnc_seatStatic` is the single seat step (re-freeze, `moveInGunner`, thaw), called by `DUWS_fnc_crewCompositionStatics` (prefab) and `DUWS_fnc_manStatics` (stream re-crew, hardpoints). A crewed gun that fires but won't rotate is this bug until proven otherwise. It is the frozen arrival that matters, not the `StaticWeapon` class: an artillery battery's self-propelled guns come frozen out of `fnc_static_place` too and are seated by hand in `fnc_hardpoint_garrison`, which cannot route through `seatStatic` — that step squares the gun with `setVectorUp [0,0,1]`, right for a gun on legs and a tilt for a tracked hull.

## A hidden terrain object comes back the moment its damage state changes

A terrain object can't be deleted (`deleteVehicle` no-ops), so clearing ground means `hideObjectGlobal` — but the engine replaces a building with a fresh, *unhidden* object when its damage state changes (`BuildingChanged`, carrying no hidden flag), so an explosion near a cleared site re-pops the buildings through whatever was built on top. Fix: hide a building only where one must go, and register it — `misc/fnc_clear_buildings.sqf` owns the one register (`DUWS_terrain_hidden`) plus the `BuildingChanged` handler that re-hides replacements, and every site that must stand on clear ground calls it: a prefab zone centre (`init_zones/fnc_createzone.sqf`, which also deletes what is not terrain), the HQ footprint (`init_hq/fnc_BluHQinit.sqf`) and the FOB footprint (`supports/fnc_fob_server.sqf`, before the building spawns, since a hidden terrain object also drops its collision). `misc/fnc_clear_foliage.sqf` stays filtered to `TREE`/`SMALL TREE`/`BUSH` and needs no register. A hide is permanent, so pay it only where a composition must fit. `BuildingChanged` is local (fires only on the machine that simulated the damage), so a server-only re-hide misses a distant client's blast (escalation, `fnc_escalation.sqf`, works around this with a per-machine watch).

## `+` (copy) deep-copies nested HashMaps, so mutating a `+copy` element updates nothing

Unary `+` (copy) on an array recurses into nested containers, and since Arma 3 v2.02 that includes HashMaps — `+[myHashMap]` clones the map, not references it, so `forEach (+_store)` calling `_x set [...]` on each element writes to a throwaway clone; the stored map is untouched (plain assignment, `select`, `apply` and a direct `forEach` all keep the reference — only `+`/`copy` clones). OPCOM's per-tick mover (`fnc_opcom_task_step`) iterated `+DUWS_opcom_taskings`, so every tasking write vanished and no unit ever moved — silent, no error. Fix: iterate a HashMap store directly (`forEach DUWS_opcom_taskings`) whenever the loop mutates elements; snapshot only against structural change, and with `apply {_x}`, never `+`. The sqf-vm suite predates HashMaps and cannot catch this.

## A unary command binds tighter than `+`, so `sleep 2 + random 5` sleeps a flat 2 s

Every unary command (`sleep`, `count`, `random`, `floor`, `str`) binds tighter than `+`/`-`/`*`/comparisons, taking only the token to its right — `sleep 2 + random 5` parses as `(sleep 2) + (random 5)`: a flat 2 s, randomised part discarded, no RPT line. Fix: parenthesise whenever a unary command is followed by arithmetic — `sleep (2 + random 5)`. Staggered-wake loops hide this: a delay meant to spread a garrison collapses to one they all share.

## Conditional `count` is `{code} count array`; reversed operands throw, not miscount

Binary `count` takes the block on the LEFT — `{alive _x} count _units`; reversed (`_units count {alive _x}`) it's a type error that aborts and unwinds the whole function, not a wrong number (`findIf` is the opposite order — `_array findIf {code}` — and reaching for that shape is the slip). A reversed `count` in `DUWS_fnc_hardpointClearCheck` errored every tick before its clear line (`Error count: Type Array, expected Code`), so a battery never read as destroyed — untestable by the sqf-vm suite since the branch reads live objects. Fix: copy the shape from a known-good line (`{alive _x} count _roster`); read the RPT after play-testing any server clear/stream branch touching live objects.

## `reverse` returns Nothing, so it cannot be inlined — and `deleteWaypoint` shifts indices

`reverse` reverses in place and evaluates to Nothing — `forEach (reverse _xs)` runs nothing, no error names `reverse`. Next to `deleteWaypoint` (`[group, index]`, deleting one renumbers later indices down), a forward pass over `waypoints _group` deletes only every other one. Fix: bind, reverse as its own statement, then iterate — `private _wps = waypoints _group; reverse _wps; { deleteWaypoint _x } forEach _wps;` (or `for "_i" from (count _wps - 1) to 0 step -1`). `fnc_civ_panic.sqf` and `fnc_civ_moveToPlayerServer` (`server/civilian/fnc_civ_state_init.sqf`) do the bind-then-reverse form.

## A waypoint statement never runs if the group cannot reach the waypoint

`setWaypointStatements` fires only on actual completion — a waypoint the group can never reach (off-map, closed to its movement type) never completes, so a `waitUntil` on the flag it sets blocks forever. `fnc_intro_heli.sqf`'s despawn waited on such a flag: its flyaway waypoint sits 15000 m out on a random bearing, often off-map, and AI aircraft turn back at the boundary. Fix: treat a waypoint statement as best-effort notification, never the sole completion signal — gate deletion on something the engine can't withhold — distance travelled plus a hard time cap (`fnc_helotaxi.sqf`).

## `moveInGunner` reports nothing when it fails, and the man is left standing where he spawned

`moveInGunner` returns no value and raises no error — a static whose gunner memory point is in the ground refuses the seat, knowable only by reading it back (`gunner _gun isEqualTo _unit`); the man stands beside his gun, alive, still counted toward the zone's peak, so a defender defends nothing and the log records full strength. `moveInDriver`/`moveInCargo`/`moveInTurret` are the same. Fix: seat, read back, retry — dropping the gun a little higher each pass; `DUWS_fnc_seatStatic`/`DUWS_fnc_manStatics` do this, deleting the man with a `WARN` after the last drop.

## A physics body spawned clipping geometry takes a lethal collision impulse, not a nudge

`createVehicle` with `"CAN_COLLIDE"` (or radius `0`), or a lift-and-drop `setPosWorld`+thaw, places a simulated body into whatever solid already occupies the point — the first simulated frame resolves the overlap with a separating impulse large enough to throw the body clear and cook it off, reading as a spontaneous explosion. Healing after the fact (`setDamage 0` once settled) races the frame and loses — this is why the depot retrieves via a map click through `createVehicle [..., 5, "NONE"]` rather than forcing a pad centre. Fix: spawn with `enableSimulationGlobal false` in the same frame as `createVehicle` (before any suspension), pose it (`setDir`, then `setPosATL` since rotation displaces it), zero `setVelocity`, then thaw a beat later. As a backstop hold `allowDamage false` across the settle, restoring any stored damage first (`allowDamage false` suppresses `setDamage`), then restoring `allowDamage true`. Same freeze-pose-thaw pattern at `init_hq/fnc_placeHQUnits.sqf`, `fnc_civ_traffic`, `DUWS_fnc_manStatics`.

A frozen body never thawed (static furniture) will not take a `setPosASL` — seat it *before* freezing. And under scheduled code, a physics tick can land between `createVehicle` and the freeze even with no explicit suspension — wrap create→seat→freeze in `isNil { … }` so no tick interleaves (`fnc_place_settled.sqf`).

## A static weapon that goes over throws its gunner out and refuses a new one

A gun knocked onto its side ejects the man and refuses a new one while it lies there — the seat test can't distinguish an orientation fault from a clearance one (both refuse), so the retry that recovers a sunk gun never recovers a fallen one. Orientation is carried by `vectorUp` alone, and the fall lands in the *seconds after* placement, so an immediate inspection sees a clean rebuild the player then finds flat. Fix: test the tilt, never the seat — `(vectorUp _gun) select 2` against **vertical** (not the ground normal, which reads backwards on slopes); correct with `setVectorDirAndUp` on a flattened `vectorDir`. Crew only a gun that came to rest genuinely standing and re-drop one that didn't, nudged on x/y (`findEmptyPosition`) to hunt ground it stands on. `DUWS_fnc_dropStatic` stands and drops; `DUWS_fnc_seatStatic` does the square (`setVectorUp [0,0,1]`) and seat (`DUWS_fnc_dropStatic`, `DUWS_fnc_manStatics`, `DUWS_fnc_seatStatic` — none works without the others).

## `inRangeOfArtillery` takes the target on the left and the guns in the array; `doArtilleryFire` is the mirror

The two artillery commands read in opposite directions — `doArtilleryFire` is `gun doArtilleryFire [target, magazine, rounds]`, but `inRangeOfArtillery` is `target inRangeOfArtillery [[guns], magazine]`. Writing the range test to match the fire command beside it (`gun inRangeOfArtillery [[target], magazine]`) throws `Type Object, expected Array` on the left operand, which aborts the enclosing statement — inside a `forEach` that kills the rest of the loop, so a fire mission emitted no rounds and not one of its own log lines. The parse checker cannot see it: both forms parse, only the runtime types differ. Fix: `_pt inRangeOfArtillery [[_gun], _m]` (`warcom/opcom/taskings/fnc_opcom_fires.sqf`).

## `doStop` outlives the orders it was issued against, and new waypoints do not release it

A unit under `doStop` ignores its group's waypoints until given a move order of its own — a fresh waypoint set does not clear the stop, because stop and re-order live in different functions (`fnc_civ_moveToPlayerServer` ends on `doStop`, and every conversation routes through `fnc_civ_resume`→`fnc_civ_wp_Tomata`, which only rebuilds the circuit), so anyone spoken to stood put, reading as a stuck `CYCLE`. Fix: pair every `doStop` with an explicit release where orders are re-issued — `_unit doMove (waypointPosition _first)` costs nothing on never-stopped paths. `setDriveOnPath` is **not** a release: a preceding `doStop` still holds the hull halted (see [§setDriveOnPath commits a driver to the path](#setdriveonpath-commits-a-driver-to-the-path-and-ignores-waypoints-formation-and-combat)) — if `setDriveOnPath` will drive the hull, issue it alone.

## A lone MOVE waypoint is not a wait: the group completes it on arrival and drifts, so each leg of a staged journey needs its own waypoint

A single MOVE waypoint is reached, marked complete, and — with nothing queued behind it — the group reverts to idle/formation and drifts off the spot, so a journey that stages through a wait cannot be one MOVE to the far end: every leg needs its own waypoint, and the waiting leg must be a type that holds, not one that completes. Fix: give the wait point a `"HOLD"` waypoint after the MOVE leg (`(_grp addWaypoint [_pos, 0]) setWaypointType "HOLD"`) — HOLD never auto-completes, so release it explicitly when the next leg begins (it won't clear itself). `DUWS_fnc_opcom_reOrderLive` stages a live rider at its near shore this way, a boat pickup re-stages it at the shore it boards from, and a rotor pickup drops the HOLD before `orderGetIn` (`server/warcom/opcom/taskings/fnc_opcom_stream.sqf`, `fnc_opcom_ferry_devirt.sqf`).

## `waypoints` keeps finished waypoints, so an empty list never means the group is idle

`waypoints _grp` lists every waypoint the group holds, finished ones included — completing one only advances `currentWaypoint`, so `count waypoints _grp == 0` is true right after a clear and never after an arrival. OPCOM's live ferry gated each leg's move on that test, so no leg after the pickup got its order: the rotor hovered and the boat idled at the pickup for good, the carry leg being untimed. Fix: issue a leg's order once, as the leg starts; to test "done", compare `currentWaypoint _grp >= count waypoints _grp` (`DUWS_fnc_opcom_ferryStepLive`, `fnc_opcom_ferry_devirt.sqf`).

## Deleting waypoints does not move `currentWaypoint`

`deleteWaypoint` removes waypoints but leaves the group's current-waypoint index where it was. A group that already worked through earlier orders can therefore point past the new waypoints and ignore them. A jet sent home from its loiter kept orbiting because its index still pointed at the deleted loiter slot (`client/supports/fnc_arty.sqf`). Fix: after a re-order, point the group at its first new leg with `_grp setCurrentWaypoint _wp`, as the task-force orders do (`server/warcom/fnc_taskforce_tick.sqf`).

## A group in COMBAT behaviour ignores a commanded move order

An AI group whose behaviour has gone `COMBAT` owns its movement through the danger FSM — a MOVE waypoint or `doMove` is deprioritised or ignored; `setBehaviour "AWARE"` is overridden the instant it takes fire, `setCombatMode "BLUE"` + `disableAI "AUTOTARGET"` stops firing but not cover-seeking, and only `setBehaviour "CARELESS"` moves it reliably — which walks it into fire in the open. A commanded fighting withdrawal is not achievable. Fix: never design a retreat or mid-fight reposition that commands an engaged live group to a safe spot; let it fight to a decision and reclaim it for movement only once out of combat.

## `lock true` stops a player boarding, not an AI disembarking

`vehicle lock true` blocks the player getting in/out and AI getting *in*, but does not keep an aboard AI *inside* — it still bails when the group goes COMBAT or the vehicle halts/stalls/is disabled. Fix: layer three things to hold an AI in a vehicle — `lock true`, `setUnloadInCombat [false, false]` (suppresses the combat bail), and a `GetOutMan` handler reseating him (`if (alive _unit && alive _veh) then { _unit moveInCargo _veh }`, which re-enters past the lock and lets a destroyed car eject normally).

## `land "GET IN"`/`"GET OUT"` is a sticky mode with no completion event

`aircraft land "GET IN"` (or `"GET OUT"`) makes an AI helicopter descend and *stay* grounded until explicitly cancelled, with no "landed" callback, so a fresh move waypoint may be deprioritised while the order stands. Door animation is model-specific — the `door_L`/`door_R` sources `fnc_helotaxi` animates exist only on some airframes, so `animateDoor` silently no-ops on others. Fix: drive a landing across ticks, not a blocking `waitUntil` — issue `land` once within range, poll `getPosATL _heli select 2` under ~4 m for grounded, act, then `_heli land "NONE"` **before** the next waypoint (or it can sit on the pad) and re-task; OPCOM's live ferry (its rotor phase table, `fnc_opcom_ferry_rotor.sqf`) does this at both ends, setting down with `"GET IN"` at the pickup and `"GET OUT"` at the drop so the engine keeps turning, and gates a stall timer to each landing phase. "Sticky" is about the mode, not the hold: the mode stands until cancelled, while the hold under it ends as soon as the assignment it waits on is satisfied — see the `land "LAND"` entry below.

## A landed helicopter climbs back to its `flyInHeight` the moment its landing hold ends

`land "LAND"` holds a hull down only while the engine still believes it has cargo to unload, and the hold is short whatever the mode. The modes differ in engine state — `"LAND"` shuts the engine down and restarts slowly, `"GET IN"` and `"GET OUT"` keep it turning — but none of them holds a hull for a whole paced dismount. What happens next is not a departure: with its waypoint reached and its hold spent, the pilot climbs vertically to its own `flyInHeight` and hovers over the pad, forward speed reading 0 all the way up. Three shapes and what each proved at OPCOM's ferry drop, all measured five seconds after touchdown: `land "LAND"` with the men walking out one at a time, each `unassignVehicle`'d so he could not re-board — 30 m up with six of nine still queued, four killed by ejection at 50-88 m; `land "GET OUT"` plus `disableAI "MOVE"` on the pilot — 23 m up and then a crash, because that is not a pin at all, it removes the control that holds a hull on the ground; `land "GET OUT"` with every man `assignAsCargo`'d as he was seated — 43 m up and still climbing to a 150 m `flyInHeight`, so the hold does not watch the assignment either. Fix: take away the altitude the pilot wants, `flyInHeight 0` at skids-down and restored on release, and then do not trust it — gate every man's exit on the hull still being under the grounded threshold and put whoever is left on the ground yourself the moment it lifts, so a failed pin costs a tidy dismount and not the squad (the rotor phase table, `fnc_opcom_ferry_rotor.sqf`; the pin is undone in `DUWS_fnc_opcom_ferryRelease`, `fnc_opcom_ferry.sqf`). `fnc_helotaxi` reads like a working reference and is not: it turns four passengers out a second apart and is finished about four seconds after grounding, so it never tests a hold long enough to fail.

## `orderGetIn` only moves units already assigned to a seat

`units orderGetIn true` sends each unit to the vehicle it is *assigned* to (`assignAsDriver`/`assignAsGunner`/`assignAsCargo`) — a unit with no assignment has nowhere to go, so ordering before assigning is a silent no-op (and with *nothing* assigned, the wait completes at once, touching the hull down and lifting it immediately). The left operand is an `Array of Object`, not a group. Fix: assign as cargo first, then order the array in (`{ _x assignAsCargo _veh } forEach _units; _units orderGetIn true`), the shape `fnc_rescue_squad_success` uses. The two halves split cleanly, since the hold watches the assignment while only `orderGetIn` moves anyone: OPCOM's ferry assigns with the `land` call and orders at the skids, because a landing gate measured in grid cells can be hundreds of metres wide and men ordered in on the approach spend the board's deadline walking out to a hull still in the air; a unit in `COMBAT` behaviour still refuses or defers, so give the board a deadline and settle stragglers once at it — the rescue squad teleports them in with `moveInCargo` (ignores combat/range/seats), OPCOM's ferry despawns them (`fnc_opcom_ferry_devirt.sqf`). Seat assignments are also made once, against the seats free at that moment: order a squad into a cabin with fewer seats than men and the men left over are assigned nothing, and they are not re-paired when seats free later (as they do where each boarder despawns out of his seat on entry), so the last man in — the leader, who boards behind his men — idles beside the hull until the deadline. Fix: re-issue `assignAsCargo` + `orderGetIn` each tick to whoever is still outside the hull, not once with the landing order.

## `cmd [...] remoteExec ["call", 0]` broadcasts the return value, not the command

A unary command binds tighter than binary `remoteExec`, so `titleText [...] remoteExec ["call", 0]` runs `titleText` locally and broadcasts what it evaluated to (Nothing) — every other machine gets an empty payload; the fix is braces, `{titleText [...]} remoteExec ["call", 0]`. Without them the statement still reads as a broadcast and runs locally, so it survives host/SP testing and only a dedicated server exposes it. Fix: name the command instead of wrapping code, but a unary command whose one argument is itself an array needs a second bracket pair — `[["In memory of...", "PLAIN", 3]] remoteExec ["titleText", 0]` (`src/duws/server/misc/fnc_intro_heli.sqf`).

## `titleText`'s speed argument fades the new card in; it never fades the old one out

`titleText [_text, _type, _speed]` times the card being *posted* — clearing with an empty string replaces the visible card instantly then spends `_speed` seconds fading in nothing, so the text just snaps off. `titleFadeOut _duration` is the only command that fades what's on screen; it takes a plain number, so `remoteExec` needs one bracket pair — `[2] remoteExec ["titleFadeOut", 0]`. Fix: clear a title card with `titleFadeOut`; keep the empty-string form only for swapping one card for another with no gap.

## `BIS_fnc_typeText`'s second and third arguments are screen coordinates, not timings

`BIS_fnc_typeText`'s signature is `[lines, x, y, format]` — a hold or typing speed passed in those slots is read as a position, so the card types itself off-screen (`[..., 1, 2]` puts it two full screens below the bottom). The timing lever is per line: each entry is `[text, format, delay]`. Callers: `client/misc/fnc_bottom_right_message.sqf:221` passes `-safezoneX`, `0.85` to pin bottom-right; `server/warcom/fnc_init_OPFOR_WARCOM.sqf:75` passes the line array alone and lands centred. Fix: pass the line array alone unless moving the card, and put a hold in the line's own third element — a one-line card with no delay drops the instant the last character lands, reading as a flicker.

## `localize` resolves on the machine that runs it, so a broadcast string carries the sender's language

`localize` reads the executing machine's stringtable — resolving a key server-side and broadcasting the result sends the *server's* language to everyone; broadcasting a code block that localizes on arrival lets each client resolve its own:

```sqf
[localize "STR_X"] remoteExec ["hint", 0];                  // everyone reads the server's language
[{hint localize "STR_X"}] remoteExec ["BIS_fnc_Spawn", 0];  // each client resolves its own
```

Fix: this mission resolves server-side nearly everywhere (`fnc_duws_dialogue` call sites hand already-`localize`d text), so the `BIS_fnc_Spawn` hint sites are the exception — don't fold them into the first form, or the DE/ES/ZH tags stop reaching anyone on a dedicated server.

## `configFile` is the running machine's mod set, so a client can list classes the server cannot spawn

Each machine builds `configFile` from the mods it loaded, and Arma does not make a client's set match the server's. A faction enumeration, a `configClasses` list or an `isClass` check run on a client therefore answers for that client's mods, not for the server's, which is the machine that spawns. The setup screens once did all three on the game master's client: they offered factions and classes that the server could not build, and they rejected a pasted class that the server had. Clients also re-ran the faction files against their own config and rebroadcast the results over the server's. Fix: run on the server any list or check that decides what the server will build. Broadcast an answer that is fixed at init, and get a per-click answer with a server round trip (`fnc_faction_ask` calling `fnc_faction_query`, `src/duws/shared/faction_lib/fnc_faction_query.sqf`). A client-side config read is correct only for presentation that needs the mod's files locally anyway, such as an `editorPreview` picture.

## `player1` is an editor unit, so `remoteExec`ing to it addresses slot 1 and nobody else

A `remoteExec` object target runs only where that object is local, and `player1` is a `mission.sqm` unit, not a synonym for "the player" — it resolves to whoever holds slot 1 (the Game Master seat); SP hides this, a second co-op player exposes it. Fix: `player1` is right only for the Game Master seat. Anything the team reads takes `[0,-2] select isDedicated`, evaluated where the call is made — `isDedicated` is false on every client, so the idiom only excludes an interfaceless server when the call site is server-side.

## A comm-menu item id goes stale the moment the item is used

`BIS_fnc_addCommMenuItem` returns an id `BIS_fnc_removeCommMenuItem` needs back, but a `CfgCommunicationMenu` class with `removeAfterExpressionCall = 1` is deleted the instant the player calls it — the re-adding script gets a *new* id, so any id stored at purchase points at nothing (thirteen of twenty comm classes are declared this way). Fix: never call the two BIS functions directly. `fnc_support_comm_add`/`fnc_support_comm_drop` (`client/supports/fnc_supports_init.sqf`) own a per-player class→id record, every re-add routes through the add, and each `expression` opens with `['<class>'] call fnc_support_comm_used` so the deletion is observable. Removal tears the slate down in **descending id order** and rebuilds from the record.

## A `CfgNotifications` description is clipped, not wrapped, past roughly 60 characters

The notification card's description box is fixed-size — longer text is cut off mid-sentence with no ellipsis and no error; the ceiling is a pixel width (moves with the proportional font), so **60 characters is the figure this mission writes to**. Fix: keep every `BIS_fnc_showNotification` body at or under 60 characters, counting a `format` placeholder at its longest substitution. Anything needing more room is not a notification — a briefing belongs in the task description, an explanation in a `hint`, never both ([`player_text_style_guide.md`](../gameplay/player_text_style_guide.md#notification-card-dialogue-and-the-hint-box)).

## SQF identifiers are case-insensitive, so `_Varname` and `_VarName` are one variable

Variable and function names ignore case — `_Varname = "MHQ1"` then a read of `_VarName` is one variable. Harmless at runtime (`fnc_MHQ_select.sqf:38-40` mixes them and works), but a case-sensitive text search reports the write dead and the reads undefined; command names too (`IF`, `ForEach`, `SetPos`). Fix: fold case on both sides whenever a tool compares SQF identifiers, or a dead-code/rename pass produces confident false positives.

## `getUnitLoadout` pads weapon arrays, so length is not presence

A weapon slot in `getUnitLoadout` is always seven elements when carried — `[classname, suppressor, pointer, optics, [mag, count], [mag2, count2], bipod]` — absent attachments `""`, absent magazines `[]` — so `count _weapon > 3` tests for a *weapon*, never an optic, and `_weapon # 4 # 0` indexes an empty array on a launcher with no magazine. Reading an absent attachment compounds it: `configFile >> "CfgWeapons" >> "" >> ...` resolves to no classes, `configClasses` returns `[]`, and **`selectMax []` returns nil** — assigning nil *undefines* the variable, surfacing lines later as "Undefined variable". A continuous-zoom scope reaches the same `selectMax []` a second way (has `OpticsModes`, no `discreteDistance`). Fix: test the slot, not the length; guard the flattened array, not just the modes list.

## `weapons` lists the `Throw` and `Put` pseudo-weapons, and their muzzles carry magazines

`weapons _unit` returns `Throw` and `Put` next to the real guns, and both are `CfgWeapons` classes, so an `isClass` filter keeps them. Each of their muzzles (one per throwable or explosive) carries its own `magazines[]`, which is the same shape as an underbarrel grenade launcher. `fnc_IsGrenadier` therefore matched `Throw`, and a bandit grenadier drew it instead of a rifle: the grenadier had no gun and carried spares of the first throwable in `Throw`'s muzzle order. Fix: drop both classes when a weapon pool is built from `weapons` (`_excludedItems`, `src/duws/server/arsenal/fnc_create_ammo_lists.sqf`).

## The virtual arsenal lists a weapon under its base row, not the class on the shelf

`BIS_fnc_arsenal` passes every weapon on the virtual shelf, and every weapon the player holds, through `BIS_fnc_baseWeapon`. The list row, and the class a pick hands out, is that base, never the shelved or held class: the preset `arifle_MX_ACO_pointer_F` lists and is issued as a bare `arifle_MX_F`. A per-class store keyed by the carried class therefore never matches the row. A looted mod preset in the captured pool showed `[0]` on its base row, and a pick of that row settled as overdraw and was stripped. Fix: key every per-class store by the row class (`fnc_arsenal_weapon_row`, which is `BIS_fnc_baseWeapon` in declared case), and match held weapons through the same mapping when removing one (`DUWS_fnc_strip_n`, `initPlayerLocal.sqf`).

## The diary ignores `<t>`; structured-text colour there comes from `<font>`

`createDiaryRecord` bodies are structured text, but only a subset of `parseText` tags render in the map's Notes — `<t>` is **not** one, silently dropped with its `color`/`size`. Diary records colour via `<font color='#RRGGBB'>` instead (`<br/>`/`<img>` render in both); `<font size='N'>` is absolute pixels where `<t size='N'>` is a multiplier, so copying `size='1.15'`/`'2'` across renders ~1-2px text. Fix: colour diary bodies with `<font color='#RRGGBB'>`; drop or repixel any `size` copied from a `<t>` string.

## Seat and crew queries (`fullCrew`, `crew`) need a spawned object, not a classname

`fullCrew` takes a vehicle Object — handed a classname String it throws `Type String, expected Object`, and inside a `call`ed classifier the throw returns nil, so a gate built on that verdict *fails open* (the tier test errors instead of refusing, and the purchase proceeds). Fix: count seats from config instead — `getNumber (_cfg >> "hasDriver") + getNumber (_cfg >> "transportSoldier") + count ("true" configClasses (_cfg >> "Turrets"))`. `isKindOf`/`getNumber`/`configClasses` take a classname; the seat/crew *object* commands do not (`DUWS_fnc_vehTier`, `src/duws/shared/functions/fnc_ap_gate.sqf`).

## `setPos*` seats the model origin, not the model's base, so a swapped class of different height sinks

`setPosWorld`/`setPosATL`/`createVehicle` placement put the object's model **origin** `[0,0,0]` at the named height, not its lowest point — two guns with origins at different heights above their bases end up at different base heights from the same command. A composition authors weapon Z against an Eden placeholder; when auto-detect swaps in a taller-origin faction gun (e.g. a ZU-23), the reused Z drives its base underground, and the drop-and-settle only rescues guns it later crews and lifts. Fix: base offset is `(boundingBoxReal _obj select 0) select 2`; shift a swapped class's base by `baseZ(placeholder) - baseZ(resolved)`. `fnc_static_baseZ` probes and caches per class, `fnc_static_place` applies the shift only when the class changed (both `src/duws/shared/functions/fnc_static_roles.sqf`), so an unmodded faction is untouched.

## `buildingPos` slots sit above the floor, so a prop seated at that Z by hand floats

`BIS_fnc_buildingPositions`/`buildingPos` return authored unit-placement points, not the floor collision surface — their Z sits a variable gap above the walkable floor (per building and slot, not subtractable like a class base offset), so an object placed straight onto that Z hangs even base-corrected. Fix: drop the *carrier* simulated and let PhysX fall it the small gap onto the floor, then `enableSimulationGlobal false` (batch: place all carriers, one `sleep`, freeze the lot). Do **not** drop a prop that rides on the carrier — a PhysX body at the carrier's origin clips and takes an ejection impulse (see [§A physics body spawned clipping geometry](#a-physics-body-spawned-clipping-geometry-takes-a-lethal-collision-impulse-not-a-nudge)) — seat the carried prop at rest once the carrier is frozen (create above the top, zero velocity, freeze) via `fnc_place_settled` (`src/duws/server/placement/fnc_place_settled.sqf`). Callers: `sabotage_laptop/fnc_sabotage_laptop_mission.sqf`, `destroy_patrol_camp/fnc_destroy_patrol_camp_mission.sqf`.

## A shell spawned at rest is inert: it needs impact velocity to fuze

`createVehicle` on an ammo/shell class (`Sh_82mm_AMOS` and kin) makes the projectile but does not fire it — an impact fuze has nothing to arm at rest, so it sits live but inert, and `setPosATL`/`setPos` after creation re-zeroes the velocity, worsening it. Fix: spawn just above the target (`+0.5` m) and drive it down with `setVelocity [0,0,-30]` so it strikes at once; never `setPosATL` afterward. Create it on the **server** so the blast is authoritative and replicates, unlike a client-side `setDamage`. Callers: `fnc_sabotage_laptop_decoy.sqf`, `fnc_random_event_car_bomb.sqf`.

## Z-placement frame: `setPos` counts roofs, `setPosATL`/`getPos [dist,dir]` measure from terrain, `setPosWorld` is absolute

Three placement frames differ in what Z is measured from:

- `setPos [x,y,z]` — z above the *highest surface* at the point, and a building roof is a surface; a gun placed with `setPos` overlapping a footprint lands z metres above the roof.
- `setPosATL` (and `object getPos [dist, dir]`) — z above *terrain*, ignoring floors/roofs/objects; re-seating a unit on an upper floor snaps it to ground-floor height.
- `setPosWorld` (with `getTerrainHeightASL`) / `getPosASL` — absolute ASL.

Fix: for anything meant to sit on the ground, use `setPosATL [x,y,0]` or a terrain-height `setPosWorld`, never bare `setPos` (`fnc_static_place`'s `"world"` mode). To place a unit at a floor-relative point, work in the world/ASL frame (`modelToWorldWorld`+`setPosWorld`, or `getPosASL`); better, when a body is already at the wanted world spot, `detach` and let it settle rather than any setPos (`DUWS_fnc_unitDrop`, `src/duws/server/misc/fnc_unit_carry.sqf`) — a carry/drop helper once set an informant down with `setPosATL (_carrier getPos [1.2, dir])` and teleported him to the ground floor beneath the carrier.

Spawn commands read the frame the same way — `BIS_fnc_spawnVehicle` (and array-form `createVehicle`) take a 3D position's z as height above *terrain*, so a `getPosASL` point floats the hull by ≈ the terrain elevation; a 2D `[x,y]` grounds it. `BIS_fnc_spawnGroup` grounds infantry regardless, which is why only vehicles float. OPCOM banks a stowed tasking's point as `getPosASL`, so its ground-vehicle de-virt strips z before spawning.

## An empty group is never freed, and each side caps at 144 groups

`createGroup` claims a slot that lives until explicitly freed — nothing reaps an empty group unless made with `createGroup [side, true]` or handed to `deleteGroup`. Each side caps at 144; past that, `createGroup`/`BIS_fnc_spawnGroup` return `grpNull` silently and no new AI spawns. The napalm strike leaked an empty WEST group per fire object (`[_bomb] joinSilent createGroup WEST` groups a projectile, never a unit, so the group stays empty), 32 per call — a handful exhausted the side, campaign-wide (`client/supports/fnc_arty.sqf`). Fix: create transient groups with `createGroup [side, true]`, or `deleteGroup _g` once the last member is gone. When AI stops spawning mid-campaign with a clean RPT, read `count allGroups`.

## A script marker is never garbage-collected, so every exit path must delete its own

`createMarker` makes a marker that lives until `deleteMarker` names it — never reaped on unit death, GC, or mission end. A fire-mission's jet-shootdown early-out (`if (!_veh_alive) exitWith {...}`) skipped the tail cleanup, so every strike lost before its drop left two grey ellipses on the map for good. Fix: pair every `createMarker` with a `deleteMarker` that *each* exit path reaches — clean inside every `exitWith` after creation, or funnel all paths through one cleanup. Wrecks and corpses differ (the engine's GC reaps those).

## AI cargo bails a vehicle on contact by default; `setUnloadInCombat [false, false]` holds them

AI riding as cargo disembarks on its own the moment the vehicle enters combat (fire, spotting, damage) — engine behaviour invisible in the SQF, so a trucked squad empties into the open hundreds of metres short. `vehicle setUnloadInCombat [allowCargo, allowTurret]` is the switch; default `[true, true]` is auto-bail, `[false, false]` suppresses it. Fix: set it once after the men are aboard — it disables only the *automatic* dismount, so script must then provide `moveOut` calls (an ordered get-out refuses on a dead/dying/moving vehicle). A truck reinforcement dismounts from a monitor firing on arrival, truck death, or a ride-time ceiling (`server/init_zones/fnc_garrison_reserve.sqf`). **`lock true` is the harder hold, for when the occupant must never leave** — blocks entry/exit for the whole lifecycle and doesn't impede AI driving (`target_hvt/fnc_target_hvt_mission.sqf`), but never lock where the men must be able to flee a dying vehicle.

## `setDriveOnPath` commits a driver to the path and ignores waypoints, formation and combat

A hull under `setDriveOnPath [positions]` drives that exact polyline and nothing else — overrides waypoints and formation, and the driver won't manoeuvre or break to fight (turrets still engage); right for a convoy that must arrive, wrong where hulls must fight. Hand a hull back to native AI with an empty path (`_veh setDriveOnPath []`) and drop any `forceSpeed` cap (`DUWS_convoy_release`). Two consequences: a hull moved to a new group keeps its old path order until cleared, and the lead must be the **frontmost** hull (followers trace its breadcrumb trail; a rear leader reverses the column into a jam, so `fnc_convoy_drive` keeps leadership frontmost with `selectLeader` and hysteresis). Fix: `selectLeader` is safe only because one loop owns each group — two loops sharing a group flip leadership every tick.

## `group` of a vehicle object does not reliably name the crew's group

`group _vehicle` is defined for men, not a vehicle hull — on a crewed vehicle it doesn't dependably return the crew's group. Fix: work from the men — `fnc_convoy_drive` walks `units _group` and takes each man's vehicle where he is its driver, never asking a hull which group it's in.

## A runtime error inside a `call`ed function halts the whole calling script, not just the callee

An unhandled runtime error in a `call`ed helper unwinds the entire call chain and stops the scheduled script at the call site — every statement after never runs, and the RPT names only the innermost file/line, so nothing hints the caller died too. `setUnloadInCombat` bit this way: it takes an **Object** (the vehicle), not a Group (the wiki's `groupName` wording misleads) — passing a group throws `Type Group, expected Object`, killing the whole convoy-setup thread before its monitor existed. Fix: apply `setUnloadInCombat` per-vehicle in a `forEach _vehicles`, never to the group; treat any `call` before a load-bearing loop as able to take the whole script with it.

## `removeItem` cannot remove a worn uniform, vest, backpack, headgear or goggles

`removeItem "class"` only reaches loose items (magazines, attachments, container contents) — the worn container/head/eyewear slots have their own no-argument commands, so `removeItem` on a worn uniform is a silent no-op. Fix: dispatch the five worn slots — `removeUniform`, `removeVest`, `removeBackpack`, `removeHeadgear`, `removeGoggles` (each takes no class; guard on `uniform player == _cls`). The container commands discard contents — re-add afterward (`DUWS_fnc_strip_n`, `initPlayerLocal.sqf`).

## `addMagazine` needs a container; arm a containerless civilian with `addWeaponItem`

`addMagazine` places the magazine into a worn container; several vanilla civilian costumes carry none, so the call fails silently and `addWeapon` finds nothing to auto-load — the unit holds a gun it can't fire. Fix: load the magazine straight into the weapon, bypassing inventory:

```sqf
_unit addWeapon "hgun_Rook40_F";
_unit addWeaponItem ["hgun_Rook40_F", "16Rnd_9x21_Mag", true];
```

`addWeaponItem` works on any body class; the `addMagazine`-then-`addWeapon` order is safe only on units known to wear a container.

## `time` and `daytime` are different clocks; a world-clock timer cannot be built on `time`

`time` is real elapsed mission seconds (scaled by `setAccTime`, untouched by day/night); `daytime` is the world clock in hours, sped up by `setTimeMultiplier` (`time_Multiplier`, 1–60×) — above 1× they diverge. Deadlines are meant in-game but targets are stored on `time` so the many `time > deadline` checks work: the `fnc_time_*` module bridges them (`fnc_time_deadline` divides an in-game duration by the multiplier to a `time` target; `fnc_time_remaining`/`fnc_time_clock` scale back up), safe only because `time_Multiplier` is set once at setup. A mid-mission multiplier change would need `daytime`-based targets instead (accumulate deltas, adding 24 on a negative delta for midnight):

```sqf
private _elapsed = 0; private _last = daytime;
while { _elapsed < _targetSecs } do {
    sleep 2;
    private _d = daytime - _last;
    if (_d < 0) then { _d = _d + 24 };
    _elapsed = _elapsed + _d * 3600; _last = daytime;
};
```

Fix: when formatting hours into a clock string, round to whole minutes before splitting h:mm — `floor` on the raw float lands a minute short near an integer boundary (10.20 h × 60 = 611.99 → 10:11, not 10:12; `fnc_time_clock` handles this).

## A road segment's `getDir` is not the direction of the road

`getDir` on a `"ROAD"`/`"TRACK"` object returns the model's own heading (usually `0`), not the way the carriageway runs, so `setDir (getDir _road)` parks a vehicle broadside. Fix: use the bearing to an adjacent segment instead —

```sqf
private _cons = roadsConnectedTo _road;
private _dir = if (_cons isEqualTo []) then { getDir _road } else { _road getDir (_cons select 0) };
```

Placing on a road is also where cars detonate on spawn — `createVehicle [..., "NONE"]` drops exactly where told, so a point holding a wall, rock or parked car spawns it clipping and blows it up. A vehicle check sized to one car is too tight: with a 4 m radius, a second car spawned nose into the first, and the first car, which was vulnerable again, detonated. Reject the point up front with `nearestTerrainObjects [_p, ["WALL","FENCE","ROCK","TREE"], 4]`, with `nearestObjects [_p, ["LandVehicle","Air","Ship"], 20]`, and with rays through the class's bounding-box footprint (`fnc_class_half_extents`) for any other solid object (`fnc_civ_traffic`).

## A `remoteExec`'d `BIS_fnc_taskCreate` floods `objectFromNetId` every frame the map is open

`BIS_fnc_taskCreate` `remoteExec`'d to every client serialises the task's owner/destination as live references, which BIS's map draw re-resolves by netId every frame the map is open — crossed references throw `[BIS_fnc_objectFromNetId]/[BIS_fnc_groupFromNetId] Error: type OBJECT/TASK, expected STRING` for the task's whole life, jamming the strategic map's task figure, tooltip and clicks (including the side-mission picker). The last argument is `visibleIn3D` (index 8), not a share toggle; passing `[]` + `setSimpleTaskDestination` doesn't help. Fix: don't broadcast — call `BIS_fnc_taskCreate` server-side and let the task framework synchronise it to the owner side's clients (`fnc_missionTaskCreate`/`fnc_missionTaskEnd` do this with a position destination). Two related problems: `fnc_night_horde_event.sqf:56` passes `objNull` as destination (still a resolved reference — fix is `[]`; only bites in RAVAGE mode); and a curator/Zeus session as `game_master` throws a *look-alike* flood that isn't the mission's fault — unassigning `game_master` stops it.

## `uiNamespace` outlives a mission restart, but spawned loops do not

Variables in `uiNamespace` survive from one mission to the next in the same process, but `spawn`ed scripts are terminated when the mission ends — so a `uiNamespace` bool guarding "this loop is already running" strands set with no loop alive, and every mission after a restart skips the respawn (this silenced the whole subtitle system from the second mission of a session on). Fix: guard on the loop's script handle, not a bool — `scriptDone` reads true once the loop is gone and false while it runs; `client_init.sqf` respawns on `isNull || scriptDone`. The dialogue queues also live in `uiNamespace` (so they don't serialize into saves), so a respawned drain must clear the queues it owns before flushing the backlog. A per-mission guard belongs in `missionNamespace` instead.

## `BIS_fnc_strategicMapOpen` offsets an icon's click hotspot when the offer position carries a Z

An offer handed to `BIS_fnc_strategicMapOpen` with a 3D `[x,y,z]` position draws its icon at the flat `[x,y]` projection but places the clickable hotspot using the full 3D point — a Z away from the surface slides the hotspot off the icon, so the offer looks present but won't select, with nothing in the RPT. A finder snapping onto a `getPos`-derived centre (a coastal town Location can return Z of −11 to −32 m) hits this by geography. Fix: keep every strategic-map offer position 2D — `fnc_mission_findSite` flattens each finder's returned position to `[x,y]` before it becomes an offer, so a snapping finder (`fnc_informant_site`, `fnc_recon_observe_site`) can't leak a Z; the threads later measure the offer only with `distance2D`.

## `BIS_fnc_findSafePos` returns its default position on failure, not `[]`

When `BIS_fnc_findSafePos` exhausts its attempts, it returns its default position (the 9th argument), not a failure signal. With `[[0,0],[0,0]]` as the default, a miss returns `[0,0]`: open sea off Altis' SW corner, which clears any gate that rejects only `[]`. A side mission sampling `surveyKind "map"` got `[0,0]`, cleared every downstream gate, and started in the water. With no default, a miss returns a far point on land, not the origin: a zone flag search placed the flag off its zone past a `[0,0,0]` guard (`fnc_createzone.sqf`). Fix: call `fnc_safe_pos`, which passes the `[0,0]` default and rejects the origin and water. A direct call must pass `[[0,0],[0,0]]` as the default and reject `[0,0]`; a check against `[]` or `[0,0,0]` catches no miss.

## `doSuppressiveFire` needs line of sight and picks the heaviest weapon, so it levels a building

`unit doSuppressiveFire target` does nothing without line of sight, and when it fires it chooses the AI's best-rated weapon — a rifleman carrying a launcher fires the launcher, so suppressing a building the squad must keep intact either produces no fire or destroys the objective. Fix: force small-arms suppression with `unit forceWeaponFire [primaryWeapon unit, mode]` — fires the named weapon regardless of LOS/target; point the unit first with `doWatch pos` and resolve `mode` from `getArray (configFile >> "CfgWeapons" >> _w >> "modes") select 0` (a `["this"]` list means the mode name is the weapon name). `fnc_rescue_squad_mission.sqf`.

## `forceSpeed` is a ceiling on a native-driven hull but a setpoint on a `setDriveOnPath` one

On a natively-driven hull (`doMove`, waypoints) the path planner owns the throttle, so `forceSpeed` is only a ceiling (caps top speed, can't make a stalled driver go, fights native steering if used for spacing); on a `setDriveOnPath` hull it's a true setpoint that closes and holds a gap. `limitSpeed` is the soft cap for the native case (km/h; `forceSpeed` is m/s) — `limitSpeed -1` does **not** remove the limit (it flies a helicopter in reverse). `forceSpeed 0` drops a `setDriveOnPath` hull off the path onto native idle, so a later positive value behaves as a ceiling and the hull sits commanded-but-stationary until its path is re-committed. Fix: for a tight convoy, put every hull on a committed path with `setDriveOnPath` and hold the gap with `forceSpeed`; space with `limitSpeed` where native pathing must stay. Reset any cap with a large sentinel, never `-1` (`fnc_convoy_drive.sqf`'s `CV_NOLIMIT` = `1e10`); re-issue `setDriveOnPath` to a wedged hull (`speed ~ 0` for a few ticks) rather than trusting `forceSpeed` to restart it.

## `waypointPosition [group, 0]` reads `[0,0,0]`: index 0 is an implicit placeholder

Every group carries an implicit waypoint at index 0, whose `waypointPosition` reads `[0,0,0]` — user waypoints land at index 1 up. A driver that indexes waypoints itself (because it no longer native-drives the leader, so `currentWaypoint` never advances) starting at 0 reads `[0,0,0]` forever, idling on the map origin. Fix: when self-managing a waypoint index, step past any waypoint whose `waypointPosition` is `[0,0,0]` before using it — not just index 0, a wrapped CYCLE or completed final leg can also land empty (`fnc_convoy_drive.sqf` advances `_legIdx` with `while { ... waypointPosition [_group, _legIdx] isEqualTo [0,0,0] } do { _legIdx = _legIdx + 1 }` and idles only when the index runs past the whole list).

## `getVariable` with a default returns `nil` on a null object, not the default

`_obj getVariable ["name", _default]` returns `_default` only when `_obj` is a *live* object missing that variable — on a **null** object it returns `nil` regardless, so a `select`/`findIf` over a list that can contain a null (`allUnits + vehicles`) and then compares (`_x getVariable ["k", -1] == _token`) evaluates `nil == _token`, which throws and aborts the whole `select` — so a filter that looks total silently returns nothing. Fix: guard the element first, short-circuited — `(allUnits + vehicles) select {!isNull _x && {_x getVariable ["k", -1] == _token}}`.

## `setHitPointDamage` never moves `getDammage`, and field repair only touches hit points

A vehicle carries two decoupled stores: the hull value (`damage`/`getDammage`) and per-part hit points (`getHitPointDamage`) — `setHitPointDamage` writes one part and leaves the hull untouched, so a repair loop using only it moves no health bar. Stock engine field repair restores **hit points only, capped** (~40% integrity / ~0.6 hit-point damage) and never clears the hull, so testing `damage _veh` for "player repaired it" can never win by field repair. Fix: detect field repair by testing hit points, not the hull — mean part damage (`fnc_veh_comp_damage`, `server/misc/`) against a threshold just above the ~0.6 cap; the structural `HitHull`/`HitBody` points do *not* field-repair, so watch odd/modded hit-point layouts. Full script repair is `setDamage 0`; to immobilise a derelict, kill the engine hit point *after* `setDamage` (`fnc_veh_disable_engine`).

## A civilian-class unit made hostile by `createUnit` into an enemy group still reads Civilian in Zeus

A CIVILIAN-faction man created with `group createUnit [...]` straight into an EAST/WEST group doesn't reliably take that side — the curator/Zeus layer still lists and colours it Civilian, and it won't open fire even set to COMBAT. Fix: create it, then `[_unit] joinSilent (createGroup [EAST, true])` — re-grouping registers the live side for the curator icon and engagement while keeping the civilian costume (VBIED driver, informant manhunt, `informant/fnc_informant_mission.sqf`).

## The `"Horn"` action is a player keybind; an AI honks by firing the horn as a vehicle weapon

`vehicle action ["Horn", vehicle]` sounds the horn only for a player — "Horn" is an action-menu entry an AI has no entry in, so it's a silent no-op on an AI driver. The horn is really a vehicle weapon (`CarHorn`/`SportCarHorn`/`TruckHorn`, in `weapons[]`). Fix: read the hull's horn out of `weapons _veh` and fire it with `_veh forceWeaponFire [_horn, _horn]` — a global effect on a local argument, so run it where the hull is local (a server-spawned event vehicle → the server, everyone hears it, no `remoteExec`). `BIS_fnc_fire` also works and adds the weapon first, but a civilian car already carries its horn.

## An AI driver will not run over a man on foot; it brakes and steers around, stopping short

A `doMove` at a player's position doesn't make an AI car ram them, even CARELESS/`combatMode "BLUE"`/`speedMode "FULL"` — the pathfinder treats a person as an obstacle and a destination as a place to arrive, halting a few metres off, so a proximity-detonating suicide car on foot never reaches its target. Fix: accept the standoff — drive in on the pathfinder and detonate on proximity within arm range plus a short fuse (`fnc_random_event_car_bomb.sqf`). The alternative (scripting the last stretch with `disableAI "PATH"` + `setVelocity`) forces a hit but slides/snaps unnaturally. If ever driving a hull by `setVelocity`: ramp speed in a *script variable*, never by re-reading `vectorMagnitude velocity` — PhysX damps an externally set velocity on a wheeled hull within the tick, so the read-back returns near zero and the ramp collapses.

## A building door locks by variable, not command, and there is no per-door hit event

A house door is locked against the engine's "Open" action by setting `bis_disabled_Door_<N>` to `1` — there is no `lockDoor`. Opening a leaf is `animateDoor ["Door_<N>_rot", 1|0]`, a LOCAL effect that must run on every machine drawing the house; no event fires when a specific door is shot, only `HitPart` on the whole object. Door count and source names vary by model, so a lock loop sets `bis_disabled_Door_1..N` over a bounded range and animates `Door_<N>_rot`; a mission depending on the mechanic must filter candidate houses to those defining `Door_1_rot` (`isClass (configFile >> "CfgVehicles" >> typeOf _h >> "AnimationSources" >> "Door_1_rot")`). `bis_disabled_Door_*` set outlives the mission (terrain houses are never deleted), so clear it on every end path or strand the town. Fix: for "shoot the door open", add a `HitPart` handler on all machines (see [§Practice targets ignore damage](#practice-targets-ignore-damage-entirely-hitpart-fires-on-the-shooter-not-the-owner)), then unlock every `bis_disabled_Door_*` and `remoteExec` the `animateDoor` sweep to `0` from the server. Raid-safehouse (`server/missions/mission_threads/raid_safehouse/`): `fnc_raid_safehouse_arm` adds the `HitPart`, `fnc_raid_safehouse_breach` does the server-side unlock.

## A `Draw3D` / `onEachFrame` block captures no local variables from where it was added

Code handed to `addMissionEventHandler ["Draw3D", {...}]` (and `onEachFrame`) runs in a fresh scope every frame, not the scope it was written in — no closure, so a `private` from the enclosing function is `nil` inside at draw time. Fix: store per-draw state in `missionNamespace` globals set before the handler is added, or inline constants in the block (`fnc_draw_world_icons.sqf` uses the global `DUWS_icon3d_rows`; the furnish overlay, `client/debug/fnc_debug_furnish_view.sqf`, reads its mode from a global and inlines its palette — a palette left as an outer `private _palette` compiles clean and then draws nothing). Tear down by the id `addMissionEventHandler` returns (`removeMissionEventHandler ["Draw3D", _id]`), never with a bare `onEachFrame {}` (clears every stacked handler in the mission).

## An array cached with `setVariable` is a shared reference; a consumer that mutates it corrupts the cache

SQF arrays are reference types — `setVariable`, `pushBack` and plain assignment store the *reference*; only `+` deep-copies. An array stashed with `setVariable` and read back by a consumer that mutates it writes through to the cache — the furnish grid (`fnc_furnish_grid.sqf`) caches its per-storey cell array on the building; the placer (`fnc_furnish_building.sqf`) stamps `occupied` on each cell, so without a copy a second furnish reads every cell already occupied. Fix: any function reading a `setVariable` cache and writing into the returned structure must deep-copy first (`+value`) — grouping cells with `pushBack` copies only references, so mutating a grouped cell still writes through.

## A command applied to an argument inside a `remoteExec` target trips a spurious `Missing ]`

`[msg] remoteExec ["hint", clientOwner _x]` — a command applied to an argument directly in the target slot — makes the in-engine SQF parser reject the whole enclosing function with `Missing ]`, though the brackets balance; sqf-vm accepts it, so the break surfaces only in the game `.rpt` at compile time, and a function that fails to compile is silently never defined (a whole side mission failed to generate, no runtime error). Computed targets aren't forbidden — `remoteExec ["addAction", [0,-2] select isDedicated, _hostage]` compiles — only the bare command-applied-to-argument form fails. Fix: hoist the target to a local first — `private _owner = clientOwner _x; [msg] remoteExec ["hint", _owner];`. A green sqf-vm run is necessary but not sufficient: read the `.rpt` after a build.

## A non-existent command reads as two adjacent values and reports `Missing ;`, not "unknown command"

`_x disableSimulation true` — not a real command (the freeze is `enableSimulation false`) — makes the parser see a value, an unknown identifier, then another value with no operator between, and report `Missing ;` on the following token, naming a syntax fault rather than the wrong command name. A file that fails to parse never runs its body — and when that body's top level assigns a `DUWS_fnc_*` (this file defines `DUWS_fnc_opcom_advance` at its head), the function is silently left undefined, so every unrelated caller throws `Undefined variable` and the whole subsystem stalls with no hint at the true file. Fix: when the RPT points `Missing ;` at a command call, first check the command exists and is spelled right — sqf-vm also accepts the bad token as an identifier, so this clears unit tests and surfaces only in the game `.rpt`.

## `setRain` shows nothing unless overcast is at least 0.5

Rain only renders over an overcast of 0.5 or higher — `setRain 1` under a clear sky shows nothing; the floor is hard and independent of the overcast transition otherwise. Fix: floor the overcast at 0.5 whenever rain is wanted, then force it before setting rain — `if (_rain > 0) then { _overcast = _overcast max 0.5 }; 0 setOvercast _o; forceWeatherChange; 0 setRain _r;` (`fnc_rest_heal.sqf`), done behind a black screen since the `0`-time force snaps the sky in one frame.

## A boat given a move waypoint (or spawned) on land beaches ashore, not stops at the shoreline

A boat ordered to a `MOVE` waypoint inland climbs up the beach toward it rather than halting at the water's edge, and one spawned on land simply sits there — there is no engine "amphibious ceiling"; keeping a boat wet is the caller's job. OPCOM's ferry hands a boat only navigable-water nav targets (`DUWS_fnc_opcom_ferryApproach`), snapping any land pickup/drop to the nearest water cell (`DUWS_fnc_opcom_nearestWater`) while the rider board-despawns and respawns across the water-to-shore gap; the boat never receives the land point. This is asymmetric with the rider rule: `DUWS_fnc_opcom_advance`'s shore-stop fires only for a `transportable` unit, so a boat has no mover-level guard and must be kept off land by target choice alone. Fix: never point a boat's movement (a waypoint, a `deVirt` spawn, a ferry rendezvous or drop) at a land cell — resolve the nearest navigable-water point first and let a reach margin (`OPCOM_FERRY_BOARD_BOAT`, 100 m) bridge the remainder; `fnc_opcom_route` refuses a cross-land boat route but degrades to "hold straight" rather than hard-refusing a land destination.

## `selectionPosition` takes `FireGeometry`, not `GeometryFire`

The array form's LOD argument is an engine enum matched word-order-exactly (`Memory`, `Geometry`, `FireGeometry`, `LandContact`, `HitPoints`, and since 2.06 `ViewGeometry`) — writing the Oxygen display order, `"GeometryFire"`, fails with `Foreign error: Unknown enum value: "GeometryFire"`, and the script keeps going past the failed evaluation, so the damage is silent (a fall-through chain loses the rung, one RPT error block per probe that reaches the bad name — first seen at the raid safehouse's door-point broadcast, `fnc_house_door_pts.sqf`). Fix: spell LOD names with `Geometry` last and probe in the engine's own search order — `forEach ["Memory", "Geometry", "FireGeometry"]`. For an unambiguous hit, pass the LOD's resolution as a number instead of a name (FireGeometry is `7e15`).

## `lineIntersectsSurfaces` stops at tree trunks but not at leaves or bushes

The ray tests geometry LODs, so it stops at buildings, rocks and tree trunks. A tree canopy has alpha-textured leaves and no geometry, and a low bush has no geometry LOD, so the ray passes through both although they hide a man. A sight that the ray alone certifies can look straight into a bush. Grass is client-side clutter with no object, so no command can test it. Fix: test the sight with `fnc_sightline_clear` (`shared/functions/fnc_sightline_clear.sqf`). It runs the ray and then `fnc_sightline_foliageClear`, which samples the line for `TREE`/`SMALL TREE`/`BUSH` terrain objects. The recon hold check, the recon overwatch pick and the enemy-sniper perch pick all use it.

## `nearestTerrainObjects` measures 3D distance unless its fifth argument is `true`

The fifth argument (`2Dmode`) defaults to `false`, so the radius is a sphere around the given point. A point above the ground, such as a sample along a sightline, then misses a bush or tree below the sphere. `fnc_sightline_foliageClear` described a 2D lookup but left out the argument, so it missed vegetation under its raised samples. Fix: pass `false, true` (unsorted, 2D) when the question is "what stands at this map spot", as `fnc_site_terrain.sqf` does.

## A static's bag list is `assembleInfo >> dissasembleTo`, misspelled, and the English spelling reads empty

A static weapon names the backpacks it breaks into in `CfgVehicles >> <static> >> assembleInfo >> dissasembleTo[]`. The engine puts the double s first (`dissasemble`), where English puts it second (`disassemble`). `getArray` on a key that does not exist returns `[]` and logs nothing, so the English spelling `disassembleTo` gives every static no bags and gives no error. The bag side of the same link, `assembleTo`, is spelled correctly. Fix: read `dissasembleTo` as the engine writes it, as `fnc_create_ammo_lists.sqf` does for the static assembly bags on the arsenal shelf. An empty array from `dissasembleTo` means that the static cannot be assembled from bags.
