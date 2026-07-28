# Civilian interaction: design notes

The scroll-wheel actions on a civilian collapse into one dialog, built like the Requests and
Squad Manager screens. What the town will do for the player is rolled against its reputation
rather than gated on it, so the `-20 … 20` scale that
[`per_town_reputation_plan.md`](per_town_reputation_plan.md) introduced finally has a consumer
that reads more of it than `> 0`.

Civilians are primarily an **information** channel: locals are how the player learns where the
enemy is. Supplies stay for now and are marked for rework rather than settled.

## Why the current shape is replaced

| Problem | Where |
|---|---|
| Six actions crowd one civilian's scroll menu, each its own file and its own handshake | `fnc_addAskEnemyAction`, `fnc_civ_askForAid`, `fnc_civ_askForToolkit`, `fnc_civ_addDevelopInformantAction`, `fnc_civ_recruitAction`, `fnc_civ_lootAction` |
| Every request stacks three gates — a `rep > 0` boolean, a coin cost, and a success roll — so paying does not mean getting | the same six |
| Reputation is read as a boolean, so a town at 1 and a town at 19 behave identically | `fnc_civ_repAt` callers |
| Develop-informant costs 5 coins at a 15 % ceiling to set `civ_informant_active_<town>`, whose only reader is the check that stops you buying it twice | `fnc_civ_developInformantServer.sqf`, `fnc_civ_addDevelopInformantAction.sqf:14` |
| Ask-enemy reveals a group within 700 m — inside spotting range — while its own docstring claims 1500 m | `fnc_civ_askEnemy_server.sqf` |
| Aid strictly dominates toolkit: 1 coin guaranteed against 2 coins at 50 %, and the cheaper one is the one that despawns | `fnc_civ_askForAid_server.sqf`, `fnc_civ_askForToolkit_server.sqf` |

## The reaction curve

Every request rolls one of three reactions, weighted by the town's reputation. With
`t = rep / 20` clamped to `[-1, 1]`:

```sqf
accept = if (t <= 0) then { (1 + t) / 3 } else { (1/3) + t * (0.9 - 1/3) };
refuse = accept evaluated at -t;      // exact mirror
bribe  = 1 - accept - refuse;         // the remainder
```

| Rep | Accept | Bribe | Refuse |
|---:|---:|---:|---:|
| −20 | 0 % | 10 % | 90 % |
| −10 | 17 % | 22 % | 62 % |
| 0 | 33 % | 33 % | 33 % |
| +10 | 62 % | 22 % | 17 % |
| +20 | 90 % | 10 % | 0 % |

Piecewise linear with a kink at zero, because accept climbs faster above neutral than below it.
Bribe is a symmetric tent peaking at neutral: a town that neither likes nor hates the player is
where money talks loudest, and at both extremes standing decides instead of coins.

**There is no hard refusal wall.** A town at `-20` still takes a bribe one time in ten, so
hostile ground is expensive rather than closed. The player is never locked out of a settlement
they have ruined — the garrison and the aid missions remain the routes back, but a determined
player can still buy a single answer.

**The band boundary is not a cliff on this curve.** `±10` reads 62 % / 17 %, so the ellipse
colour hints at the reception rather than predicting it. That is a deliberate loss of map
legibility in exchange for reputation mattering continuously instead of at two thresholds.

## One attempt per category, and a refusal closes the civilian

The roll is scoped to the individual, not the town:

| Outcome | Effect |
|---|---|
| Accept | the request is served; that category is spent on this civilian, other categories stay open |
| Bribe, paid | as accept |
| Bribe, declined or unaffordable | the civilian will not talk again, in any category |
| Refuse | the civilian will not talk again, in any category |

This is what stops the curve being decorative. A per-attempt roll with no cost lets a player at
`-20` work down a fifty-strong town until one civilian says yes, which is the failure the heal
action had before `fnc_civ_healed.sqf` replaced it: a failed roll consumed nothing, so the
player simply clicked again. Here a refusal costs a person, so a hostile town burns through
roughly ten civilians per successful deal against one in ten at a friendly one, and the town's
population is finite until it respawns.

