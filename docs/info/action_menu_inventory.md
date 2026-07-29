# Action Menu Inventory

Every scroll-wheel entry DUWS itself creates. Vendored modules under `src/modules/` add their
own and are listed separately at the end.

Three mechanisms produce entries, and they are not interchangeable:

| Mechanism | Produces | Used for |
| --- | --- | --- |
| `addAction` | An instant scroll entry | Almost everything |
| `BIS_fnc_holdActionAdd` | A hold-to-complete entry with an on-screen icon and progress ring | Searching bodies and containers, the disguise panel, `fnc_actionRotary` props |
| `fnc_open_action_menu` | A dialog listbox opened *by* one scroll entry | Collapsing a cluster of related entries into a single scroll row |

`src/duws/client/dialog/fnc_open_action_menu.sqf` is the escape hatch from scroll-menu sprawl:
Black Market, Mission Control, Vehicle Recycling, Vehicle Customization, Killhouse Controls,
Quick Kits and the debug menu each occupy one scroll row and expand into a list. Rows in that
listbox are *not* action-menu entries and are excluded from the inventory below.

## Buckets

Every entry belongs to a bucket, and the bucket decides both how the title looks and where the
entry sits in the scroll list. `src/duws/shared/includes/action_style.hpp` defines one macro per
bucket; call sites pass a stringtable key and never write markup themselves.

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

**Colour lives in the header, not in `stringtable.xml`.** A value that carries its own `<t>`
markup freezes that markup into every translation: the variants drift apart — one entry once
shipped coloured in German and plain in English — and a listbox row renders the tags literally
rather than applying them. Keys stay plain text so the bucket alone decides appearance.

**Four buckets deliberately share one blue.** Navigational, medical, social and informational
entries read as one ambient family against the loud consequence colours. They stay four named
macros rather than one so priority keys off the bucket, and splitting a blue back out later is a
one-line edit in the header.

**`ACT_COMMIT` sits lowest on purpose.** Priority orders the scroll list, and a mis-scrolled
15 CP spend costs more than a buried one.

**A bare `&`, `<` or `>` in a title breaks the entry.** Titles are wrapped in `<t>` markup, so an
unescaped ampersand ends the structured-text parse and swallows the rest of the entry. Use `/`
or a different word — `Rest / Heal`, `Mission Control`.

## Inventory

Priority and colour follow the bucket, so neither is repeated per row.

### Primary menu

| Entry | Key | Attached by |
| --- | --- | --- |
| Requests | `STR_DUWS_T_vw32hahc` | HQ building, FOB |
| Squad Manager | `STR_DUWS_T_l0xark5g` | HQ building, FOB |
| FOB Manager | `STR_DUWS_T_iggpsdqo` | HQ building, FOB |

### Secondary menu

| Entry | Key | Attached by | Rows |
| --- | --- | --- | --- |
| Black Market | `STR_DUWS_T_BLACKMARKET_TITLE` | HQ terminal | 3 |
| Mission Control | `STR_DUWS_T_INTELRECRUIT_TITLE` | HQ terminal | 3 |
| Killhouse Controls | `STR_DUWS_T_KILLHOUSE_CONTROLS` | Multi-screen computer | 4 |
| Vehicle Recycling | `STR_DUWS_T_VEHICLE_RECYCLING` | Depot | 2 |
| Vehicle Customization | `STR_DUWS_T_VEHICLE_CUSTOMIZATION` | Depot | 4 |
| View Map | `STR_DUWS_T_civ_mapview_action` | HQ map board | — |
| Fast Travel | `STR_DUWS_T_FAST_TRAVEL_BASE` | HQ map board | — |

The two board entries open a readout and a map-click rather than a listbox, so they carry no row
count. Fast Travel is a relocation and belongs to `ACT_MOVE` by consequence; it sits here so the
map board reads as one group and does not disappear into the same blue as the earplugs toggle.
Both outrank the Killhouse teleports on the same board, and View Map is added first, so it heads
the list.

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

