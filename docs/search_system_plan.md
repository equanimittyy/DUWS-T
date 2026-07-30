# The Search system

Searching a thing — a corpse, a laptop, a surrendered civilian, a cache — becomes one mechanic
with two rolls, configured per source rather than reimplemented per source:

1. **Success roll.** Did the search turn anything up?
2. **Payout roll.** Given that it did, what came out of it?

Both are per-source data. A civilian frisk can succeed half the time; a side-mission objective can
succeed always. An intel mission can pay intel every time; a corpse can pay a spread.

This is a design for unbuilt work. What ships today is described below as the starting state, and
the near-term garrison change that lands before any of this is in
[`refactoring_plan.md`](refactoring_plan.md).

## Why one system

Five surfaces search something. Two already have the two-roll shape; three fused or skipped a
stage, each in a different direction.

| Surface | Success roll | Payout |
|---|---|---|
| Body search, any corpse (`server/misc/fnc_intel_search.sqf`) | 20%, one per player per economy tick | `fnc_intel_payout` |
| Document turn-in (`server/misc/fnc_intelAnalysis.sqf:70`) | 10% | `fnc_intel_payout`, falling through to CP |
| Mission garrison corpse (`client/misc/fnc_corpse_search_action.sqf`) | fused — one roll is both | inline: reveal target / 1 CP + 1 AP / nothing |
| Civilian frisk (`shared/functions/fnc_civ_search_action.sqf:31-51`) | fused — one roll is both | inline: 1–5 coins / one document / nothing |
| Mission objective — laptop, cache, armour, sniper nest | none; reaching the object is the gate | `fnc_intel_payout` |

Three separate odds tables encode "did it work" and "what did I get" in one number each, so
neither can be tuned without moving the other. The two that already split the rolls prove the
shape works — the turn-in's fallthrough is the clearest case: the reveal is a 10% draw on top of a
CP payment that happens regardless, which is only expressible because the stages are separate.

## Stage 1: the flag, set when the entity is created

**The success roll happens at spawn, not at search.** An entity that can be searched carries a
flag decided when it is generated — 5–10% of a mission garrison, and every side-mission objective.
Searching an unflagged thing finds nothing, deterministically. Searching a flagged one always
reaches stage 2.

Rolling at creation rather than at the action is what makes the faucet a function of the world
instead of a function of how often the player pressed a key. A garrison of thirty holds two or
three pieces of intel and holds them whoever finds them; the number is set by how much OPFOR is on
the ground, which is a thing the campaign already controls.

It also collapses the per-entity cost the outward-looking body search exists to avoid: only the
flagged minority needs any state at all, so whatever marks a searchable thing is carried by one
unit in fifteen rather than by every corpse the campaign produces.

Side-mission objectives are the same flag with a chance of 1. A laptop, a cache and a flagged
rifleman are one kind of thing to the search action, which is what lets the objectives stop being
a separate hold-action path with its own inline payout.

### The 30-minute per-player throttle goes

**What a search costs is the fight that produced the thing being searched, not a clock.** The body
search carries a second price today — one attempt per player per 30-minute economy tick — and it
is removed. The flag is the constraint: the limit is how much flagged materiel the player fought
through, not how long they have waited since the last time.

That is one price instead of two, and the price left is the one the mission always meant: reaching
the body.

### Streamed entities are flagged too, and the farm is the price

A zone despawns 300 s after BLUFOR were last seen and rebuilds its garrison from scratch when they
return (`server/init_zones/fnc_spawnWait.sqf:13`, and the `while {true}` at
`fnc_createzone.sqf:286-293`), so flagging on generation means a fresh roll on every rebuild.
A player can leave, wait out the timer, come back and search a new garrison.