State lives on the unit — a closed flag, and one spent flag per category — so it dies with the
civilian and needs no registry.

## What moves and what stays

**Into the dialog:** intel, supplies, recruit, loot. All four are requests *to the settlement*;
the individual civilian is the doorbell. Loot is the odd one — it is coercion rather than
conversation, which is why the dialog is titled *Civilian Interaction* and not *Talk to a
local*. It keeps the orange treatment it already renders with.

**Stays on the scroll wheel:** call over. It is positional and instant, and a dialog would ruin
it.

**Already gone, and not returning as rows:** civilian fast travel (removed), and the custom
heal action, replaced by a `HandleHeal` listener that credits the town once per economy tick
(`server/misc/fnc_civ_healed.sqf`). Healing is a give, not a request, so no reaction is rolled
for it.

## The dialog

`shared/includes/disguise_menu.hpp` is the nearest template: its own idc block so nothing
clashes, framed rows each carrying a description and a button, and buttons that `closeDialog 0`
then `remoteExec` the work to the server. `request_menu.hpp` supplies the other half if a row
needs a dropdown — an `RscCombo` whose selection the handler reads with `lbCurSel`.

A new `shared/includes/civ_menu.hpp` and one `#include` in `src/description.ext`. One
`addAction` on every civilian opens it, replacing six.

**The client does not need the town's reputation.** The rows are the same whatever the band —
only the outcome differs, and that is rolled on the server when a row is picked. This settles
the question the per-town plan left open about broadcasting town state: nothing has to be
broadcast, because no client-side decision depends on it.

**Rows carry no price, and a bribe gets its own prompt.** The reaction is unknown until the
roll, so a price on the row would be a guess at a demand that arrives two thirds of the time at
best. Picking a row is therefore free of commitment; if the roll comes back `bribe`, a second
dialog states the amount and the player answers it.

The prompt carries three things: the demand, an **In Inventory: X** readout of the player's
`Money_roll` count, and Accept / Refuse. Accept is disabled — `ctrlEnable [idc, false]` — when
the count falls short, so an unaffordable demand reads as unaffordable instead of failing on
click. The inventory line goes on the main menu too; it is the same count and it is what the
player needs to decide anything.

Chaining a second dialog is the established shape here: `squadmng.hpp:104` closes itself and
opens `squad_rename_dialog` the same way.

**The greyed button is advisory, and the server re-checks.** The count comes from
`magazines player` on the client, which is a snapshot the server has no reason to trust — in
co-op two players can spend the same coins. The deduction stays server-side and refuses on its
own read, exactly as [`info/cp_economy.md`](info/cp_economy.md) describes for the client-side CP
pre-filters. Greying the button spares the player a pointless click; it decides nothing.

Refusing, and being unable to pay, both close the civilian. That rule does not soften now the
amount is visible: what the prompt buys the player is knowing the price before they lose the
contact, not a free look.

### What a bribe costs

Per category, and **not** scaled by reputation — the curve already carries that signal by
deciding whether money is asked for at all, so a reputation term in the amount would count it
twice.

| Row | Bribe |
|---|---:|
| Intel | 3 |
| Recruit | 2 |
| Supplies | 1 |
| Loot | — |

**These are placeholders chosen to make the framework testable, not balanced figures.** They
are anchored on the black market, which is the price scale the player already reads — goggles
at 1, pistol and optic at 5 — so intel sits between the two and recruit keeps the cost it has
today. Intel is deliberately *not* inheriting the old ask-enemy price of 1: that bought a marker
on a group within 700 m, inside spotting range, whereas the row now reveals a zone or a hidden
hardpoint or hands over an intel object worth up to 8 CP.

Loot takes no bribe and no reaction roll. It is coercion, not a request; a town's opinion does
not change whether a rifle works. Its existing surrender and reprisal rolls are untouched.

