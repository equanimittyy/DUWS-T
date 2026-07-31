# Economy: command points and army power

Two currencies, one job each, and the split is what makes either legible.

- **Command Points are throughput.** What the player can put and keep in the field right now.
  Held by the player alone — there is no OPFOR CP anywhere in the mission. Abundant by design:
  CP must never be the reason a decision is impossible, only the reason every decision is not
  possible at once.
- **Army Power is authority.** What either side may field at all. Held by both sides, scarce on
  both, and the only place in the economy where scarcity lives.

Two tests follow, and every price below answers to one of them. If a CP price blocks the player
for more than a few minutes of play, it is wrong. If one action pays for an AP price outright,
the faucet is wrong.

Where the shipped CP economy is documented — pools, writers, faucets, the purchase handshake —
see [`info/economy.md`](info/economy.md). This plan covers what changes.

## The integer contract

**No fractional value reaches a pool writer.** Rounding happens once, where a figure is derived,
and the derived integer is what gets stored, passed and paid. Writers assert rather than repair,
because a writer that repairs makes the same delta worth different amounts depending on what the
pool already holds.

Most of the tree already holds this, which is why the constraint is cheap:

| Figure | Derived at | Integer by |
|---|---|---|
| Zone worth | `server/init_zones/fnc_locatorzones_random.sqf:49` | `round (radius / 10)` |
| Zone bounty | generation, from worth × `zone_cp_capture` | rounded at generation |
| Bounty decay | `fnc_captured.sqf:70`, `fnc_blufor_cap.sqf:69` | `round (_bounty * zone_cp_recapture)` |
| AP swing | `fnc_captured.sqf:39`, `fnc_blufor_cap.sqf:31`, `fnc_opfor_cap.sqf:34` | `round (_points * zone_ap_swing)` |
| Escalation-scaled price | `fnc_escalation_cost` | `ceil` |
| Mission CP reward | `server/missions/fnc_mission_reward.sqf:14` | multiplier is 1-5, whole |
| Town income | `civ_town_ap` | authored 1-3 |

**The one gap is `fnc_ap_adjust`.** `fnc_cp_adjust` rounds the running total and logs a `WARN` on
a fractional delta; `fnc_ap_adjust` adds and floors at 0 with no rounding anywhere
(`server/misc/fnc_economy_init.sqf`). Nothing feeds it a fraction today, so it is latent — and it
stops being latent the moment AP becomes a priced currency, because every ladder gate reads
`> N`. A pool resting at 39.97 fails a `>40` gate while a rounded readout prints 40, and the
player has no way to tell why. `fnc_ap_adjust` takes the CP writer's invariant verbatim.

The two new multipliers below therefore round at their application site, never at the writer.