Three separate keys share the label `Set Waypoints`. That is deliberate: helo taxi, boat taxi and
the lift request are independently translatable but present the same choice to the player.

### Aid

| Entry | Key | Attached by |
| --- | --- | --- |
| AI Heal / Rearm | `STR_DUWS_T_xfgokhbc` | Medical tent, FOB, MHQ ammobox, airdropped ammobox |
| Rest / Heal | `STR_DUWS_T_9eiwr3bt` | Satellite phone, FOB — `game_master` only, 600 s cooldown in the callback |

### Civilian interaction

| Entry | Key | Shown when |
| --- | --- | --- |
| Halt | `STR_DUWS_T_CIV_STOP` | Within 3 m, inside a 15° facing cone, not panicking |
| Interact | `STR_DUWS_T_CIV_MENU_ACTION` | Alive, called over, within 3 m, not surrendered, not spent |
| Search | `STR_DUWS_T_LOOT` | Within 3 m and surrendered |
| Release | `STR_DUWS_T_RELEASE` | Within 3 m, surrendered, still civilian-side |
| Evacuate | `STR_DUWS_T_RECRUIT_ACTION` | Always |

Interact opens `civ_dialog` rather than `fnc_open_action_menu`, because its rows need per-row
greying against coin count, town state and range. Search stays a scroll entry rather than becoming
a dialog row: the menu hides on `isSurrendered`, so offering it there would mean closing, waiting
out the surrender animation and reopening.

### Util

| Entry | Key | Attached by |
| --- | --- | --- |
| Earplugs | `STR_DUWS_T_2rc0nvug` | `player` |
| Debug | `STR_DUWS_T_DEBUG_ACTION` | `player` — needs the `DUWS_Debug` parameter and `game_master` |
| Reset Squad Leader | `STR_DUWS_T_4jabuvz6` | HQ building |
| Mission Cooldowns | `STR_DUWS_T_SHOW_MISSION_COOLDOWNS` | HQ building, FOB — `player1` only |

### Commit

| Entry | Key | Attached by |
| --- | --- | --- |
| Redeploy Base Units (2 CP) | `STR_DUWS_T_REDEPLOY_ACTION` | HQ building |
| Replace FOB Defences (5 CP) | `STR_DUWS_T_qxrh9fws` | FOB |
| Replace Guards (15 CP) | `STR_DUWS_T_p5i8fe14` | FOB |
| Deploy / Undeploy Mobile HQ | `STR_DUWS_T_rqzxlvf4`, `…_fjpyu3zb` | `MHQ1` — `Squad_Leaders` only |
| Sabotage | `STR_DUWS_T_p3200mf5` | Laptop |

### Plain entries

Two groups take no macro. The rescue-pilot set is the only feature whose entries are a bucket to
themselves; the searches identify by their hold icon, so colour on the title would duplicate a
signal the player already has.

| Entry | Key | Icon |
| --- | --- | --- |
| Carry Pilot / Drop Pilot / Load Into Vehicle / Unload Pilot | `STR_DUWS_T_carry_pilot` and siblings | — |
| Search For OPFOR Positions | `STR_DUWS_T_INTEL_SEARCH_ACTION` | `holdAction_search_ca.paa` |
| Search Body | `STR_DUWS_T_SEARCH_CORPSE_ACTION` | `holdAction_search_ca.paa` |
| Search Container | `STR_DUWS_T_SEARCH_CONTAINER` | `holdAction_search_ca.paa` |
| Search Intel | `STR_DUWS_T_7yec9ifj` | `holdAction_search_ca.paa` |

`STR_DUWS_T_SEARCH_CORPSE_ACTION` exists separately from `STR_DUWS_T_SEARCH_CORPSE`, which titles
the "bodies may carry intel" notification in nine side missions. They were one key; the action
needed a label and the notification needed a sentence.