**Expect the coin drain to fall against today's.** Every current action charges every time; here
a bribe is asked roughly half the time at a neutral town and one time in ten at a friendly one.
That is the discount for carrying refusal risk and for having earned the town's standing, and it
pushes coins toward the black market and partisans, which are the underused sinks.

## What intel buys

An accepted intel request rolls one payout at random from the kinds available. The pool grows
as the systems behind it land; two of the four exist today.

| Kind | State | Mechanism |
|---|---|---|
| An unrevealed enemy zone | **buildable** | `zone_namePOS_pairs` carries `[name, pos, revealed]` (`fnc_createzone.sqf:28`); filter for `select 2 == false`, pick one, reveal it |
| An intel object to carry home | **buildable** | add one of the classes `fnc_intelAnalysis.sqf:8-16` accepts, which the player cashes at a terminal for CP |
| An unrevealed normal hardpoint | **blocked** | hardpoints are unimplemented — `hardpoint_system_plan.md` is a plan and nothing in `src/` builds one. Available in both modes once they exist, though the pool differs: normal mode offers only what the director has built since, hardcore adds the batch generated at campaign start |
| An unrevealed enemy patrol | **blocked** | needs the OPFOR commander's tasking, per [`opfor_commander_plan.md`](opfor_commander_plan.md) |

Rolling over the *available* kinds rather than a fixed list is what lets the other two appear
without touching this code again.

**The hardpoint payout works in both modes**, because visibility turns on when a thing came into
existence rather than on the difficulty setting: campaign generation puts its output on the map
in normal mode, and anything OPFOR build during play stays hidden either way. Decided in
[`hardpoint_system_plan.md`](hardpoint_system_plan.md#reveal) rather than here. Only the
announcement differs — normal mode says OPFOR are fortifying without saying where, hardcore says
nothing — so in both this menu is one of only two things that can surface a location, alongside
the body-search path, and the alternative to both is walking into its fire.

The pool still varies with what a campaign has generated and what OPFOR have since built, which
is why it is rolled over *available* kinds rather than a fixed list. An entry with nothing to
give simply never enters the draw.

**Revealing a zone through `fnc_zone_reveal` drags two side effects along.** It zeroes
`master_Intel_chance` for twenty minutes (`fnc_zone_reveal.sqf:44-50`), suppressing the
corpse-and-mission intel drops campaign-wide, and it sets `hardcore_visibleZone_found`, which is
what unblocks task-force assaults in hardcore (`fnc_request_squad.sqf:82`). The second is
probably wanted. The first is a throttle on *free* intel and reads wrong on a reveal the player
paid a bribe for, so the civilian path should either skip the cooldown or accept that buying one
answer switches off another source for twenty minutes. Undecided.

Its trailing `sleep 1200` also means the function must be `spawn`ed, never `call`ed — a `call`
would park the caller for twenty minutes.

## Open questions

- Balancing the bribe figures once the framework runs. The values above exist to make it
  testable. What is not measured is the coin supply they meet: the HQ crate hands out 20 once
  and never refills, and enemy infantry drop **0.267 coins each** (80 % carry loot,
  `floor random 3` items, one class in three) — so a thirty-enemy zone assault yields about
  eight coins. Whether that pays for a campaign of talking to towns is the first thing to watch.
- Whether a paid zone reveal carries `fnc_zone_reveal`'s twenty-minute `master_Intel_chance`
  cooldown, or skips it. The cooldown throttles free intel; this intel is not free.
- Whether supplies survive the rework, and what gives the toolkit a reason to exist alongside
  aid if they do.
Develop-informant is not on this list. It is deleted outright — the action, the server
function, `civ_informant_active_<town>` and twelve strings — rather than folded into a row.

It worked, and that is not the reason it goes. On success it drew a 700 m disc over the town and
spent one to three hours marking every enemy unit inside it, refreshed each minute. That is a
tactical feed about ground the player has already found, and intel here means the opposite:
discovering positions the player does not yet know exist. See
[`hardcore_mode_plan.md`](hardcore_mode_plan.md#what-intel-is-for). Rebuilding a local unit
tracker later is a separate feature with a separate justification, not a row on this menu.