**That is allowed.** The cycle is not a button press: it is walking out, waiting, walking back in
and defeating a full garrison again for one to three reveals. Intel bought with repeated firefights
is intel that was earned, and the mission already prices the body search as costing a firefight
([`info/intel_system.md`](info/intel_system.md#three-sources-three-prices)) — this only makes the
player able to choose to pay it again.

Two properties keep it from running away. **The pool is finite**: every source draws from the same
unrevealed set, and when it is empty the payout says so rather than inventing something, so farming
buys a faster route through the hidden-map phase and nothing at all afterwards. And **the cost
scales with the reward**, because the garrison that must be beaten to search it is the same
garrison whose size sets how many flags are in it.

What this does change is pace: a player who wants to grind can reach the end of hardcore's
discovery phase faster than one who does not. That is a deliberate trade of arc length for player
agency, not an oversight.

The throttle is also the most expensive thing in the subsystem to keep, because it does not
survive a respawn on its own. A respawned player is a new object carrying no flag, so the attempt
was refunded on death until a second record was added beside the first. Removing the throttle
removes both records and everything built to reconcile them:

| Goes | Where |
|---|---|
| `playerIntelSearchTick`, the UID-to-tick record | `server/server_var_init.sqf:311` |
| `DUWS_intel_searched`, its broadcast copy on the player | set in `fnc_intel_search.sqf:18` |
| `fnc_intel_search_restore`, which reconciles the two across a death | `server/server_fnc_init.sqf:1243-1249` |
| the restore call at every action add | `client/misc/fnc_intel_search_action.sqf:60` |
| one clause of the action's condition string | `client/misc/fnc_intel_search_action.sqf:27` |
| one line of the economy-tick sweep | `server/misc/fnc_zonesundercontrol.sqf:26` |

A whole registered function, a hashmap, a broadcast variable and a respawn edge case, all of which
exist only to make a clock work. The corpse claim needs none of it: the flag lives on the body,
dies with the body, and no player-side record has to survive anything.

**The civilian menu's intel cap is a different cap and stays.** `DUWS_civ_intel_asked`
(`server/misc/fnc_civ_request.sqf:33,51`) rides the same tick but limits asking a *local*, which is
a finite population the reaction curve already prices in people. Only line 26 of the sweep goes;
line 27 stays.

**The flag rate is what replaces it as the balance knob, and it is a better one.** Removing the
throttle from a per-search 20% would have paid roughly six reveals for a thirty-body engagement,
which ends hardcore's hidden-map phase in a couple of fights. At a 5–10% flag rate the same
engagement pays one to three, bounded by how much OPFOR the campaign chose to put there rather
than by how many times an action was pressed. The intended ordering — civilians primary, bodies a
trickle ([`info/intel_system.md`](info/intel_system.md#three-sources-three-prices)) — survives at
that rate without a clock defending it.

## Stage 2: the payout roll

A weighted table per source, where each row names a payout kind and its weight.

**`fnc_intel_payout` becomes one row, not the stage.** It is the single writer for intel today and
[`info/intel_system.md`](info/intel_system.md#one-writer-per-reveal-flag-one-function-for-payout)
owns that contract — nothing here changes it. But a system covering civilians and corpses pays in
four currencies, and three of them are outside intel entirely:

| Kind | Pays | Existing implementation |
|---|---|---|
| `intel` | a zone, town or hardpoint reveal | `fnc_intel_payout` |
| `coins` | 1–5 `Item_Money_roll` on the ground | inline in `fnc_civ_search_action` |
| `document` | one item from the turn-in pool | inline in `fnc_civ_search_action` |
| `pool` | CP and/or AP direct | inline in `fnc_corpse_search_action` |
| `nothing` | a line of dialogue and no reward | every surface, three different ways |

`nothing` is a row rather than the absence of one. A search that finds nothing must say so — the
mission already learned this the expensive way, where a dry intel pool returned quietly and four
of six faucets could not speak the failure
([`info/intel_system.md`](info/intel_system.md#one-writer-per-reveal-flag-one-function-for-payout)).
A weight of zero is how a source opts out.

The shape, as data:

```sqf
// [successChance, [[kind, weight], ...]]
DUWS_searchSources = createHashMapFromArray [
    ["civ_frisk",      [0.5,  [["coins", 3], ["document", 1]]]],
    ["corpse_mission", [0.6,  [["intel", 2], ["pool", 1]]]],
    ["objective",      [1,    [["intel", 1]]]]
];
```

Weights rather than cumulative thresholds, because the three shipped tables are all written as
nested `if (_roll < x)` ladders where every band's boundary depends on the one before it. Adding a
kind to a ladder means re-deriving every constant below it; adding a row to a weighted table means
adding a row.

## What must not regress

Four properties are load-bearing and are cheap to lose in a rewrite.

**Server authority.** Both rolls run on the server. A client that owns either can retry until it
pays, which is why `fnc_intel_search.sqf` is server-only and says so in its header.

**A flagged thing is claimed before its payout resolves, not after.** The flag survives the roll
that spends it only if nothing clears it first, so the claim goes in ahead of stage 2 — the same
ordering `fnc_civ_request` uses when it sets `DUWS_civ_closed` before the three seconds it spends
speaking, because a claim written on the way out leaves a window in which two players are served
by one source
([`info/civilian_interaction.md`](info/civilian_interaction.md#one-conversation-per-civilian)).
Stage 1 moving to spawn removes the retry loop but not the co-op race.

**Per-corpse actions do not scale and the system should stop adding them.** A hold action added
per death needs a JIP `remoteExec` per corpse and nothing removes those entries, so the queue
grows with the campaign's kill count rather than its player count
([`info/intel_system.md`](info/intel_system.md#the-body-search-looks-outward-so-it-scales-with-players-not-corpses)).
The body search already avoids this by watching `cursorObject` from one action on the player. A
unified Search system should reach corpses the same way and leave hold actions to the fixed,
countable objects — laptops, caches — that a mission places deliberately.

**A search is claimed once, globally.** `fnc_corpse_search_action.sqf:12-13` sets its guard
without the broadcast flag and the hold action's remove-on-completion is per-machine, so in co-op
every player searches the same body for their own payout. Whatever carries the claim must be
server-side state the condition reads, in the shape `DUWS_civ_closed` already uses for civilians
([`info/civilian_interaction.md`](info/civilian_interaction.md#one-conversation-per-civilian)).

## The mission reward and the trickle stay distinct

A mission garrison corpse can currently be searched twice by different mechanics — the hold action
that pays the mission's reward, and the outward body search that pays the trickle any body offers.
That overlap is deliberate.

Under this design they stay distinct **as two sources, not two systems**: different success
chances, different payout tables, one code path. That is what per-source configuration buys, and
it is the reason the distinction does not have to be argued about again — it is a row.

## Open questions

- **What a guaranteed source does when its payout is dry.** The turn-in already answers this by
  falling through to CP, which is the best-behaved case in the mission today. Whether every
  guaranteed source needs a fallback kind, or whether `nothing` is an acceptable outcome for a
  100% success roll, decides how much a side-mission objective is worth late in a campaign when
  the intel pool is exhausted.
- **Whether the civilian frisk moves onto this system at all.** It pays no intel, rides no
  throttle, and is reached only through an arrest that has already charged the town a point of
  reputation. It fits the two-roll shape, but it may be the one source whose cost model is
  different enough that folding it in buys nothing.
- **Whether the search action appears on unflagged entities.** The flag is random and carries no
  tell, which settles what a *living* unit gives away: nothing. It leaves one thing undecided —
  whether an unflagged body offers the search and answers "nothing on this one", or offers no
  action at all. The first keeps the outcome legible and costs nothing extra, since the
  outward-looking action already lives on the player and reads `cursorObject`. The second is
  cheaper still but makes the action's presence the tell the flag was meant not to have.
- **Numbers otherwise.** Every other figure above is the shipped value or the example the shape
  was discussed with, not a balanced one. The rates and the weights are the last thing to settle,
  after the system can express them.