Reputation is the deliberate exception and is not a pool in this sense: it is the only figure
taking fractional deltas, and `fnc_town_rep_adjust` owns its rounding for the reason recorded in
[`info/economy.md`](info/economy.md#authority-one-server-side-writer-per-pool).

## Command Points

### The pool is shared, so abundance is a requirement

`commandpointsblu1` is one pool spent by every slot in `Squad_Leaders`
(`server/server_var_init.sqf:225-258`), which as shipped is every playable slot. Four squad leads
drawing on one wallet is why CP has to sit in relative abundance: a scarce shared pool means the
first player to open a request menu spends the team's afternoon.

That is a design constraint, not a nicety, and it is why the answer to "make CP matter" is never
"make CP scarce".

### The drain moves to use, not to price

Income needs no change. Passive hold alone pays `zoneundercontrolblu * 6` every 30 minutes with
no upkeep (`server/misc/fnc_zonesundercontrol.sqf:51-54`), against eight permanent unlocks at
5-25 CP — roughly 200 CP across an entire campaign. A one-time unlock cost cannot absorb a
recurring faucet at any price, and raising the shopping list only postpones the same problem.

**So the unlock buys the right to call a support, and each call costs CP.**

| Layer | Pays | When | Starting values |
|---|---|---|---|
| Unlock — consumes one of eight slots | CP, plus AP if advanced | once | 5-10 CP regular; 15-25 CP + 20-40 AP advanced |
| Each call | CP | every use | 3-8 CP regular; 10-25 CP advanced |

Several comm-menu supports already pass `_cost = 0` at use time because the charge happened at
unlock (`client/dialog/fnc_MHQ_select.sqf`, both taxis in `supports/taxi/`), so this is a value
change at sites that already route through the spend handshake rather than new plumbing. It gives
CP a recurring, activity-scaled drain that tracks how much the player is fighting rather than how
much they own, and it needs no new state.

Two things fall out. The eight-slot cap starts reading correctly — the slot is the right to call
it, the CP is the call. And escalation gets something to bite: `escalation_multiplier` scales CP
prices, which is nearly inert against one-time unlocks in an abundant pool, but against a
per-use cost a late-campaign CAS run visibly costs double.

**Upkeep was the alternative and is rejected.** A recurring cost per squad, vehicle or holding
needs new state, has no good failure behaviour when a co-op team cannot pay, and taxes owning
things in a mission that is about doing things. Metering use rather than ownership gets the same
pressure from the machinery already in the tree.

### Intel analysis is capped per tick

`server/misc/fnc_intelAnalysis.sqf` converts loot to CP with no cap and no cooldown, against
`fnc_addRandomLoot.sqf` putting items on roughly 80% of spawned enemies. It is the one faucet
scaling with playtime rather than with anything the player achieved, which is what turns
"abundant" into "meaningless". The cap keys off `econ_tick`, which exists for exactly this and
already has one caller in `fnc_civ_healed.sqf`.

### The AP-to-CP converter is deleted

`client/dialog/fnc_convertAPtoCP.sqf` trades 15 AP for 10 CP, repeatable, no cooldown. Selling
the scarce currency for the abundant one is strictly wrong under this split, and with the
player's AP now buying supports and garrisons it competes with both. A CP-to-AP path must never
exist in either direction, or the abundant pool launders into the scarce one and the split
collapses.

### The eight slots

The budget is `support_max_slots` (8) consumable supports per player, and which rows draw on it is
now the catalogue's `PERM`/`CONS` column rather than a per-case habit — see
[`info/economy.md`](info/economy.md#supports-permanent-and-consumable). Mobile HQ's half-in state,
where it tested the cap without ever consuming one, was resolved by making it permanent.

**Advanced supports draw on the same slots.** A second currency that bought its own would raise the
campaign-long budget while appearing to be bookkeeping, and the cap would stop meaning anything the
moment AP could bypass it.

### Refunding the slate

Eight permanent slots against seventeen competing rows means a player commits at hour one to a
shape they cannot evaluate until hour six. The refund is the escape hatch, and its CP half is
built: [`info/economy.md`](info/economy.md#supports-permanent-and-consumable) has the mechanism,
including why it pays back the recorded charge rather than the price and why a support that is away
on a mission cannot be sold.

Two things this plan asked for came out differently, and both are better. The refund is
**per support** rather than a wholesale reset of the slate, because a slate you re-cut one row at a
time is a loadout selector in the useful sense rather than an all-or-nothing button. And it needs no
place gate of its own: the support list only exists inside the request menu, which only opens at HQ
or a FOB, so the trip is already the price.

What is left for AP is the second currency, not the mechanism. When a support costs both pools the
ledger has to record both charges and the refund has to return both; today it records one number per
support because there is one pool to record.

## Army Power

### The ladder input is not the wallet

AP does two jobs, and the shipped arrangement makes them fight for the same points. A ratchet fed
by a spendable pool reads its **high-water mark**, and a high-water mark is not lifetime income:
a player who spends as they earn oscillates in a low band and never crosses a rung, however much
they have earned in total. The player this punishes hardest is the one who uses AP for what it
exists to buy.

It also has a known-correct answer — bank just past a rung, then spend down — and a decision with
a known-correct answer is a chore the player performs rather than a choice they make.

**Both sides therefore split the two**, and the symmetry is what makes the ladder tunable at all.

| Side | Wallet | Ladder input | Tier |
|---|---|---|---|
| BLUFOR | `WARCOM_blufor_ap` | `WARCOM_blufor_ap_earned` | `WARCOM_blufor_tier` |
| OPFOR | `WARCOM_opfor_ap` | `WARCOM_opfor_ap_earned` | `WARCOM_opfor_tier` |

A wallet moves both ways; an earned counter and a tier only ever rise. A tier is reached by having
*earned* that total, whatever was spent since, so the wallet and the ladder can be sized
independently on both sides — raise a support's price without pushing the ladder out, lower a rung
without making supports free, and set the enemy's escalation pace without reference to how much it
happens to be buying.

The read surface is small: `server/warcom/fnc_WARCOM_blu_assault.sqf:11-25` and
`fnc_WARCOM_blu_patrol.sqf:11-20,92,96,100` on the player's side, and the OPFOR sites in
[§The enemy ceiling](#the-enemy-ceiling-is-199-not-136).

**A shared pool would make the enemy's two jobs fight each other.** The commander's sinks can
absorb more per hour than its income supplies — a build tick and a squad-tasking rate that
together outrun town income and the flat floor — so a commander that buys whenever it can holds
its balance near zero, and under a high-water ladder that is an enemy which never escalates at
all, however long the campaign runs. The alternative is a commander that hoards to climb and
therefore never buys anything, which empties the map of the pressure the sinks exist to create.
There is no rate that gets both out of one number; splitting them is what lets the enemy spend
continuously *and* harden over time.

**The earned counters credit ground gained, never ground regained.** The wallet's anti-farm
invariant is the `- swing` on a lost zone, which makes lose-then-retake net exactly zero. A
monotonic counter has no such protection, so crediting a re-take would let a zone flipped back and
forth pump a tier that can never come down. On the player's side that means `fnc_captured.sqf`
credits and `fnc_blufor_cap.sqf` does not. On the enemy's side the same rule needs no test at all:
every zone OPFOR takes is one the player took from it first, so `fnc_opfor_cap.sqf` credits the
wallet and never the counter. The two ladders therefore ride the recurring faucets — towns, the
flat income, missions — which are the ones the player can actually contest.

This is the same split the CP bounty already makes by decaying on recapture, and nothing enforces
it structurally on either side.

`fnc_ap_adjust` stays the sole writer and owns both counters, so the integer invariant and the log
stay in one place. Each counter is a running sum of already-rounded positive deltas and is
integer by construction.

### The ratchet is otherwise structural, and only in half the read sites

The wave-composition threads already ratchet: each is a `spawn`ed thread walking forward through
`waitUntil` gates, so once it passes a threshold it never re-tests it. A pool drained back below
100 leaves the thread where it got to.

The eight sites that read the pool live, once per spawn, would silently downgrade the moment
anything spends:

| Site | Gate | What is lost |
|---|---|---|
| `fnc_WARCOM_blu_patrol.sqf:92,96,100` | > 99 / > 149 / > 199 | The three vehicle steps, BLUFOR side |
| `fnc_missionPatrols.sqf:20` | > 100 | Mission guard armour drops to a car |
| `fnc_missionPatrolswithintel.sqf:14` | > 100 | Same |

These read the tier, not the pool. A player who watches their own patrols lose armour because
they bought a support is being shown an unlock that un-unlocked, which contradicts the one rule
the ladder has.

The tier globals are also save state. A reload restoring the pools but not the tiers would
re-derive them from a pool that has since been spent down, silently downgrading an enemy that had
already unlocked armour. A ratchet whose only record is a number that goes both ways is not a
ratchet.

### The starting-AP presets become the ladder's own rungs, plus zero

Each side's opening pool is picked from seven options — 10, 50, 80, 110, 150, 170, 200
(`client/dialog/fnc_process_campaign_menu.sqf:278-308,319-349`) — none of which except 10 and 150
lands on a threshold, so the preset sets a position part-way between tiers and the host cannot
tell which one they picked. Replacing them with `0, 10, 40, 65, 100, 136, 150` is the same seven
options expressed as "start at this tier", and it is exact: those are the wave rungs plus OPFOR
air.

Zero is the genuinely new option, and it matters more under a spendable pool: a 200 AP start
hands a side several permanent purchases before the first shot. Zero is what a campaign that
wants both economies earned from nothing selects.

**A preset seeds the earned counter as well as the wallet**, or "start at tier 4" would hand a
side a wallet at tier 0 and the option would stop meaning what it says.

The seven values are *derived* from the thresholds, not chosen alongside them. If the ladder is
retuned, the presets are regenerated from the new rungs rather than re-picked — a preset that no
longer lands on a threshold has silently gone back to meaning nothing.

### Where BLUFOR army power comes from

Sized against the sinks, since the ladder no longer competes for the same points. A campaign
should fund roughly four advanced unlocks, eight combat vehicles and garrisons on a couple of
towns — about 300 AP of spending — so lifetime earn lands near 340 on a default six-zone campaign
(`server/server_var_init.sqf:292`).

| Faucet | Rule | Per event | Share |
|---|---|---|---|
| Town income | banded town, per 30-minute tick | 1-3 | ~60% |
| Side mission | `round (base * ap_reward_multiplier)`, base 5-45 | 2-14 | ~25% |
| Zone capture | `round (worth * zone_ap_swing)` | 3-15 | ~15% |
| Corpse search | flat | 1 | remainder |

**Two constants do the whole deflation**, against a shipped economy paying roughly twice the top
rung in the first hour:

- `zone_ap_swing` (`server/server_var_init.sqf:96`) drops from 0.5 to **0.15**. A capture stays a
  windfall and stops being a substitute for holding ground.
- **`ap_reward_multiplier`** is new, starts at **0.3**, and is applied in
  `server/missions/fnc_mission_reward.sqf:19` beside the CP one. Side missions currently pay 5-45
  AP each across 17 mission types, which outpays a banded town by roughly ten to one per event —
  they were the dominant faucet and no plan said so.

A multiplier rather than a sweep of the 17 mission threads, because this is the knob that gets
turned between play-tests and re-authoring 17 literals each time is how a table goes stale.

Two consequences to accept rather than discover. A 200 m zone now pays 3 AP, so small zones are
AP-irrelevant and their reward is the CP bounty; that is the intended ordering, not a rounding
artefact. And the lose-then-retake invariant survives the change untouched, because all three
capture paths use the identical `round (_points * zone_ap_swing)` expression against the same
worth — which is also why the swing must never be derived from the bounty, since the bounty
decays.

**The shares above hold at `time_Multiplier = 1` and nowhere else.** The two faucets are on
different clocks. Town income rides the economy tick's `sleep 1800`, which sits on `time` and is
not scaled by `setTimeMultiplier`; side-mission cooldowns are stamped against `dateToNumber date`,
which is scaled by it
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).
The host picks 1, 2, 4, 8, 16, 24, 32 or 60 from the environment menu
(`client/dialog/fnc_process_enviro_menu.sqf:99-106`), so at 32x a mission type comes off a
three-in-game-hour cooldown every five and a half real minutes while towns keep paying at an
unchanged real rate. Missions then supply almost all of the player's AP and the ordering this
plan is built on inverts.

Which clock the economy should be paid on is
[open](#open-questions). Every figure in this plan is quoted at 1x until it is answered, so a
number tuned against an accelerated campaign is being tuned against a different economy from the
one written down here.

**BLUFOR gets no flat income.** The player's AP stays entirely earned. A passive trickle would
make the tier gates a matter of waiting rather than of fighting, and it is the earned-only rule
that makes AP feel coveted at all.

### Where OPFOR army power comes from

| Faucet | Amount |
|---|---|
| Town income | banded OPFOR towns, 1-3 each, per 30-minute tick |
| Flat income | one constant per tick, independent of everything |
| Zone retaken | `round (worth * zone_ap_swing)` |

**The consolation goes to zero.** `zone_ap_consolation` paid OPFOR half the swing whenever the
player took a zone, on the reasoning that a losing enemy should not simply stop escalating. With
town income, a flat floor and a swing of its own for retaking, the enemy has enough routes in
without also being paid for the player's successes — and being paid for them is the least legible
of the four, since it is the one the player cannot see or influence.

**The flat income is a floor, not the main faucet.** A town whose radius reaches into an enemy
zone starts at `-20` (`server/misc/fnc_civ_init_Tomata.sqf:200-210`), so the enemy opens with
several towns already banded and already paying — OPFOR town income outweighs any sensible flat
constant several times over at hour zero. The constant is sized for a director holding nothing,
and the figure that has to be checked is the combined one.

**Held ground pays neither side AP.** The obvious version of this design — territory pays AP the
way it pays CP — spirals structurally rather than as a matter of rate. The enemy holds the entire
map at hour zero, so a holdings-scaled faucet pays it most when it has earned least; the ladder
is a one-way ratchet, so that front-loaded income lets the enemy bank the ceiling during its
strongest hours and keep it after being reduced to its last zone; and `zones_number` runs from 1
to 40 while the thresholds are constants, so a large campaign would climb forty times faster than
a small one and every threshold in the mission would mean something different depending on a
number chosen before play.

### The enemy ceiling is 100, and one gate stands behind it

The WARCOM patrol, assault and air spawners are gone, and they held every OPFOR rung above the
first. What is left reading the enemy pool is a single gate:

| Gate | Site | Buys |
|---|---|---|
| 100 | `fnc_missionPatrols.sqf:20`, `fnc_missionPatrolswithintel.sqf:14` | Mission-guard armour instead of a car |

So enemy AP is currently a number that fills and buys almost nothing, and the ladder is the OPFOR
commander's to rebuild rather than something to balance against as it stands. Any figure below on
what enemy income *should* pace is written against that commander existing.

**Town income alone will reach any ceiling put back.** Every town whose radius overlaps an enemy
zone starts at `-20` (`server/misc/fnc_civ_init_Tomata.sqf:199-201`), the deepest band, so the enemy
opens with its zone-adjacent towns already paying. Six such towns at 2 AP each is 12 a tick, which
crosses 200 in roughly seventeen ticks without a flat income existing at all. The flat constant is
therefore insurance for a director that has lost its towns, not the faucet that sets the pace.

**The player's lever on escalation is the enemy's income, not its balance.** A player-facing debit
is rejected — it lets the player attack a number rather than the war, and the number is the one
thing on the enemy's side they cannot see. Under split counters, destroying what the enemy bought
no longer slows its climb either: the tier rides gross income, so a cleared garrison costs the
enemy the asset and the AP to replace it, and nothing else.

What remains is better than what it replaces. Town income is the enemy's largest faucet by some
distance, and dragging a town out of the OPFOR band cuts it at the source — permanently, visibly,
through a system the player is already working in. Escalation therefore slows for a reason the
player can see on the map, rather than as an invisible side effect of the enemy's accounting.

Flat income and the retake swing are the two the player cannot touch, which is what stops
suppression from becoming a freeze.

### What army power buys is permanent

CP buys a delivery, a vehicle, a squad — things that are spent or destroyed. **AP buys something
the player still has an hour later.** That is what makes the choice of what to buy weighty rather
than merely expensive.

The mission already implements this shape for radio supports, so an AP support is the same code
with a different pool: each case in `client/dialog/fnc_request_support.sqf` tests its own
`support_*_available` flag, spends once, and adds a comm-menu item.

The eight-slot cap makes an AP purchase exclusive as well as permanent. Permanent *and* capped
means spending AP on the wrong support is a misallocation the player lives with for the campaign,
and it costs nothing to get because the cap already exists.

**Two exceptions, both of which have to be legible.** A town garrison is bought with AP and can be
cleared, so it is a risked investment where a support unlock is not. And a tier is not bought at
all: it is reached, which makes it permanent by construction rather than by rule.

**Permanence depends on work that is not built yet.** Support unlocks are client-local with no
server-side record of what the team owns, so today a permanent unlock survives neither a reload
nor a reconnect. That is tolerable for a 5 CP supply drop and is not tolerable for the most
coveted resource in the campaign.

### Civilians off costs BLUFOR its primary faucet

Three configurations pay no town income: `CIV_PRESENCE` of `NONE`, `RAVAGE` or `WBK`. Civs-off
leaves the town arrays empty (`server/misc/fnc_zonesundercontrol.sqf:29-39`); the two mode
campaigns register no town reputation at all, so every town sits permanently neutral and
`fnc_civ_townIncome` (`server/misc/fnc_civ_state_init.sqf`) pays nobody. The loss is one-sided —
OPFOR's flat income is untouched by the setting. Turning civilians off should be a presentation
choice; it must not quietly be a difficulty setting.

Making towns 60% of the player's AP makes that gap load-bearing, so it closes here:

- **`ap_reward_multiplier` goes to 1.0 when `civ_town_rep` is empty.** Side missions exist in
  every configuration, so the substitute rides a faucet that is already there.
- **Gate on the faucet being absent, not on the mode being named.** One condition covers all three
  configurations, and a fourth mode added later inherits it instead of being forgotten.
- **BLUFOR only.** OPFOR loses nothing it depends on, so a symmetric substitute would preserve
  exactly the gap it exists to close.

A flat BLUFOR trickle was the alternative and is rejected: it contradicts the earned-only rule
directly, and the rate could not be settled on paper — set at what a well-played civs-on campaign
yields, civs-off becomes the AP-optimal way to play. Routing the substitute through missions
keeps it earned and needs no new number.

## Prices

### Two tiers, one price format

| Tier | Pays | Examples |
|---|---|---|
| Regular support | CP only | UAV recon, supply drop, taxis, paradrop |
| Advanced support | CP **and** AP | Artillery, mortar, cluster, napalm, attack helicopter, CAS |
| Utility vehicle | CP only | Unarmed cars, transport trucks, boats, transport helicopters |
| Combat vehicle | CP **and** AP | Tanks, tracked APCs, armed helicopters, artillery pieces |

**Both halves are charged.** An AP-only price for the top of the catalogue was rejected: it leaves
CP with nothing expensive to buy, and it makes the player learn two price formats instead of one.

Under an abundant CP pool the AP half is what actually decides an advanced purchase, and the CP
half is close to a rounding error. The dual price is therefore carried for legibility — one price
format across the whole catalogue — rather than as a second constraint. Saying so is what stops
someone later tuning the CP half as though it were load-bearing.

**Escalation scales the CP half only.** `fnc_pool_try_spend` applies `fnc_escalation_cost` on
entry to whatever it is given; the AP component opts out. CP is the player's own purchasing power,
so a hardening enemy making the shopping list dearer is what escalation models — and AP purchases
are permanent, so scaling them would make buying early strictly better than buying well, which is
the opposite of a decision worth having. Taking AP out of escalation also removes the accidental
`ceil` that was keeping AP prices whole, which is why the integer contract above has to be
explicit.

### The dual price needs an atomic handshake

`fnc_pool_spend` takes one pool per call. Charging CP and then AP as two sequential calls is not
one purchase: the first can succeed and the second fail, leaving the player charged for nothing,
and in co-op another player's spend can land between them. That is the same race the single-pool
handshake was written to close
([`info/economy.md`](info/economy.md#authority-the-server-decides-a-purchase-not-the-buyer)),
reopened one level up.

`fnc_pool_try_spend` gains a dual case that tests both pools and debits both as adjacent
statements against the one server copy, replying with a single verdict. Partial success must be
impossible rather than merely unlikely.

### The two label formats are opposites

| Catalogue | Label built | Consequence |
|---|---|---|
| Vehicles | At runtime, `_typeDisplayName + ' (' + str(_typeCost) + 'CP)'` (`shared/factions/MODERN/AUTODETECT_blufor.sqf:223`) | English-only, generated. Free to reformat into a dual price |
| Supports | Baked into stringtable text across five languages | The AP figure must be **appended**, never substituted |

The support constraint already forced escalation to append its surcharge rather than rewrite the
row (`client/dialog/fnc_request_menu.sqf`): a `%1` placeholder added to English but not to the
other four languages leaves them printing a stale baked number, which is a wrong figure rather
than an untranslated one. A dual price inherits that exactly, and so does a per-use price.

### Vehicles split on a classifier that already exists

`shared/factions/MODERN/AUTODETECT_blufor.sqf:35` unpacks 26 categorised arrays from
`fnc_parseFaction` — `_tank`, `_apcTracked`, `_apcWheeled`, `_carArmed`, `_carTransport`,
`_heliArmed`, `_heliTransport`, `_arty`, `_antiAir` among them — and `:195-215` flatten every one
of them into a single `requestAssets` list, discarding the category one line later.

The split is a test against arrays that already exist at build time, not a new taxonomy and not a
per-classname table maintained against every faction mod on the Workshop. Keeping it derived from
`fnc_parseFaction` is what preserves faction auto-detection: a hand-authored list of tank
classnames would silently mis-price any mod the list has not heard of.

The cost figure stays `fnc_evalVehicleCost`, which already reads armour, threat and type
multipliers from config. What changes is which pool it draws from and what the AP component
alongside it is.

## The OPFOR commander

One actor, one pool, one archetype. The director in this document, the director that builds
hardpoints in [`hardpoint_system_plan.md`](hardpoint_system_plan.md) and the commander that makes
low-reputation towns fight back in [`opfor_commander_plan.md`](opfor_commander_plan.md) are the
same thing under three names, and they share `WARCOM_opfor_ap`. How that one actor decides — what
it wakes on, what it is allowed to know, and how it ranks targets — is
[`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md); this section is its shopping list.

Director spends call `fnc_ap_adjust` directly, as `["OPF", -_cost, _reason] call fnc_ap_adjust`.
There is no second writer to race — the director is server-side and single — so the purchase
handshake would only add a frame boundary between its test and its debit.

### What the commander spends on

| Sink | Effect | Throttled by | Saturates? |
|---|---|---|---|
| Town garrison upgrade | Raises the purchased tier of one town | Tier ceiling of IV times the towns in the OPFOR band | Yes |
| Tasking order | Gives a newly spawned squad a job | The rate squads spawn at | No |
| Hardpoint construction | Builds an emplacement | One build attempt every 20-30 min | No, but capped at one purchase per tick |

**Town events are not a sink.** IEDs, ambushes and sabotage out of a low-reputation town fire on
their own, rolled against the town's reputation, and cost the commander nothing
([`opfor_commander_plan.md`](opfor_commander_plan.md)). Reputation is already the input that
decides whether a town garrisons and what it pays, so making the same towns also *charge* for
acting on it would price a thing the player has already paid for by letting the town fall. Stated
here because the shape invites the opposite: a free enemy behaviour sitting next to three
purchased ones reads like an omission until the reason is written down.

The consequence is a deliberate double dividend on a turned town — it pays the enemy AP and acts
against the player for free — and that is what makes dragging a town back out of the OPFOR band
the player's sharpest move.

**Every remaining sink is rate-limited, and none of them absorbs a surplus.** Garrisons saturate
outright at tier IV across the towns in the band; the other two are throttled by a build tick and
by how fast squads spawn, so neither can be bought faster than its clock allows however rich the
commander is. A commander that out-earns all three banks the difference.

Under split counters that costs the campaign nothing directly — the ladder rides income, so
banking neither accelerates nor stalls escalation. What it costs is felt: an enemy sitting on an
unspent wallet is one that has quietly stopped pressuring anybody. What the commander should do
with a surplus is unsettled, and it is in [§Open questions](#open-questions) rather than answered
here.

A tasking order is bought for a squad the director is spawning anyway, so the price buys *intent*,
not units:

| Tasking | Job |
|---|---|
| QRF | Respond to contact, under a commander that decides whether to spend the reserve rather than a handler that always does |
| Supply | Move between held towns and zones, restoring garrison strength en route |
| Rapport | Occupy a town and drag its reputation toward OPFOR |
| Intel patrol | Sweep for BLUFOR and report what it finds, feeding target selection |

The intel patrol is deliberately the weak one — a cheap tasking that buys knowledge rather than
force, and unlike the other three it goes looking for the player instead of circulating around
what the enemy already holds. `reveal` against EAST is the mechanism.

**Rapport owns dragging a town toward OPFOR; the town-event sink does not.** Both act on a town in
the OPFOR band and the division has to be stated or they will drift into each other: rapport moves
reputation, events spend the reputation a town already has. Today a town only moves toward OPFOR
through the player's own mistakes, and rapport is what makes the town economy two-sided.

### The commander has an archetype

One archetype is rolled per campaign and decides how the director splits its income across the
sinks above. Two campaigns on the same map with the same settings should not produce the same war.

| Archetype | Spends toward |
|---|---|
| Defensive | Town garrisons and hardpoints; fortifies what it holds and cedes initiative |
| Balanced | No strong lean — the baseline the others are tuned against |
| Aggressive | Taskings, especially QRF and rapport; projects force and leaves its ground thin |

A single authored list rather than a second independent roll on top: each archetype can then be
tuned and named as a whole, where a second roll multiplies out combinations nobody has balanced.
Further leans worth having — indirect fire, armour — become entries in this list.

Three properties keep it from becoming a problem:

- **Weights, not switches.** An archetype biases the roll; it never removes a sink. A Defensive
  commander that could not order QRF would hand the player a permanent read on the campaign and
  delete a mechanic from it. `selectRandomWeighted` is the mission's idiom for exactly this.
- **It cannot override the ladder.** An Aggressive commander with no armour tier reached still
  fields no armour. Archetype decides what the enemy buys, never what it may buy, so the tier
  gates stay the one honest signal of how dangerous the enemy is.
- **It is not difficulty.** `opfor_ai_skill` already sets how well the enemy shoots. A Defensive
  commander is not an easier one — it is a slower, more fortified campaign.

Rolled once at WARCOM init and never re-rolled, so it is campaign state and belongs in the
persistence snapshot alongside the tiers.

Because each sink is throttled differently, no archetype reliably outspends another, and each has
its own way of running out of things to buy — a Defensive commander whose towns are all at IV is
left with the build tick alone, an Aggressive one facing a quiet player has no squads to task.
Whichever runs dry first banks the surplus, which is the same open question by another route:
archetype decides *where* the money goes, not whether there is anywhere for it to go.

### Town garrisons: I through IV

Towns gain purchasable garrisons on both sides. A zone garrison is the benchmark the ladder climbs
toward: `server/init_zones/fnc_createopfortified.sqf` fields a multiplied fortified group with a
squad leader, a mortar team, and up to eight buildings occupied at three units each. **Zone
garrisons are tier IV by definition and are not purchased** — they are what a zone already is, and
nothing about zone generation changes.

Today a town garrison is OPFOR-only and its tier comes from reputation alone: tier 1 at `-10`,
2 at `-15`, 3 at `-20` (`server/misc/fnc_civ_garrison.sqf:72-74`, band contract in
[`info/zones_and_civilians.md`](info/zones_and_civilians.md#ownership-bands-and-the-garrison)).

- **Reputation still decides *whether* a town garrisons; AP decides *how hard*.** The band is the
  trigger and stays untouched, so the existing contract — clear the garrison, reputation resets to
  0, the garrison stops — survives intact.
- **Effective tier is the higher of the reputation tier and the purchased tier**, so a town ruined
  to `-20` is never made weaker by the arithmetic.
- **Clearing a town destroys the purchase.** No refund, and the director must spend again to
  restore it. With a refund, a player clearing towns would hand the enemy its AP back and the
  enemy would never climb; with a purchase that survives clearing, clearing stops meaning
  anything.
- **Tier IV is more units, not fortifications.** Static emplacements are what make a zone an
  objective and a town must not compete with one, so IV reaches the zone benchmark by occupying
  buildings.

| Tier | Adds | Reputation reaches it at | Starting price |
|---|---|---|---|
| I | Patrol plus one team | `-10` | 15 |
| II | Second team, light vehicle | `-15` | 25 |
| III | Armour | `-20` | 40 |
| IV | Building-occupying units, on the zone pattern | never — purchase only | 60 |

BLUFOR garrisons are new ground: the BLUFOR band (`>= 10`) has no garrison today, so a player
buying tier I at a town they hold is creating something that has never existed rather than
upgrading something that has. It is the player's answer to the enemy taking towns back.

## Spending authority

`fnc_cp_adjust` and `fnc_ap_adjust` stay the sole writers of their pools. Player spends go through
the purchase handshake — a client testing its own copy of a networked pool is a round trip out of
date, so two co-op players can both pass one gate.

**Who may spend AP is unsettled, and the leaning is toward `game_master`.** Both pools are shared,
any squad lead can spend them today, and permanence means a bad AP purchase cannot be worked off
the way a wasted CP one can. Moving the support call to `game_master` alone — which already owns
campaign-level control and reads naturally as the BLUFOR commander — makes one player answerable
for the campaign's premium currency rather than making every squad lead trustworthy. That is a
role decision as much as a permissions one, and in a two-player session it may just mean one of
them cannot buy.

## Reading the war from the map

**AP needs a live readout, which it has never had.** `fnc_ap_adjust` broadcasts the pool but
refreshes no control, and there is no `publicVariableEventHandler` for either pool. Three dialogs
read AP at open time (`client/dialog/fnc_request_menu.sqf` for both the HQ and FOB forms, and
`fnc_convertAPtoCP.sqf`) and none updates afterwards. A stale counter was cosmetic when AP was a
score; it is a purchase made on wrong information once AP is a currency, and worse in co-op, where
someone else's spend is exactly what the reader cannot see.

The map view is where that goes. Both pools are `publicVariable`d, so the client's copies are
current and the readout can print them directly with no round trip — and a readout the player
opens is read at the moment they are deciding, where a dialog control left open is not. The wallet
and the tier are both printed: the pool figure alone stops describing capability the moment
spending starts.

Garrison levels belong in the same click readout rather than on the markers. Nothing is added to
the map itself: the player clicks a town and the popup that already answers gains a line.
`client/misc/fnc_map_readout_open.sqf` claims map clicks, each click goes to
`fnc_map_readout_query` on the server, and `fnc_map_readout_draw` draws the answer — a garrison
level is one more field on the tuple those two pass.

The lookup stays server-side because `civ_locations`, `civ_radii` and `civ_town_rep` are none of
them broadcast, so this costs no new networked state. Reveal gating is already correct: an
unrevealed town answers as empty ground rather than as a hit the readout declines to describe, so
the map cannot be swept for towns the presence trigger is hiding.

**Nothing records a garrison tier today**, which is why the readout cannot lead. In
`server/misc/fnc_civ_garrison.sqf:72-74` the tier is a local, computed inside the spawn branch and
discarded. Making it per-town state belongs to the garrison work, which has to record it either
way; the readout is a consumer and follows it.

### SITREP becomes free

It costs 1 CP today (`server/supports/fnc_sitrep_support.sqf`) and reports what the player can
already work out — more so once the map carries the same figures. The stronger argument is that
SITREP is the only save in the mission: it is the sole caller of `fnc_autoSave`, so the 1 CP is a
charge for saving the game, and a player who has spent down to nothing cannot save at all.

**The cost is also the only throttle**, since there is no cooldown on the support. Removing the
price without adding one leaves `saveGame` spammable, and a save is a real frame hitch. The
cooldown replaces the price; it does not accompany it.

## The unlock state model has to be settled first

The mixed locality that blocked this is now named rather than incidental. A permanent unlock is
team state, broadcast, and mirrored on the server in `DUWS_support_permanent`; a consumable is the
buyer's alone and is deliberately not broadcast, because it dies with its buyer. `support_count` is
still per-client, and that is now correct rather than a gap — it counts one player's slate.

One thing the flags rest on is still unverified: defaulting behind `isNil` preserves a broadcast
value only if `publicVariable` values are delivered to joining clients at all, which is an open
engine question in [`KNOWN_ISSUES.md`](../KNOWN_ISSUES.md). If they are not, the defaults preserve
nothing and the team can still be charged twice for the same permanent unlock. The server mirror
does not close that on its own: it records what the team owns, but nothing yet reads it back to a
joining client.

## Build order

Each phase is independently shippable, and the ordering is forced rather than chosen.

| Phase | Contains | Why it is gated here |
|---|---|---|
| **Floor** | `fnc_ap_adjust` integer invariant; both earned counters and both tier globals, seeded by the presets; the eight live pool reads switched to tiers; CP, AP and tier in the map readout; presets regenerated to the rungs | Without the tier globals the first AP spend downgrades that side's own patrols. Without a readout, deciding what to buy is guesswork |
| **Deflation** | `zone_ap_swing` to 0.15; `ap_reward_multiplier` at 0.3, and 1.0 with no town reputation; `zone_ap_consolation` to 0; the OPFOR flat income; delete the AP-to-CP converter | Two constants and a deletion, playable the moment they land. Nothing else matters until AP is scarce |
| **CP becomes a flow** | Per-use CP on supports; the intel-analysis cap | Independent of AP entirely |
| **AP becomes spendable** | The dual case in `fnc_pool_try_spend`; AP halves on advanced supports and combat vehicles; the refund's second currency | The permanent/consumable split and the CP refund are in; what is left is the second pool |
| **The commander** | One director thread, one archetype roll, four sinks; town garrisons I-IV; hardpoints; town events | Everything above is its budget |

## Open questions

- **How long a passive campaign should take to reach maximum enemy capability.** The ceiling is
  199 ([above](#the-enemy-ceiling-is-199-not-136)), the ratchet is one-way, and a director that
  never spends climbs at its whole income. Picking that duration *is* picking the flat income, so
  the constant cannot be set before it.
- **The flat income figure**, which falls out of the answer above once OPFOR town income is
  measured on a real map rather than estimated.
- **Which clock the economy tick runs on.** Town income and territory CP ride `sleep 1800`, which
  `setTimeMultiplier` does not scale; side-mission cooldowns ride the campaign date, which it
  does. The two therefore diverge by exactly the host's multiplier, and at 32x missions supply
  almost all of the player's AP instead of a quarter of it
  ([above](#where-blufor-army-power-comes-from)) — so every share and every constant in this plan
  holds at 1x alone. Moving the tick onto the campaign date makes one clock of the two, at the
  cost of paying territory CP as many times faster as the campaign is running, which is
  proportionate but is not what the tick does today.
- **The AP component of each advanced support and combat vehicle.** The starting values here are
  round numbers against a 300 AP campaign budget; what they should be is a play-test question.
- **Where the boundary falls for armed cars and wheeled APCs.** Tanks and unarmed transport are
  clear; the middle of the catalogue is where a rule stated as "armed costs AP" starts pricing an
  armed offroad like a main battle tank.
- **Whether the support call moves to `game_master` alone**, and what a squad lead sees when it
  does.
- **Whether the player can learn the commander's archetype, and how.** One the player can never
  perceive is variance rather than a mechanic; the intel system is the obvious route
  ([`info/intel_system.md`](info/intel_system.md)), and observed behaviour is the free one.
- **What the commander does with a surplus.** All three sinks are throttled and one saturates
  outright, so a commander that out-earns them banks the difference and the map stops changing.
  Anything that absorbs it has to be something the player still notices — reinforcing a garrison
  rather than upgrading it, or replacing losses, would work without an ever-growing map. Town
  events cannot be it: they are free and rep-driven by decision
  ([above](#what-the-commander-spends-on)).
- **Whether the commander should be required to spend** rather than merely able to. Banking costs
  it nothing now, so nothing pushes it to buy. A forced-spend rule is a policy, though, and
  policies are where AI directors become predictable.
- **Whether flipping towns out of the OPFOR band suppresses escalation too well.** It is now the
  player's whole lever on enemy income, so it wants to work; the question is whether a diligent
  player freezes the war, and only play answers that.
- **Whether anything bought with AP is consumable after all.** The rule admits one exception
  already, and a second would make "AP buys permanence" a guideline rather than something a player
  can rely on when deciding what to spend.
