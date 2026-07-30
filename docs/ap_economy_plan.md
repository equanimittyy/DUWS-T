# Army Power: ladder and currency

Army Power becomes a second currency without ceasing to be the escalation ladder. Both sides
hold a pool, both spend from it, and both read the same thresholds to decide what they may
field. The strategic question the design exists to create is the same for the player and for
the OPFOR director: **spend now to hold what you have, or bank toward the next tier.**

CP stays the standard currency and AP becomes the premium one. Most of what a player buys should
remain purchasable with CP; the supports that decide an engagement sit behind an AP tier. Passive
territory income is unaffected and keeps paying the player CP (`zoneundercontrolblu * 6` every
30 min, `server/misc/fnc_zonesundercontrol.sqf:54-57`). Where the shipped CP economy is documented
— pools, writers, faucets, sinks — see [`info/cp_economy.md`](info/cp_economy.md).

## Where AP comes from, and why OPFOR leads without trying

**Towns are the primary income; captures are a windfall on top.** That ordering is the design, and
it is not what the numbers currently say: a zone's worth is `round(radius/10)`
(`server/init_zones/fnc_locatorzones_random.sqf:56`) and the capture swing is half of it
(`zone_ap_swing`, `server/server_var_init.sqf:102`), so a 500 m zone moves 25 AP, a 1000 m one 50,
and a zone at the 2000 m ceiling 100 — against 1–3 per town per tick. The swing has to come down
far enough that a run of towns outweighs a capture over a campaign. It stays a windfall; it stops
being a substitute for holding ground.

A town pays no lump for entering a band, only its per-tick income. Turning a town is a slow
deliberate act and paying a bonus for it invites oscillating a town across the boundary, which
would need a once-per-town flag to close — a guard, a flag and a farm, in exchange for a moment.

**The consolation goes to zero.** `zone_ap_consolation` paid OPFOR half the swing whenever the
player took a zone, on the reasoning that a losing enemy should not simply stop escalating. With a
flat income, town income and a swing of its own for retaking, the enemy has enough routes in
without also being paid for the player's successes — and being paid for them is the least legible
of the four, since it is the one the player cannot see or influence.

| Faucet | BLUFOR | OPFOR |
|---|---|---|
| Town income, per 30 min (`fnc_zonesundercontrol.sqf:39-46`) | towns at `>= 10` rep, 1-3 each | towns at `<= -10` rep, 1-3 each |
| Flat income, per 30 min | — | one constant, independent of everything |
| Zone captured (`fnc_captured.sqf:39-42`, `fnc_blufor_cap.sqf:31-34`) | + swing | — |
| Zone lost (`fnc_opfor_cap.sqf:34-36`) | − swing | + swing |
| Side mission (`fnc_mission_reward.sqf:20`), corpse search | + reward, +1 | — |

### The enemy's pool goes down only by being spent

Nothing the player does subtracts from OPFOR's Army Power. There is no debit anywhere: the
director's own purchases are the sole way the pool falls. Side missions were the obvious candidate
for a player-facing debit — the code for one had sat commented out in `fnc_mission_reward.sqf`
since before this design and has now been deleted — and it is rejected. A debit lets the player
attack a number rather than the war, and the number is the one thing on the enemy's side that the
player cannot see.

