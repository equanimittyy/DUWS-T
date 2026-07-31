# Player-facing text and actions

Everything the player reads lives in `src/stringtable.xml`, grouped into `<Container>` blocks by
subsystem. Keys are `STR_DUWS_T_*` (a handful of newer ones use a bare `STR_DUWS_*` prefix);
lookups are case-insensitive, so a `localize` that differs in case from the `Key ID` still
resolves. The second half of this doc inventories the scroll-menu entries that carry much of it.

## English is the source of truth

Every key carries both `<Original>` and `<English>`, and Arma falls back to `<Original>` when the
active language has no tag. **Edit the two in lockstep** — changing only `<English>` leaves the old
wording live for anyone whose game language isn't listed on that key.

## The localised tags lag English on purpose

The `<German>`, `<Spanish>` and `<Chinesesimp>` tags were translated from the pre-rework text and
have not been carried through the English prose passes. They still hold the retired callsigns
(`Action Squad`, `Overlord 1-1`), the old unnamed-department phrasing for Allseer, and pre-rework
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

## Register

The reference for radio prose is the `Support & Radio` container: speaker-first callsign framing
(`Alpha 1-1, this is Overlord.` / `Swordfish 1-1 to Alpha 1-1, ...`), procedure words (*be advised,
roger, stand by, over, out*), numbers spelled out in spoken lines but numerals in HUD text, and flat
declaratives — Overlord does not shout. Hints carry no trailing period; subtitles do.

## Side-mission briefings carry their own reward block

One key per side mission serves both the strategic-map card and the task description, so the same
text has to read as a briefing in either place: situation, task, then any timer or kit the player
has to plan around. It ends with the reward, laid out on its own lines after a blank one:

```
&lt;br /&gt;&lt;br /&gt;CP: 45&lt;br /&gt;AP: 15
```

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
entries and are excluded from the inventory below.

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

## Inventory

Every scroll entry DUWS itself creates; vendored modules are listed separately at the end. Priority
and colour follow the bucket, so neither is repeated per row.

### Primary menu

| Entry | Key | Attached by |
| --- | --- | --- |
| Requests | `STR_DUWS_T_vw32hahc` | HQ building, FOB |

Squad Manager (`STR_DUWS_T_l0xark5g`) and FOB Manager (`STR_DUWS_T_iggpsdqo`) are the first two
buttons of the command column inside it. They print as written rather than uppercased: capitals were
a property of the scroll bucket, and a button carries no bucket.

### Secondary menu

| Entry | Key | Attached by | Rows |
| --- | --- | --- | --- |
| Black Market | `STR_DUWS_T_BLACKMARKET_TITLE` | HQ building | 3 |
| Killhouse Controls | `STR_DUWS_T_KILLHOUSE_CONTROLS` | Multi-screen computer | 4 |
| Vehicle Recycling | `STR_DUWS_T_VEHICLE_RECYCLING` | Depot | 2 |
| Vehicle Customization | `STR_DUWS_T_VEHICLE_CUSTOMIZATION` | Depot | 4 |

View Map is no longer here. It is a button in the request menu's missions row, beside the mission
timers and the pools it is read against, because choosing where to go and choosing what to buy for
it are one decision. Travel between bases belongs to the FOB Manager; the board's own base fast
travel is gone, having only ever moved the player within 200 m of an HQ they were standing at, and
the board now carries the killhouse teleports alone.

Mission Control is gone as a menu: its three entries spend CP, which is command's business, so each
became a button of its own in the command column. The black market stayed on the scroll wheel,
because it spends the coins a player takes off civilians instead — nobody has to ask for that. Both
hung off the HQ structure rather than a terminal of their own, so the one that stayed is added by
`fnc_addHQBuildingActions` alongside Requests, in the single broadcast that object gets.

### Equip

| Entry | Key | Attached by |
| --- | --- | --- |
| Arsenal | `STR_DUWS_T_160jkc3a` | HQ, FOB, MHQ ammobox, airdropped ammobox, multi-screen computer |
| Quick Kits | `STR_DUWS_T_QUICK_KITS` | Supply crate, multi-screen computer |
| Full Arsenal | `STR_DUWS_T_FULL_ARSENAL_ONCE` | Cache boxes, supply truck |
| Disguise | `STR_DUWS_T_DISGUISE_MENU_ACTION` | `player` (hold, 1 s) |

### Move

| Entry | Key | Attached by |
| --- | --- | --- |
| HALO Solo / Group / Group (AI Only) | `STR_DUWS_T_foldimok`, `…_u6btu73i`, `…_halo_ai_only` | HQ, FOB, squad-leader units |
| Killhouse A / B | `STR_DUWS_KILLHOUSE_TELEPORT_A` / `_B` | HQ map board |
| Set Waypoints | `STR_DUWS_T_helotaxi_action_wp`, `…_boattaxi_action_dest`, `…_helolift_action_wp` | Taxi helo, taxi boat, `player` during a lift |
| Set LZ | `STR_DUWS_T_helotaxi_action_lz` | Taxi helicopter |
| Set Destination | `STR_DUWS_T_boattaxi_action_loc` | Taxi boat |
| Open Chute | `STR_DUWS_T_bd22lcos` | `player` at HALO exit |

Three separate keys share the label `Set Waypoints` deliberately: helo taxi, boat taxi and the lift
request are independently translatable but present the same choice.

### Aid

