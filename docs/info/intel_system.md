# Intel and hardcore mode

Hardcore hides every enemy zone, and every civilian town bar the handful around the HQ, at campaign start
and makes finding them the game. Intel is the mechanism that unhides them. It is not hardcore-only — what
differs between the modes is the pool, not the machinery.

## What intel is for

**Intel reveals positions the player does not know exist.** Unrevealed zones, hidden hardpoints, enemy
locations somewhere on the general map — strategic discovery, and the answer to "where is the war". It is
not a live feed about ground already found.

That line is load-bearing, because it is what rules mechanics out. Two shipped features were deleted
against it rather than reworked: develop-informant, which drew a 700 m disc over a town and marked every
enemy inside it for one to three hours, and the informant spawner, which handed intel out on a 30-minute
timer the player could not influence. Both functioned. Both were a tactical readout of ground the player
was already standing on, sold as intel. Something that marks known enemies locally does not compete with
the sources below, because it is not answering the same question — but it does not belong in an intel
channel either.

## What is hidden depends on when it came into existence

Not on the difficulty setting. Campaign generation puts its output on the map in normal mode; anything
OPFOR build during play stays hidden in both.

| | Normal | Hardcore |
|---|---|---|
| Zones | visible from the start | hidden |
| Civilian towns | visible from the start | hidden, bar the HQ anchor's opening three |
| Zone hardpoints | visible from the start | hidden with their parent |
| Normal hardpoints, generated at start | visible from the start | hidden |
| Normal hardpoints, built in play | **hidden** | **hidden** |
| Enemy elements on missions | **hidden** | **hidden** |

So normal mode has a live intel channel answering "what has changed", and hardcore has that plus
everything generation produced, answering "where is the war". Both of normal mode's payouts are unbuilt
today, so outside hardcore the reveal pool is empty and a draw that lands on intel has nothing to give.

**The mode changes what is hidden and nothing else.** Every mechanic runs the same in both — same flag
rates, same action, same payout table, same substitute when intel comes up dry. Only how often each branch
is reached differs, because that follows from what generation put on the map. The search used to be gated
on `hardcore_mode_enable` to sidestep the empty pool, which cost normal mode a whole faucet to avoid a case
one branch handles.

## One writer per reveal flag, one function for payout

Two contracts hold the system together, and both exist so that adding a source cannot quietly change what
intel is worth.

**One writer per flag.** `fnc_zone_reveal` owns the revealed flag in `zone_namePOS_pairs`, whose entries
are `[name, pos, revealed]`; `fnc_civ_town_reveal` owns `civ_visible`, one boolean per entry of
`civ_locations`. Both repaint the markers from the flag rather than beside it, so no caller can leave the
map and the array disagreeing, and both return whether they changed anything so a caller can tell
"revealed something" from "that was already on the map".

Both take the audience for their announcement rather than assuming one. Walking into a zone or a town is
everyone's news and takes the default of `0`; a reveal bought with a bribe belongs to the one player who
paid for it, so `fnc_intel_payout` passes its earner down and the line is hinted to that player as well as
spoken to them.

Both also take a `_quiet` flag that hands the reporting to the caller outright. The line they speak is
Overlord broadcasting to the AO — *"All units in the AO, be advised"* — which is the wrong voice for a
reveal the searcher bought and speaks in their own, so a search suppresses it rather than talking over it.

Two functions rather than one switched writer, because the two arrays are keyed differently — a zone by
position compared through `str`, since that array carries no index; a town by index — and their markers
follow unrelated naming conventions. The town writer sets its alphas directly instead of delegating to
`fnc_civ_townRender`, which returns early for RAVAGE and WBK: those campaigns register no town reputation,
and their towns still have to be revealable. In the other direction `fnc_civ_townRender` reads
`civ_visible` before it touches the ellipse, so a reputation change cannot repaint a hidden town back onto
the map.

**`fnc_intel_payout` is the single point where intel becomes something.** Every faucet calls it: the body
search, all six side-mission sites, and the civilian menu when it lands. It picks a *kind* at random from
those holding something right now, then lets that kind pick its own member, and reports that it had
nothing left rather than silently awarding nothing.