**The lever is forcing the enemy to spend, not taking points off it.** Every hardpoint cleared and
every town garrison wiped is a purchase destroyed, and no purchase is refunded
([`hardpoint_system_plan.md`](hardpoint_system_plan.md#the-director-and-the-escalation-ladder)), so
restoring it costs the enemy again. A player who keeps destroying what the enemy buys keeps the
enemy buying, and an enemy that is buying is not banking toward the next tier. That is the same
suppression, expressed as pressure on what the enemy owns rather than on its balance — and it is
visible, because the player can see the emplacement they just destroyed being rebuilt.

**This makes the never-saturating sink load-bearing rather than a refinement.** If the director
runs out of things to buy — every town at IV, corridors full — it stops spending, and with no
debit anywhere the pool then rises monotonically until the ladder tops out, with nothing the
player can do about it. Under a debit that state was survivable. Without one, a saturated director
is a campaign whose escalation the player has no purchase on at all.

The two pools are therefore not symmetric, deliberately. BLUFOR's is a wallet the player fills and
spends, and it drops when ground is lost. OPFOR's is a budget the director burns, and only the
director burns it.

### Losing a zone must cost BLUFOR exactly what taking it paid

The `− swing` on a lost zone is an anti-farm invariant, not a flourish, and it is the one line here
most likely to read as gratuitous punishment to someone tidying up later. Without it, a player lets
OPFOR retake a zone for free and recaptures it for another `+ swing`, indefinitely. With it, the
cycle is exactly net zero and there is nothing to farm.

**Exactly** is load-bearing, and it holds only because both paths measure the zone's *worth*.
Worth never changes; the CP bounty decays on every capture by design
([`info/cp_economy.md`](info/cp_economy.md)). An AP swing computed from the bounty on one path and
worth on the other would leak in whichever direction the mismatch fell. Both
`fnc_blufor_cap.sqf:31` and `fnc_opfor_cap.sqf:34` derive it from `_points`, and must keep doing so.

The enemy's remaining structural advantage is one the player can see and act on:

- **The enemy's towns are free; the player's are work.** A town whose radius reaches into an enemy
  zone starts at `-20` (`server/misc/fnc_civ_init_Tomata.sqf:200-210`) — already in the OPFOR
  band, already paying, already garrisoned at the top reputation tier. Nothing starts in the
  BLUFOR band. Getting a town to `+10` is the deliberate, slow direction documented in
  [`info/cp_economy.md`](info/cp_economy.md).

### Held ground pays the enemy nothing, deliberately

Holding zones does not pay AP to either side. The obvious version of this design — territory pays
AP the way it pays CP — spirals, and the spiral is structural rather than a matter of rate:

- **The enemy's income is front-loaded.** It holds the entire map at hour zero, so a
  holdings-scaled faucet pays it most at the moment it has earned least, and declines only as the
  player wins.
- **The ladder is a one-way ratchet**, so that front-loaded income does not merely give the enemy
  an early advantage — it lets the enemy *bank the ceiling* during its strongest hours and keep it
  for the rest of the campaign, including after being reduced to its last zone.
- **The pace would depend on a setup slider.** `zones_number` runs from 1 to 40
  (`client/dialog/fnc_process_campaign_menu.sqf:93-149`) while the thresholds are constants, so a
  large campaign would climb the ladder forty times faster than a small one and every threshold in
  the mission would mean something different depending on a number chosen before play.

The enemy already leads without any of this, through the two advantages above. A flat income adds
what the director needs to spend without adding a feedback loop: it is the same on every map size,
it does not grow as the enemy wins or shrink as it loses, and it cannot be farmed from either
side. One constant, paid on the existing 30-minute economy tick.

### BLUFOR gets no flat income

The player's AP stays entirely earned — captures, towns, side missions, corpse searches. The
asymmetry is the point: AP is the premium currency, and a passive trickle would make the tier
gates a matter of waiting rather than of fighting. The enemy needs a flat income because it has
sinks to fund and no player to earn on its behalf; the player has a campaign to play.

The cost of that decision is that the civs-off gap below stays a real gap, and has to be closed on
its own terms rather than absorbed by a general income.

### What AP buys is permanent; CP buys uses

Earned-only income is half the rule. The other half is what the points turn into: **an AP purchase
is normally a permanent capability, not a consumable.** CP buys a delivery, a vehicle, a squad —
things that are spent or destroyed. AP buys something the player still has an hour later. That is
what makes hoarding versus spending a real decision instead of an accounting one, and it is why
the pool has to be earned.

The mission already implements this shape for radio supports, so an AP support is the same code
with a different pool. Each case in `client/dialog/fnc_request_support.sqf` tests its own
`support_*_available` flag, spends once, and adds a comm-menu item that costs nothing thereafter —
which is why several comm-menu supports pass `_cost = 0` at use time.

**The eight-slot cap makes an AP purchase exclusive as well as permanent.** A player may unlock at
most eight radio supports (`support_count > 7`, tested first in every case). Permanent *and*
capped means spending AP on the wrong support is a misallocation the player lives with for the
campaign — which is the weight the design wants, and it costs nothing to get, because the cap
already exists. The decision to make is whether AP supports draw on those same eight slots;
they should, or the cap stops meaning anything the moment a second currency can bypass it.

**Two exceptions, both of which have to be legible to the player.** A town garrison is bought with
AP and can be cleared, so it is a purchase that can be taken away — a risked investment where a
support unlock is not. And a tier unlock is not bought at all: it is reached
([below](#the-two-roles-do-not-collide-because-unlocking-costs-nothing)), which makes it permanent
by construction rather than by rule.

**Permanence depends on work that is not built yet.** Support unlocks are client-local by design
with no server-side copy of what the player paid for
([`campaign_persistence_plan.md`](campaign_persistence_plan.md)), so today a permanent unlock
survives neither a reload nor a reconnect. That is tolerable for a 5 CP supply drop and is not
tolerable for the most coveted resource in the campaign: the unlock mirror that plan already calls
for becomes a prerequisite rather than an improvement.

## Civilians off costs BLUFOR its only unearned faucet

Three configurations pay no town income: `CIV_PRESENCE` of `NONE`, `RAVAGE` or `WBK`. Civs-off
leaves the town arrays empty (`fnc_zonesundercontrol.sqf:8-9`); the two mode campaigns register no
town reputation at all, so every town sits permanently neutral and `fnc_civ_townIncome`
(`server/server_fnc_init.sqf:286-291`) pays nobody.

With no BLUFOR flat income, town income is the player's only recurring AP faucet — everything else
is a lump paid for an action taken. So these three settings remove a whole income route rather
than trimming one, and they remove it from the side that has fewer.

The loss is one-sided: OPFOR's flat income is untouched by the setting, so civilians off costs the
player a faucet and the enemy nothing. Turning civilians off should be a presentation choice; it
must not quietly be a difficulty setting.

Decided:

- **Gate on the faucet being absent, not on the mode being named.** The test is that
  `civ_town_rep` is empty — one condition covering all three configurations, and a fourth mode
  added later inherits it instead of being forgotten.
- **BLUFOR only.** OPFOR loses nothing it depends on, so a symmetric substitute preserves exactly
  the gap it exists to close.
- **Flat per tick, not scaled by zones held.** Holdings-scaled AP is rejected outright
  ([above](#held-ground-pays-the-enemy-nothing-deliberately)); a substitute must not reintroduce
  it on the player's side.
- **Paid from the existing 30-minute economy tick**, not a new loop. Equal nominal periods are
  not one clock, which is why that tick was merged in the first place.

**The trap to price around:** town income is *earned* — the player drags a town to `+10` through
aid and healing — while a passive substitute is not. Set it at what a well-played civs-on
campaign yields and civs-off becomes the AP-optimal way to play, which inverts the intent. It
should sit below that, and be felt as a trickle rather than an income.

## The two roles do not collide, because unlocking costs nothing

A tier unlocks on **reaching** a threshold, and reaching it debits nothing. Spending therefore
delays gates not yet reached and never rescinds one already passed. That is the whole contract,
and it is what makes "spend or bank" a real decision rather than a trap: a director that could
lose armour by paying for a garrison would have to hoard, and the sinks would go unused.

The alternative — an unlock that debits its threshold — was rejected. It empties the pool at the
moment the war gets hardest, so every unlock is immediately followed by a period of being unable
to defend anything, and the two roles fight each other for the same points.

## The ratchet is structural today, and only in half the read sites

The wave-composition threads already ratchet by construction: each is a `spawn`ed thread walking
forward through `waitUntil` gates, so once it passes a threshold it never re-tests it. Nothing
needs changing there — a pool drained back below 100 leaves the thread where it got to.

| Site | Gate | Behaviour when AP is spent |
|---|---|---|
| `server/warcom/fnc_WARCOM_opf_assault.sqf:8-21` | 10 / 40 / 65 / 100 / 136 | Holds. Thread is past the gate |
| `server/warcom/fnc_WARCOM_opf_patrol.sqf:10-19` | 40 / 65 / 100 / 136 | Holds |
| `server/warcom/fnc_WARCOM_blu_assault.sqf:11-25` | 10 / 40 / 65 / 100 / 136 | Holds |
| `server/warcom/fnc_WARCOM_blu_patrol.sqf:11-20` | 40 / 65 / 100 / 136 | Holds |
| `server/warcom/fnc_WARCOM_opf_air.sqf:11` | 150 | Holds |

The other eight sites read the pool live, once per spawn, and would silently downgrade the moment
anything spends:

| Site | Gate | What is lost |
|---|---|---|
| `fnc_WARCOM_opf_patrol.sqf:101` | >100 | The second team joined onto a patrol |
| `fnc_WARCOM_opf_patrol.sqf:124,128,132` | >99 / >149 / >199 | Patrol car, then armour, then the third vehicle |
| `fnc_WARCOM_blu_patrol.sqf:96,100,104` | >99 / >149 / >199 | The same three vehicle steps, BLUFOR side |
| `server/missions/fnc_missionPatrols.sqf:18` | >100 | Mission guard armour drops to a car |
| `server/missions/fnc_missionPatrolswithintel.sqf:14` | >100 | Same |

**These must read the unlock, not the pool** — and the tier globals that replace them are save
state, for the same reason. A reload that restores the pools but not the tiers would re-derive
them from a pool that has since been spent down, silently downgrading an enemy that had already
unlocked armour. A ratchet whose only record is a number that goes both ways is not a ratchet.

A player who watches enemy armour disappear because the enemy bought a garrison is being shown an
unlock that un-unlocked, which contradicts the one rule the ladder has. The fix is a pair of published tier globals that only ever rise, written
where the `waitUntil` threads already step, and read in place of the comparisons above. Every
surviving site is a threshold test; a consumer that wants a curve rather than a gate takes the
highest tier reached instead.

Making the tier explicit is also what lets both sides display it. The pool figure alone stops
describing capability the moment spending starts.

**The starting-AP presets become the ladder's own rungs, plus zero.** Each side's opening pool is
picked independently from seven options — 10, 50, 80, 110, 150, 170, 200
(`client/dialog/fnc_process_campaign_menu.sqf:278-308,319-349`) — none of which except 10 and 150
lands on a threshold, so today the preset sets a position part-way between tiers and the host
cannot tell which one they picked. Replacing them with `0, 10, 40, 65, 100, 136, 150` is the same
seven options expressed as *"start at this tier"*, and it is exact: those are the wave rungs plus
OPFOR air.

Zero is the one genuinely new option, and it matters more than it used to. The preset is no longer
only a ladder position — under a spendable pool it is also an opening wallet, so a 200 AP start
hands a side several permanent purchases before the first shot. Zero is what a campaign that wants
both economies earned from nothing selects.

The seven values are *derived* from the thresholds rather than chosen alongside them. If the ladder
is retuned — and it likely will be, since it was set against an economy where only captures paid —
the presets are regenerated from the new rungs, not re-picked. A preset that no longer lands on a
threshold has silently gone back to meaning nothing.

## Spending authority

`fnc_ap_adjust` (`server/server_fnc_init.sqf`) stays the sole writer of both pools. Two paths in:

- **Player spends go through the purchase handshake.** `fnc_pool_spend` already carries an `"AP"`
  case (`server/server_fnc_init.sqf:415`), used today only by the AP→CP converter. Every new
  player-facing AP sink uses it for the same reason CP sinks do: a client testing its own copy of
  a networked pool is a round trip out of date, so two co-op players can both pass one gate.
- **Director spends call `fnc_ap_adjust` directly**, as `["OPF", -_cost, _reason] call
  fnc_ap_adjust`. There is no second writer to race — the director is server-side and single —
  so the handshake would only add a frame boundary between its test and its debit.

**Escalation scales CP prices only.** `fnc_pool_try_spend` applies `fnc_escalation_cost` to every
pool on entry, which would scale BLUFOR AP prices as a side effect; the `"AP"` case has to opt
out. Two reasons. CP is the player's own purchasing power, so a hardening enemy making the
shopping list dearer is what escalation is modelling — AP is the war's momentum and belongs to
more than the player. And AP purchases are permanent, so scaling them would make buying early
strictly better than buying well, which is the opposite of a decision worth having.

**AP needs a live counter, which it has never had.** Nothing spent AP, so nothing had to display
it: `fnc_ap_adjust` broadcasts the pool but refreshes no control — its own comment says *"no HUD
counter to refresh"* — and there is no `publicVariableEventHandler` for either pool, which
`client/dialog/fnc_convertAPtoCP.sqf:12` notes as the reason it paints control 1002 from its own
predicted total rather than re-reading. Three dialogs read AP at open time
(`fnc_FOB_Request_Menu.sqf:9`, `fnc_HQ_Request_Menu.sqf:9`, `fnc_convertAPtoCP.sqf:13`) and none
updates afterwards. A stale counter was cosmetic when AP was a score; it is a purchase made on
wrong information once AP is a currency, and worse in co-op, where someone else's spend is exactly
what the reader cannot see. The map view readout ([below](#reading-the-war-from-the-map)) covers
the deciding case; a dialog that sits open while another player spends is the residue.

**AP prices must be integers, and nothing will enforce it any more.** `fnc_ap_adjust` does not
round — CP's writer rounds its running total, AP's simply adds and floors at 0 — so a fractional
delta persists in the pool. Until now `fnc_escalation_cost` was an accidental guard, since it
`ceil`s every price on the way through `fnc_pool_try_spend`; taking AP out of escalation removes
it. A pool resting at 39.97 fails a `>40` gate while a rounded counter prints 40, and the player
has no way to tell why.

**Who may spend is unsettled, and the leaning is toward `game_master`.** Both pools are shared, any
squad lead can spend them today, and permanence means a bad AP purchase cannot be worked off the
way a wasted CP one can. The shape under consideration is moving the support call to `game_master`
alone, which already owns campaign-level control — the setup flow, side-mission requests, the
global heal ([`info/cp_economy.md`](info/cp_economy.md)) — and reads naturally as the BLUFOR
commander. That is a role decision as much as a permissions one: it makes one player answerable for
the campaign's premium currency rather than making every squad lead trustworthy.

## Reading the war from the map

Garrison levels belong in the click readout, not on the markers. Nothing is added to the map
itself: the player opens the board's View Map action, clicks a town, and the popup that already
answers gains a line.

The three additions do not arrive together, and the order is forced rather than chosen. CP and AP
depend on nothing. A town's garrison level waits on the garrison work in
[§Town garrisons](#town-garrisons-i-through-iv), which is what turns a tier into something a query
can read. Zones enter the readout later still, and are not in it at all today.

**The mechanism exists.** `client/misc/fnc_civ_mapView.sqf` claims map clicks, each click goes to
`fnc_civ_townQuery` on the server, and `fnc_civ_townInfo` draws the answer as a map prompt — name,
population, reputation, and what the town pays or is worth. A garrison level is one more field on
the tuple those two pass and one more line in the readout.

The lookup has to stay server-side for the same reason it already is: `civ_locations`, `civ_radii`
and `civ_town_rep` are none of them broadcast, so the click travels to the server and the readout
travels back. Nothing about a garrison figure changes that, and it is why this costs no new
networked state.

**Reveal gating is already correct for towns.** An unrevealed town answers as empty ground rather
than as a hit the readout declines to describe, so the map cannot be swept for towns the presence
trigger is keeping hidden. A garrison line inherits that, because the query never reaches the point
of composing a readout.

**Nothing records a garrison tier today**, which is why the readout cannot lead. In
`server/misc/fnc_civ_garrison.sqf:72-74` the tier is a local, computed inside the spawn branch,
used once and discarded. Making it per-town state belongs to the garrison work, not here — the
effective tier is the higher of the reputation tier and the purchased one, so that feature has to
record it either way. The readout is a consumer of that state and follows it.

**Zones, when they are added.** `fnc_civ_townQuery` searches `civ_locations` and nothing else, so a
click on a zone reads as empty ground. Extending it means a second lookup against `zone_meta_array`
and — the part that has to be got right — a zone reveal test standing in for the `civ_visible` one,
or the readout becomes the free map sweep the town path was written to avoid. What a zone reports
needs deciding too: zone garrisons are tier IV by definition, so a constant `IV` says nothing, and
the useful figure is the strength it will actually spawn at, which comes from the OPFOR tier ladder
rather than from the zone.

**CP and AP need no round trip.** Both pools are `publicVariable`d, so the client's copies are
current; the map view can print them directly. That also answers most of the missing-counter
problem above without a `publicVariableEventHandler`: a readout the player opens is read at the
moment they are deciding, where a dialog control left open is not.

### SITREP becomes free

It costs 1 CP today (`server/supports/fnc_sitrep_support.sqf:3`) and reports what the player can
already work out — more so once the map carries the same figures.

**The stronger argument is that SITREP is the only save in the mission.** It is the sole caller of
`fnc_autoSave` ([`campaign_persistence_plan.md`](campaign_persistence_plan.md)), so the 1 CP is a
charge for saving the game, and a player who has spent down to nothing cannot save at all.

**The cost is also the only throttle**, since there is no cooldown on the support. Removing the
price without adding one leaves `saveGame` spammable, and a save is a real frame hitch rather than
a free call. The cooldown replaces the price; it does not accompany it.

## Town garrisons: I through IV

Towns gain purchasable garrisons on both sides. A zone garrison is the benchmark the ladder
climbs toward: `server/init_zones/fnc_createopfortified.sqf` fields a multiplied fortified group
with a squad leader, a mortar team, and up to eight buildings occupied at three units each.
**Zone garrisons are tier IV by definition and are not purchased** — they are what a zone already
is, and nothing about zone generation changes.

Today a town garrison is OPFOR-only and its tier comes from reputation alone: tier 1 at `-10`,
2 at `-15`, 3 at `-20` (`server/misc/fnc_civ_garrison.sqf:72-74`, band contract in
[`info/zone_and_town_generation.md`](info/zone_and_town_generation.md#ownership-bands-and-the-garrison)).

Decided:

- **Reputation still decides *whether* a town garrisons; AP decides *how hard*.** The band is the
  trigger and stays untouched, so the existing contract — clear the garrison, reputation resets
  to 0, the garrison stops — survives intact.
- **Effective tier is the higher of the reputation tier and the purchased tier.** A purchase can
  only raise a town, so a town ruined to `-20` is never made weaker by the arithmetic.
- **Clearing a town destroys the purchase.** No refund, and the director must spend again to
  restore it. This is the same anti-farm rule the hardpoint director runs on
  ([`hardpoint_system_plan.md`](hardpoint_system_plan.md#the-director-and-the-escalation-ladder)),
  applied from the other end: with a refund, a player clearing towns would hand the enemy its AP
  back and the enemy would never climb; with a purchase that survives clearing, clearing stops
  meaning anything.
- **Tier IV is more units, not fortifications.** A town garrison remains units-only — no
  prefab, no fortification ring — because static emplacements are what make a zone an objective
  and a town must not compete with one. IV therefore reaches the zone benchmark by occupying
  buildings, which is what `fnc_createopfortified.sqf` mostly is anyway.

| Tier | Adds | Reputation reaches it at |
|---|---|---|
| I | Patrol plus one team | `-10` |
| II | Second team, light vehicle | `-15` |
| III | Armour | `-20` |
| IV | Building-occupying units, on the zone pattern | never — purchase only |

BLUFOR garrisons are new ground: the BLUFOR band (`>= 10`) has no garrison today, so a player
buying tier I at a town they hold is creating something that has never existed rather than
upgrading something that has. It is the player's answer to the enemy taking towns back.

## What the OPFOR director spends on

| Sink | Effect | Notes |
|---|---|---|
| Town garrison upgrade | Raises the purchased tier of one town | Above |
| Tasking order | Gives a newly spawned squad a job | Below |
| Hardpoint construction | Builds an emplacement | [`hardpoint_system_plan.md`](hardpoint_system_plan.md) |

A tasking order is bought for a squad the director is spawning anyway, so the price buys
*intent*, not units. Four jobs:

| Tasking | Job |
|---|---|
| QRF | Respond to contact. The removed contact-triggered QRF is the behaviour to rebuild here, under a commander that decides whether to spend the reserve rather than a handler that always does |
| Supply | Move between held towns and zones, restoring garrison strength en route |
| Rapport | The enemy's hearts-and-minds: occupy a town and drag its reputation toward OPFOR |
| Intel patrol | Sweep for BLUFOR and report what it finds, feeding target selection |

The intel patrol is deliberately the weak one — a cheap tasking that buys knowledge rather than
force, and unlike the other three it goes looking for the player instead of circulating around
what the enemy already holds. `reveal` against EAST is the mechanism, the same one the hardpoint
observation post uses.

Rapport is the direct counterpart to the player's aid missions, and it is what makes the town
economy two-sided: today a town only moves toward OPFOR through the player's own mistakes.

### The commander has an archetype

One archetype is rolled per campaign and decides how the director splits its income across the
sinks above. Two campaigns on the same map with the same settings should not produce the same war.

| Archetype | Spends toward |
|---|---|
| Defensive | Town garrisons and hardpoints; fortifies what it holds and cedes initiative |
| Balanced | No strong lean — the baseline the others are tuned against |
| Aggressive | Taskings, especially QRF and rapport; projects force and leaves its ground thin |

Two further axes are worth having and are the obvious extensions — a commander that favours
indirect fire (weighting mortar pits and the battery), and one that favours armour (weighting the
vehicle-heavy garrison tiers). Whether those become entries in this one list or a second
independent roll is open; a single authored list is the recommendation, because each archetype can
then be tuned and named as a whole, and a second roll multiplies out combinations nobody has
balanced.

Three properties keep this from becoming a problem:

- **Weights, not switches.** An archetype biases the roll; it never removes a sink. A Defensive
  commander that could not order QRF at all would hand the player a permanent read on the campaign
  and delete a mechanic from it. `selectRandomWeighted` is the mission's idiom for exactly this,
  used for zone prefabs and the WARCOM wave tables.
- **It cannot override the ladder.** An Aggressive commander with no armour tier reached still
  fields no armour. Archetype decides what the enemy buys, never what it may buy, so the tier
  gates stay the one honest signal of how dangerous the enemy is.
- **It is not difficulty.** `opfor_ai_skill` (`client/dialog/fnc_process_campaign_menu.sqf:393-413`)
  already sets how well the enemy shoots. An archetype changes what kind of war it fights, and a
  Defensive commander is not an easier one — it is a slower, more fortified campaign.

Rolled once at WARCOM init and never re-rolled, so it is campaign state and belongs in the
persistence snapshot alongside the AP unlocks.

**What limits an archetype's spending is its sink's throughput, not its prices.** Every sink is
rate-limited by something other than money, and the limits are nothing alike:

| Sink | What throttles it | Saturates? |
|---|---|---|
| Town garrison upgrade | Tier ceiling of IV, times the towns in the OPFOR band | Yes — a fully upgraded map has nothing left to buy |
| Hardpoint construction | One build attempt every 20-30 min, 8-25 AP each | No, but it is capped at roughly one purchase per build tick |
| Tasking order | The rate squads spawn at, which for QRF is set by how much contact the player makes | No — and it rises when the player is active |

So no archetype reliably outspends another, and each has its own way of running out of things to
buy: a Defensive commander whose towns are all at IV is left with the build tick alone, and an
Aggressive one facing a quiet player has no squads to task. **Whichever archetype saturates first
banks the surplus and climbs the ladder on it**, which is the hoarding problem arriving by a
different route than a cheap shopping list — and it says the director needs one sink that never
saturates and can absorb whatever the others leave, rather than an archetype-by-archetype fix.

## Open questions

- The flat rate itself, which is the first number to settle: every OPFOR price here is expressed
  against it. The bounding case is a director that never spends — the rate must leave that enemy
  hours short of the top of the ladder, since the sinks are optional and the ratchet is not.
- Prices for every sink, and whether the four taskings differ enough in cost to make the choice
  interesting or should be flat.
- The civs-off substitute rate, which cannot be settled on paper: it has to be measured against a
  civs-on campaign's actual BLUFOR town income, not against the ceiling every town banded implies.
- Whether RAVAGE and WBK take the same substitute as civs-off. They lose the same faucet, but
  their threat model is not the enemy ladder, so the rate that fixes one may not suit them.
- Whether the player can *learn* the archetype, and how. One the player can never perceive is
  variance rather than a mechanic; the intel system is the obvious route
  ([`info/intel_system.md`](info/intel_system.md)), and observed behaviour is the free one.
- What the never-saturating sink is. This is the first thing to settle after the flat rate, since
  with no debit anywhere it is the only thing standing between a saturated director and a pool
  that only rises. Reinforcing an existing garrison rather than upgrading it, or replacing losses,
  would absorb surplus without an ever-growing map — but any such sink is also the one the enemy
  spends on when it has run out of ideas, so it has to be something the player still notices.
- Whether the director should be *required* to spend rather than merely able to. Banking is
  strictly simpler than spending, and a director that banks by default turns "spend or climb"
  into a formality — but a forced-spend rule is a policy, and policies are where AI directors
  become predictable.
- Whether clearing hardpoints and garrisons faster than the director rebuilds them holds the enemy
  below a threshold indefinitely. It is the only suppression route there is, so it wants to work —
  the question is whether it works so well that a diligent player freezes the war, and only play
  answers that.
- The capture swing's new value. It has to stay large enough to read as a windfall and small
  enough that towns outweigh it over a campaign, and both halves of the lose/retake pair move
  together — the swing is one number, not two.
- Whether the AP→CP converter survives. It is a 15 AP → 10 CP one-way trade with no cooldown
  (`client/dialog/fnc_convertAPtoCP.sqf`); with the player's AP entirely earned and now buying
  garrisons and tiers, selling it for CP competes with both.
- Whether the support call moves to `game_master` alone, and what a squad lead sees when it does.
  Restricting it makes one player the BLUFOR commander, which is a role the mission does not
  currently ask anyone to play; in a two-player session it may just mean one of them cannot buy.
- Which supports move behind an AP tier, and what the player is told when one is locked.
- Whether anything bought with AP is consumable after all. The rule admits one exception already
  (a garrison can be cleared), and a second would make "AP buys permanence" a guideline rather
  than something a player can rely on when deciding what to spend.