`fnc_actionRotary` also serves `holdAction_connect_ca.paa` and `holdAction_talk_ca.paa` props —
the talk icon is the one not from `\a3\ui_f\data\IGUI\Cfg\holdactions\`.

## Call-site conventions

**Slot arity is uniform.** `addAction`'s array is positional — `[title, script, arguments,
priority, showWindow, hideOnUse, shortcut, condition, radius, …]`. Every DUWS call passes eight
elements, or nine where `radius` is used (the rescue-pilot set). The `arguments` slot is `[]` when
there are none; a shorter array silently inherits engine defaults, which is how Open Chute went
without a condition and the Mobile HQ entries without a priority.

**One broadcast path.** Actions attached from the server go out as
`remoteExec ["addAction", [0,-2] select isDedicated, <object>]`. The target skips a dedicated
server, which has no interface to draw a scroll menu on. The third argument is the owning object
rather than `true`: an auto-generated JIP id outlives the object it decorates and leaves a queue
entry per object forever, where an object-keyed message is dropped when that object is deleted.
That id *is* the object's netId, so two broadcasts against one object write the same queue key and
the later silently evicts the earlier — a gap only a late joiner ever sees. Give an object all its
entries in a single broadcast where you can: `fnc_ammobox_actions` attaches both the arsenal and
the rearm entry for the airdropped and Mobile HQ boxes, which keeps the object-keyed id and the
lifetime that goes with it, and the Mobile HQ depends on that lifetime because undeploy deletes
its box. Suffix the id only when the entries genuinely cannot share a call — the FOB's defences
and guards entries are attached from different files at different times, and the killhouse
terminal's gear is attached after its controls menu.

**A function that is already broadcast must attach locally.** `fnc_FOBactions` and
`fnc_ammobox_actions` run on every machine, so a plain `_obj addAction` inside them produces
exactly one entry per machine. A `remoteExec` inside such a function instead fans out once per
machine that runs it, so an eight-player session gets eight copies of that one entry on every
screen — and a single-player test shows one, because there is only one machine to multiply by.

**Duplicate guards must stay machine-local.** The adders are broadcast to every client and each
client adds its own local action, so a guard written with a public `setVariable` lets the first
client through and locks every other one out permanently.

## Menu rows

`fnc_open_action_menu` takes `[r,g,b,a]` floats per row. Row labels are plain text — a listbox
renders `<t>` markup literally rather than applying it — so a scroll-entry colour and a row colour
cannot share a definition.

| Menu | Row colours |
| --- | --- |
| Black Market | `[0,1,0,1]` on all three purchases |
| Mission Control | `[1,0.667,0,1]` on all three rows |
| Killhouse Controls | `[0,1,0,1]` spawn targets, `[1,0,0,1]` spawn enemies, `[1,1,0,1]` cleanup, `[1,0.533,0,1]` exit |
| Vehicle Recycling | None — both rows default |
| Vehicle Customization | None — all four rows default |

## Vendored module entries

Not DUWS-authored, but they share the same scroll menu, the same priority space, and the same
`<t>` markup. DUWS now bands from 10 to 100, so every vendored entry sits below every DUWS entry.

| Module | Entries | Source and formatting |
| --- | --- | --- |
| AIS | First Aid/Revive, Stabilize, Drag, Carry, Release, Unload Injured, Load Injured | `src/modules/AIS/System/fn_postinit.sqf`, added through `AIS_Core_fnc_addAction` at a fixed priority of 1.5. Titles are hardcoded English and restyled through `setUserActionText` with `#E9FDF7` text plus a per-action `<img>` icon — the only entries in the scroll menu that carry an inline image |
| R3F Logistics | Object move/rotate/align entries and the config-tool dump actions | `src/modules/R3F_LOG/objet_deplacable/deplacer.sqf:166-171`, priority 10 on release and 6 on the rest, coloured `#ee0000` and `#00eeff` |
| TAW View Distance | View-distance menu | `src/modules/taw_vd/fn_openMenu.sqf`, reached through the CfgFunctions include in `src/description.ext` |
