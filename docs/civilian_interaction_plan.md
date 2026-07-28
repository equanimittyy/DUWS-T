# Civilian interaction: design notes

The scroll-wheel actions on a civilian collapse into one dialog, built like the Requests and
Squad Manager screens. What the town will do for the player is rolled against its reputation
rather than gated on it, so the `-20 … 20` scale per-town reputation introduced
([`info/zone_and_town_generation.md`](info/zone_and_town_generation.md#ownership-bands-and-the-garrison))
finally has a consumer that reads more of it than `> 0`.

Civilians are primarily an **information** channel: locals are how the player learns where the
enemy is. Everything else the menu offers is secondary to that.

## Why the current shape is replaced

| Problem | Where |
|---|---|
| Five actions crowd one civilian's scroll menu, each its own file and its own handshake | `fnc_addAskEnemyAction`, `fnc_civ_askForAid`, `fnc_civ_askForToolkit`, `fnc_civ_recruitAction`, `fnc_civ_lootAction` |
| Every request stacks three gates — a `rep > 0` boolean, a coin cost, and a success roll — so paying does not mean getting | the same five |
| Reputation is read as a boolean, so a town at 1 and a town at 19 behave identically | `fnc_civ_repAt` callers |
| Ask-enemy reveals a group within 700 m — inside spotting range — while its own docstring claims 1500 m | `fnc_civ_askEnemy_server.sqf:48` |
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

## One conversation per civilian

The roll is scoped to the individual, not the town, and every outcome ends the conversation:

| Outcome | Effect |
|---|---|
| Accept | the request is served, then the civilian walks off and will not talk again |
| Bribe, paid | as accept |
| Bribe, declined or unaffordable | as refuse |
| Refuse | the civilian walks off and will not talk again |

This is what stops the curve being decorative. A per-attempt roll with no cost lets a player at
`-20` work down a fifty-strong town until one civilian says yes, which is the failure the heal
action had before `fnc_civ_healed.sqf` replaced it: a failed roll consumed nothing, so the
player simply clicked again. Here a refusal costs a person, so a hostile town burns through
roughly ten civilians per successful deal against one in ten at a friendly one, and the town's
population is finite until it respawns.

A person who has helped is as finished with the player as one who refused, so a town is a finite
number of favours rather than a menu the player works down row by row on one obliging local.
Arrest sits outside the rule, because it is not a request and rolls nothing.

## What moves and what stays

**Into the dialog:** intel, aid, toolkit, recruit, arrest. The first four are requests *to the
settlement* and the individual civilian is the doorbell. Arrest is the odd one — it is coercion
rather than conversation, which is why the dialog is titled *Civilian Interaction* and not
*Talk to a local*.

**Stays on the scroll wheel:** call over, and the body search that follows a successful arrest.
Both are positional and a dialog would ruin them — see [§Arrest](#arrest) for why the second step
in particular cannot move. Call over is also the gate on the dialog: the menu action does not
appear until the local has been told to stop, so a player cannot work a whole town without ever
announcing themselves to anyone in it.

**Already gone, and not returning as rows:** civilian fast travel (removed), develop-informant
(deleted outright, for the reason in
[`info/intel_system.md`](info/intel_system.md#what-intel-is-for)), and the custom heal action,
replaced by a `HandleHeal` listener that credits the town once per economy tick
(`server/misc/fnc_civ_healed.sqf`). Healing is a give, not a request, so no reaction is rolled
for it.

## The dialog

`shared/includes/disguise_menu.hpp` is the nearest template: its own idc block so nothing
clashes, framed rows each carrying a description and a button, and buttons that `closeDialog 0`
then `remoteExec` the work to the server. `request_menu.hpp` supplies the other half if a row
needs a dropdown — an `RscCombo` whose selection the handler reads with `lbCurSel`.

A new `shared/includes/civ_menu.hpp` and one `#include` in `src/description.ext`. One
`addAction` on every civilian opens it, replacing five. The main menu takes idc block
**8300-8399** and the bribe prompt **8400-8499**; both are clear of every idc the mission ships,
the nearest neighbours being the disguise panel's 8000-8203 below and `fobmanager.hpp`'s lone
9745 above.

**The client does not need the town's reputation.** The rows are the same whatever the band —
only the outcome differs, and that is rolled on the server when a row is picked. This settles
the question the per-town plan left open about broadcasting town state: `civ_town_rep` stays
server-side, because no client-side decision reads it. The per-civilian state below is a
different thing and does go out.

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

Refusing, and being unable to pay, both close the civilian. That rule does not soften now the
amount is visible: what the prompt buys the player is knowing the price before they lose the
contact, not a free look.

### Everything the client greys, the server re-checks

Three client-side conditions decide what a row looks like, and none of them decides anything:

| Greyed when | Read from | Why the server cannot trust it |
|---|---|---|
| The player cannot afford a bribe | `magazines player` | A snapshot; in co-op two players can spend the same coins |
| The civilian is closed | the unit's own variables | Broadcast state a client machine holds a copy of |
| The player is further than conversation range | `player distance _civ` | Read once on open, so it is stale the moment they walk |

The deduction, the spend and the range test all stay server-side, exactly as
[`info/cp_economy.md`](info/cp_economy.md) describes for the client-side CP pre-filters. Greying
spares the player a pointless click; it decides nothing.

Range is read once on open rather than polled, the same way `fnc_disguise_menu.sqf` reads its
status line once — a picker does not need a watcher loop. The consequence is deliberate: the menu
opens at arrest range so the arrest row is reachable from a standoff, and the four conversational
rows grey out beyond 3 m, so walking in and reopening is what a conversation costs.

### State lives on the civilian

| Variable | Locality | Purpose |
|---|---|---|
| `DUWS_civ_stopped` | broadcast | Set when call over is answered. The menu action's condition gates on it, so nothing before it exists as an entry point |
| `DUWS_civ_closed` | broadcast | One exchange spends it — served, refused, or a bribe declined or unaffordable. Greys the four conversational rows; the menu action survives it, because arrest is not a conversation |
| `DUWS_civ_arrested` | broadcast | One hands-up attempt per civilian, spent on the attempt |
| `DUWS_civ_pending` | server only | `[caller, row, amount]`, written when a roll returns `bribe`, cleared when the prompt is answered |

The first three are broadcast because they are read off the server: the dialog is built on the
client that opens it and has to know at open time which rows are dead, and `DUWS_civ_stopped` is
read by an addAction condition on every machine that carries it. A boolean pushed when it changes
beats a request-and-wait handshake in front of every open, which would either delay the menu or
pop rows grey after the player is already looking at them — the same trade as `DUWS_intel_searched`
([`info/intel_system.md`](info/intel_system.md#the-throttle-is-per-player-and-the-attempt-is-what-it-spends)).

`DUWS_civ_stopped` is written server-side, in the call-over's own server function rather than in
the client action body that triggers it: a client that owns the flag can open the menu on a local
it never actually stopped.

The menu action's own condition does **not** read `DUWS_civ_closed` — a closed civilian still
shows the menu, because arrest survives closure. It gates on `alive`, on `DUWS_civ_stopped`, on
arrest range, and on the civilian not already being surrendered, which is what today's hands-up
action gates on (`fnc_civ_lootAction.sqf:85`).

`DUWS_civ_pending` is the opposite case and must not be broadcast. The Accept button sends only
*I accept* — the server reads which row and how much from its own record, so a client cannot
claim a bribe it was never offered or name its own price. It records the caller too, so in co-op
a second player cannot answer someone else's prompt.

All of it lives on the unit, so it dies with the civilian and needs no registry.

## What an accepted request pays

**Intel** hands off to `fnc_intel_payout`, the single point where intel becomes something for
every source in the mission —
[`info/intel_system.md`](info/intel_system.md#one-writer-per-reveal-flag-one-function-for-payout)
owns that contract, including which payout kinds exist and which are still waiting on unbuilt
systems. Nothing about the payout is decided here; the menu is a faucet like the body search, and
what a faucet pays is not the faucet's business. The one thing this row must pass is an origin —
the asking player's position — because the town bucket ranks by distance.

**Recruit** is unchanged behind the row: the accepted path is `fnc_recruitSuccessServer`, which
clears captive and broadcasts it itself.

**Aid and toolkit are one choice, not two**, because a civilian answers one request and then
walks. That is what fixes the dominance without inventing a number: the price is the same, the
odds are the same, and the only difference left is which item the player needs — aid for the
wounded, toolkit for the vehicle. The 50 % roll and the 2-coin price on the toolkit both go; they
were the third gate the whole rework removes.

The aid drop is a medikit *and three first aid kits*. A medikit is a tool with nothing to spend,
so against a toolkit that repairs a vehicle outright the row was the weaker half of a choice that
is supposed to be even — and one civilian is now the whole of what a town gives that player.

The one asymmetry that has to go with them is the despawn. The medikit is deleted after 60 s
(`fnc_civ_askForAid_server.sqf:51-55`) and the toolkit is not (`fnc_civ_askForToolkit_server.sqf:55-57`),
which under equal cost and equal odds would make aid simply the worse of two equals. Both carry
the 60 s window: the item is handed over to be picked up, not left as a supply dump, and a
persistent toolkit lets one friendly town furnish a squad's repairs for the rest of the campaign.

### Arrest

The row orders hands up and nothing else. It rolls no reaction, takes no bribe, and is available
on a closed civilian: a town's opinion does not change whether a person raises their hands, and
refusing to talk is not protection from being detained.

**One attempt per civilian, spent on the attempt.** Today the scroll action removes itself when
clicked (`fnc_civ_lootAction.sqf:78`), so the 10 % that ends in the civilian running cannot be
retried. A dialog row has no equivalent — it is redrawn every open — so the flag has to carry
that, on the attempt rather than the outcome, the same rule and for the same reason as the body
search (`server/misc/fnc_intel_search.sqf:8-12`). Without it the row is a button the player holds
until the 90 % lands, and the reputation hit and the runner both become free.

**The row is red**, which is what the hands-up action already renders as
(`fnc_civ_lootAction.sqf:29`), and it names what the player is doing. *Loot* described the second
step and let the first hide behind it.

**The body search stays a scroll action** and keeps its orange (`fnc_civ_lootAction.sqf:100`). It
is gated on `isSurrendered` at 3 m, on a civilian now standing still with their hands up — the
menu that opens at arrest range would have to close, wait for the animation and reopen to offer
it, and that is a dialog imitating a hold action. The surrender and reprisal rolls behind both
steps are untouched.

**The action wipes go.** Hands-up clears every action on the civilian on every machine
(`fnc_civ_lootAction.sqf:37-38`, `:97`) because it was competing with five other scroll actions.
With one menu action those wipes delete the entry point, and the JIP `remoteExec` that added it
has already fired, so nothing puts it back. They are deleted rather than worked around: the menu
action's own condition already excludes a surrendered civilian, which is the only exclusion the
wipes were buying.

### What a bribe costs

Per row, and **not** scaled by reputation — the curve already carries that signal by deciding
whether money is asked for at all, so a reputation term in the amount would count it twice.

| Row | Bribe |
|---|---:|
| Intel | 3 |
| Recruit | 2 |
| Aid | 2 |
| Toolkit | 2 |
| Arrest | — |

**These are placeholders chosen to make the framework testable, not balanced figures.** They
are anchored on the black market, which is the price scale the player already reads — goggles
at 1, pistol and optic at 5 — so intel sits between the two and recruit keeps the cost it has
today. Intel is deliberately *not* inheriting the old ask-enemy price of 1: that bought a marker
on a group within 700 m, inside spotting range, whereas the row now draws from the campaign-wide
payout pool.

Aid and toolkit are flat at 2, which is the toolkit's old price rather than aid's. Aid was
the cheaper of the two only because it was also the one that despawned, and that asymmetry is
gone — pricing the pair at the survivor's figure keeps a medikit from being the cheapest thing a
town can be asked for.

**Expect the coin drain to fall against today's.** Every current action charges every time; here
a bribe is asked roughly half the time at a neutral town and one time in ten at a friendly one.
That is the discount for carrying refusal risk and for having earned the town's standing, and it
pushes coins toward the black market and partisans, which are the underused sinks.

## Open questions

- Balancing the bribe figures once the framework runs. The values above exist to make it
  testable. What is not measured is the coin supply they meet: the HQ crate hands out 20 once
  and never refills, and enemy infantry drop **0.267 coins each** (80 % carry loot,
  `floor random 3` items, one class in three) — so a thirty-enemy zone assault yields about
  eight coins. Whether that pays for a campaign of talking to towns is the first thing to watch.