| Kind | Picks | State |
|---|---|---|
| An unrevealed enemy zone | at random | built |
| An unrevealed civilian town | nearest to where the intel was earned | built; contributes nothing outside hardcore, where no town is hidden |
| An unrevealed hardpoint | at random from the eligible set | built ([`hardpoints.md`](hardpoints.md#reveal)) |
| An unrevealed enemy patrol | — | waiting on [`../opcom_plan.md`](../plans/opcom_plan.md) |

**Kinds are separate buckets rather than one merged pool, because they are picked on different rules.** A
zone is a target the campaign points the player at, so which one comes next is a strategic question and
random is right — ranked by distance it would march them outward in a spiral. A town is somewhere the
player goes to *do* something, so one on the far side of the map is worth no more to them than nothing
happening, and nearest wins. One merged pool would force a single rule on both. The consequence to know
when tuning: in hardcore both buckets usually hold stock, so roughly half of all intel goes to towns.

Every bucket draws from the unrevealed set rather than from everything and filtering after the draw.
Drawing from every zone and then testing whether it happened to be hidden — the shape this replaced —
makes the real odds decay as a campaign progresses, because late on most winning rolls land on ground
already found.

**A dry bucket drops out of the draw, not out of the feature.** `_kinds` is rebuilt from what has stock on
every call, so the last zone being found silently turns the coin flip into towns-only and nothing latches.
When every bucket is empty the payout speaks *"Nothing we don't already know"* itself rather than returning
quietly: four of the six side-mission sites hand their result to a `remoteExec` and never see the return
value, so a line spoken at each faucet is a line four of them cannot say. It goes to the earner where there
is one, and from Overlord to everyone where there is not, because a mission completing is everyone's news.

Only hardpoints can refill a dry pool — they are the one kind OPFOR build during play
([§What is hidden](#what-is-hidden-depends-on-when-it-came-into-existence)). Zones and towns are generated
once, so once found they are found for the campaign, and today that means the pool goes dry permanently.

The town bucket needs somewhere to measure from, so every faucet passes an origin in. The body search and
the four hold-action sites have a player to ask; the two rescue missions pay out from a server thread that
has none, so they pass the mission site, the ground the rescue was fought over. A faucet that passes nothing
falls back to the HQ. With neither, the bucket sits out the draw rather than picking at random — one feature
quietly running on two different rules is worse than it paying a zone instead.

`hardcore_visibleZone_found` gates every task-force launch (`fnc_request_squad`,
`fnc_WARCOM_blu_assault`). It is derived from reveal state plus OPFOR ownership and recomputed whole by
`fnc_hardcore_visible_recalc`, never nudged: capture moves it one way and reveal the other, and a delta from
either side drifts as soon as they interleave. Towns are deliberately outside it — it asks whether the
player can see an enemy zone to send a task force at, and a town is not capturable.

## Three sources, three prices

Proximity, the body search and the civilian menu all stay, and they are not redundant: proximity costs the
walk in, the body search costs a firefight, and the menu costs coins and a town's patience. Three prices for
one commodity is the point — a hardcore player out of one currency still has a route.

| Source | Capped |
|---|---|
| Body search | by the flagged materiel on the ground, not by a clock — a third of any combat group, zone garrison and side-mission patrol alike |
| Side-mission objective | flagged with certainty; reaching the object is the gate |
| Walking into a zone or town | not applicable; it reveals the ground the player is standing on and rolls nothing |
| Civilian frisk | flagged with certainty; the arrest is the price, and its payout table carries the odds |

**A third of a combat group is searchable, so a fight is a reliable route to intel rather than a lottery.**
A much lower rate read in play as a broken action: a player who cleared a position and found no prompt on
any body had no way to tell a cold roll from a feature that never worked. What keeps the search from
collapsing into a kill count is its payout table, where intel is one kind of four, not its flag rate — so
a combat group pays *something* most of the time and pays intel far less often than that.

The sources draw from one finite pool, so they compete rather than stack, and the hidden-map phase ends when
the last hidden position is found however that happened. That is the intended arc — but it means adding a
fourth source shortens hardcore rather than enriching it.

Side missions are uncapped *and* unrolled. The old design put a campaign-wide throttle in front of them, so a
mission completed during another source's cooldown paid nothing and said nothing about why; worse, the roll
ran at mission *setup*, deciding whether the intel object existed before the player had done anything. Four
of the six plant a hold action on a specific object rather than paying on completion, because reaching that
object is the mission.

## The success roll is spent at spawn, so the price is the fight

An entity that can be searched is decided when it is created, not when it is searched
(`server/misc/fnc_search_flag_group.sqf`). What the player can find is then a function of how much OPFOR the
campaign put on the ground, rather than of how often a key was pressed, and the price of a search is the
fight that produced the thing being searched.

**That is what let the clock go.** The body search used to carry a second price, one attempt per player per
30-minute economy tick, and with it a UID-keyed record, a broadcast copy on the player object and a restore
routine to reconcile the two across a respawn — a whole apparatus existing only to make a timer survive
dying. A flag lives on the body and dies with it, so none of it is needed. `DUWS_civ_intel_asked` still rides
`econ_tick`, because asking a *local* is capped against a finite population rather than against a clock.

Only the flagged share carries any state, rather than every corpse the campaign produces. Flags are broadcast,
because the action's condition is evaluated on the client that would draw it and an unflagged thing offers no
action at all.

**A zone rebuilding its garrison re-rolls, and that is allowed.** A player can leave, wait out the despawn,
return and search a fresh garrison — but the cycle is not a button press, it is walking out and defeating a
full garrison again. The pool is finite, so farming buys a faster route through the hidden-map phase and
nothing after it, and the cost scales with the reward because the garrison that must be beaten is the same
garrison whose size sets how many flags are in it.

## What a search pays is a weighted table per source

Stage two is a draw over `DUWS_searchSources` (`server/server_var_init.sqf`), each row naming a payout kind
and its weight. Weights rather than a cumulative `if` ladder: every band in a ladder depends on the one above
it, so adding a kind means re-deriving each constant below it.

Kinds are drawn **without replacement**. `fnc_intel_payout` is the only kind that can decline — it returns
false once every position is revealed — and when it does, that kind drops out and the remainder are re-drawn.
A dry pool therefore costs a search its best outcome rather than its voice, which is the failure this mission
already paid for once when a dry pool returned quietly.

**When intel is exhausted, the search pays a flat 2 CP in its place.** Reachable only where intel was the last
kind standing — an intel-only source such as a mission objective, which hardcore reaches once the map has been
found and normal mode reaches on every such search. Reaching the objective still pays, so a reveal pool going
dry costs the search its best outcome rather than its whole worth.

`fnc_search_claim` silences its own call into `fnc_intel_payout`, so a live reveal is reported in the
searcher's voice rather than announced twice; the flat consolation above is spoken the same way when there is
nothing left to reveal.

`nothing` is a row rather than the absence of one, and a weight of zero is how a source opts out of a kind.
The empty-handed line is per-source too, because a body that held nothing and a detainee who was carrying
nothing are different sentences.

**Every outcome is spoken in the searcher's voice, to the searcher alone.** A frisk spoke in the team's
callsign until the two shapes were reconciled; the player did the searching either way, and one voice per
faucet was the thing this system was collapsed to remove. It is hinted as well as spoken: the dialogue queue
holds a line behind whatever traffic is already in it, and a result the player held an action for should not
arrive late or scroll past unread. The audience is the searcher rather than everyone because a body emptied
in co-op is not news the other three players asked for. That holds for the reveal kinds too, which is why
they are silenced upstream rather than left to announce themselves.

**What the team sees instead is a notification, and only for the two kinds that move shared state.** A
revealed position lands on every player's map and a pool payout lands on every player's CP total, so the
team is told those happened even though the search that bought them is reported locally. Money, a document
and an empty pocket move nothing anyone else can see and stay with the searcher. This is the one split the
system draws: *voice and hint are local, the notification is global*, and the notification prose is written
for a reader who did not do the searching — hence *"The pool gains 2 CP"* rather than *"you gained"*.

**Both rolls run on the server, and so does everything they read.** A roll a client makes is a roll a client
can retry. Server authority over the roll alone is not enough: the reveal payout was once handed a target
position sampled on the client, from a global only the server ever wrote, so it silently paid nothing on a
dedicated server while working perfectly on a listen host. The claim is taken before the payout resolves,
because the intel branch speaks across a sleep.

## One action on the player, not one per searchable thing

One hold action watching `cursorObject`, rather than an action attached to each thing that can be searched. A
per-corpse action needs a `remoteExec` with the JIP flag per death, so it costs one queue entry and one action
for every body the campaign produces rather than one of each per player.

The flag is what let the type test go with it. The condition no longer asks whether the thing under the cursor
is a body: it asks whether it carries a search source and has not already been claimed, which covers bodies
and the objects a mission places deliberately — a laptop, a piece of armour — through one condition. Those
objects had an action apiece before, each with `removeOnCompletion` set, and that removal is local: it hid the
entry from the searcher and left it standing for everyone else, so in co-op one objective paid once per player.

Living men are the one exclusion the flag cannot express, since a garrison is flagged when it spawns. That
clause is scoped to men rather than gating the whole action, because a laptop is never dead and an intact
vehicle is still worth opening. The condition's clause order is load-bearing and is documented where it lives
(`client/misc/fnc_intel_search_action.sqf`); it matters at all because an action on the player is evaluated far
more often than one on a distant object — the player is never out of range of themselves.

**The action survives its owner's death, so it has to be stripped.** An `addAction` is not removed by its owner
dying and the engine goes on evaluating the conditions of actions on any object near a player, so a corpse left
carrying this one polls the whole condition for the rest of the campaign — one more per death, forever, which
is the per-object cost this shape exists to avoid. `onPlayerKilled.sqf` strips it from the body using the id
stashed at add time.

## Persistence

A hardcore campaign's entire progress is which zones and towns it has revealed, and none of it survives a
restore today. The shape it needs — revealed state as an outcome applied after build-out, the same as zone
ownership — is specified in
[`../campaign_persistence_plan.md`](../plans/campaign_persistence_plan.md#the-snapshot), which is unbuilt.