| Entry | Key | Attached by |
| --- | --- | --- |
| AI Heal / Rearm | `STR_DUWS_T_xfgokhbc` | Medical tent, FOB, MHQ ammobox, airdropped ammobox |
| Rest / Heal | `STR_DUWS_T_9eiwr3bt` | Medical tent, FOB — `game_master` only |

Rest / Heal is two entries again, one per base kind, but both now take the server-checked path.
They had shared one 600 s cooldown through `GM_Heal_LastUsedTime` while testing it in different
places — the HQ copy deferred to `fnc_restHealServer`, where one machine decides, while the FOB copy
checked and stamped in its own client callback and then `publicVariable`d the result, so two players
triggering it inside one propagation window both passed.

Which base is rested is the object the entry sits on: `fnc_rest_heal` treats only what stands within
100 m of it, so a rest called at a FOB cannot patch up a fight at the HQ. That is also why it is on
the medical tent rather than on the HQ structure — the tent is where the wounded are.

### Civilian interaction

| Entry | Key | Shown when |
| --- | --- | --- |
| Halt | `STR_DUWS_T_CIV_STOP` | Within 6 m, inside a ±15° facing cone, not panicking |
| Interact | `STR_DUWS_T_CIV_MENU_ACTION` | Alive, called over, within 3 m, not surrendered, not arrested, not spent |
| Release | `STR_DUWS_T_RELEASE` | Within 3 m, surrendered, still civilian-side |
| Evacuate | `STR_DUWS_T_RECRUIT_ACTION` | Always, but only on RAVAGE/WBK civilians |

Interact opens `civ_dialog` rather than `fnc_open_action_menu`, because its rows need per-row greying
against coin count, town state and range. Searching a surrendered civilian carries no entry of its
own — it goes through the shared hold action below — and was never a row inside Interact either: the
menu hides on `isSurrendered`, so offering it there would mean closing, waiting out the surrender
animation and reopening. Reach and reputation are in
[`zones_and_civilians.md`](zones_and_civilians.md#range-two-distances-on-purpose).

**Evacuate never shares a civilian with the other four.** `fnc_civ_spawnUnit` branches on
`CIV_PRESENCE`: the vanilla path attaches Halt and Interact through `fnc_civ_clientActions`, and the
RAVAGE/WBK path attaches this instead — as do the WBK survivor spawns. A survivor you can recruit is
not a local you can question, so no civilian ever carries both sets.

### Util

| Entry | Key | Attached by |
| --- | --- | --- |
| Earplugs | `STR_DUWS_T_2rc0nvug` | `player` |
| Debug | `STR_DUWS_T_DEBUG_ACTION` | `player` — needs the `DUWS_Debug` parameter and `game_master` |

| Reset Squad Leader | `STR_DUWS_T_4jabuvz6` | HQ medical tent — `Squad_Leaders` only |

The first two hang off the player, so they follow whoever opened them anywhere on the map. Reset
Squad Leader and Mission Timers (`STR_DUWS_T_SHOW_MISSION_COOLDOWNS`) mean nothing away from a base,
so neither follows the player: the reset is on the tent and the timers are a button in the MISSIONS
box, Game Master only.

### Commit

| Entry | Key | Attached by |
| --- | --- | --- |
| Deploy / Undeploy Mobile HQ | `STR_DUWS_T_rqzxlvf4`, `…_fjpyu3zb` | `MHQ1` — `Squad_Leaders` only |
| Release Mobile HQ | `STR_DUWS_T_MHQ_RELEASE` | `MHQ1` while undeployed — `Squad_Leaders` only |
| Sabotage | `STR_DUWS_T_p3200mf5` | Laptop |

Release sits beside Deploy rather than beside Undeploy, so it is reachable exactly while the vehicle
is packed up and never while it is a working base. Undeploying is how the MHQ moves and is the common
action; releasing ends the designation and frees the one-at-a-time slot, which is rare and worth the
second click. Both are open to any squad leader, whether or not they carry the designation radio.
Designate Mobile HQ itself is never consumed — a lead holding that slot keeps the entry, so every one
of its refusals leaves them something to act on.

Redeploy Base Units (`STR_DUWS_T_REDEPLOY_ACTION`, 2 CP) is the last of the three administration
buttons at both the HQ and every FOB, which is the same reasoning that put `ACT_COMMIT` at the bottom
of the scroll list.
The two differ only in what the server is asked to rebuild — `fnc_redeployHQUnits` against
`fnc_redeployFOBUnits`, the latter carrying the FOB the menu was opened on.

### Plain entries

Two groups take no macro. The rescue-pilot set is the only feature whose entries are a bucket to
themselves; the searches identify by their hold icon, so colour on the title would duplicate a signal
the player already has.

| Entry | Key | Icon |
| --- | --- | --- |
| Carry Pilot / Drop Pilot / Load Into Vehicle / Unload Pilot | `STR_DUWS_T_carry_pilot` and siblings | — |
| Search | `STR_DUWS_T_INTEL_SEARCH_ACTION` | `holdAction_search_ca.paa` |
| Search Container | `STR_DUWS_T_SEARCH_CONTAINER` | `holdAction_search_ca.paa` |

Searching is one entry for the whole mission, on the player rather than on the thing searched
(`client/misc/fnc_intel_search_action.sqf`). Bodies, mission objectives and arrested civilians all
reach it through `cursorObject`, gated on a search flag the server sets; the reasoning is in
[`intel_system.md`](intel_system.md#one-action-on-the-player-not-one-per-searchable-thing). Search
Container is the exception: intel gathering attaches its own hold action per container, because it
hands physical intel items to the searcher rather than paying through the shared claim.

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
