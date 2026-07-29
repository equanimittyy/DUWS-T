# Civilian interaction

What a local will do for the player sits behind one dialog, built like the Requests and Squad
Manager screens. The town's reputation is rolled *against* rather than gated on, so the `-20 … 20`
per-town scale ([`zone_and_town_generation.md`](zone_and_town_generation.md#ownership-bands-and-the-garrison))
has a consumer reading more of it than `> 0`.

Civilians are primarily an **information** channel: locals are how the player learns where the
enemy is. Everything else the menu offers is secondary to that.

## The reaction curve

Every request rolls one of three reactions, weighted by the town's reputation
(`fnc_civ_reaction_weights`, `src/duws/server/server_fnc_init.sqf:236-247`). With `t = rep / 20`
clamped to `[-1, 1]`:

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
Refuse is written as accept's mirror rather than as its own expression, so the curve cannot drift
out of symmetry by being maintained twice. Bribe is a symmetric tent peaking at neutral: a town
that neither likes nor hates the player is where money talks loudest, and at both extremes
standing decides instead of coins.

**There is no hard refusal wall.** A town at `-20` still takes a bribe one time in ten, so hostile
ground is expensive rather than closed. The player is never locked out of a settlement they have
ruined — the garrison and the aid missions remain the routes back, but a determined player can
still buy a single answer.

**The band boundary is not a cliff on this curve.** `±10` reads 62 % / 17 %, so the ellipse colour
hints at the reception rather than predicting it. That is a deliberate loss of map legibility in
exchange for reputation mattering continuously instead of at two thresholds.

## One conversation per civilian

The roll is scoped to the individual, not the town, and every outcome ends the conversation:

| Outcome | Effect |
|---|---|
| Accept | the request is served, then the civilian walks off and will not talk again |
| Bribe, paid | as accept |
| Bribe, declined or unaffordable | as refuse |
| Refuse | the civilian walks off and will not talk again |

This is what stops the curve being decorative. A per-attempt roll with no cost lets a player at
`-20` work down a fifty-strong town until one civilian says yes — the failure the old heal action
had before `fnc_civ_healed.sqf` replaced it, where a failed roll consumed nothing so the player
simply clicked again. A refusal costs a person, so a hostile town burns through roughly ten
civilians per successful deal against one in ten at a friendly one, and the population is finite
until it respawns.

A person who has helped is as finished with the player as one who refused, so a town is a finite
number of favours rather than a menu worked down row by row on one obliging local.

**One per civilian, not one per player, and claimed when the row is picked rather than when the
roll resolves.** `fnc_civ_request` sets `DUWS_civ_closed` before the three-second pause it spends
speaking the opener, so the flag is broadcast while the exchange is still in flight. Written on the
way out instead — in `fnc_civ_serve` or `fnc_civ_close` — it left three seconds in which a second
player stood at the same local passed the same check, and the person answered both: two medikits,
two intel drops, or a recruit joining one group while already in another.

An arrest is one of the exchanges a civilian only has one of, so it and a conversation block each
other. `fnc_civ_arrest` claims `DUWS_civ_arrested` before its own pause and tests
`DUWS_civ_closed`; `fnc_civ_request` tests both. Neither flag is ever cleared, so a detainee who is
released stays spent.

## Range: two distances, on purpose

| Step | Reach | Source |
|---|---:|---|
| Call over | 6 m | `src/duws/shared/functions/fnc_civ_stopCommand.sqf:59` |
| Interaction menu | 3 m | `src/duws/shared/functions/fnc_civ_menuAction.sqf:44` |
| Every menu row, re-tested server-side | 3 m | `src/duws/server/misc/fnc_civ_request.sqf:22` |
| Search and Release | 3 m | `fnc_civ_search_action.sqf:79`, `fnc_civ_release_action.sqf:29` |

The call-over reaches twice as far as everything it gates. Halting a local you can see, walking up
to them, and only then getting an exchange is the shape of the interaction; matching the two
distances meant standing close enough to talk before being allowed to ask for attention. The
call-over also carries a 15° facing cone — `abs (180 - getRelDir) > 165`, close to an aim test —
so it picks the person meant rather than whoever is standing beside them.

Call over is the gate on everything else: the menu action does not appear until the local has been
told to stop, so a player cannot work a whole town without announcing themselves to anyone in it.
Panicking civilians drop out of the call-over entirely, and the entry coming back is what tells the
player the town has settled.

## The dialog

`shared/includes/civ_menu.hpp` holds two dialogs: `civ_dialog` on idc block **8300-8399** and the
bribe prompt on **8400-8499**, both clear of every idc the mission ships (the nearest neighbours
are the disguise panel's 8000-8203 and `fobmanager.hpp`'s lone 9745). Five framed rows — intel,
aid, toolkit, recruit, arrest — each `closeDialog 0` and `remoteExec` the work to the server.

**The client does not need the town's reputation.** The rows are the same whatever the band; only
the outcome differs, and that is rolled server-side when a row is picked. `civ_town_rep` therefore
stays server-side. The per-civilian state below is a different thing and does go out.

**Rows carry no price, and a bribe gets its own prompt.** The reaction is unknown until the roll,
so a price on the row would be a guess at a demand that arrives two thirds of the time at best.
Picking a row is free of commitment; if the roll comes back `bribe`, a second dialog states the
amount and the player answers it. `onUnload` rather than a send on each button, so closing with
Escape answers too — an offer left hanging would block the civilian silently.

The prompt carries the demand, an **In Inventory: X** readout of the player's `Money_roll` count,
and Accept / Refuse, with Accept disabled when the count falls short so an unaffordable demand
reads as unaffordable instead of failing on click. Refusing, and being unable to pay, both close
the civilian: what the prompt buys is knowing the price before losing the contact, not a free look.

### Everything the client greys, the server re-checks

Three client-side conditions decide what a row looks like, and none of them decides anything:

| Greyed when | Read from | Why the server cannot trust it |
|---|---|---|
| The player cannot afford a bribe | `magazines player` | A snapshot; in co-op two players can spend the same coins |
| The civilian is closed | the unit's own variables | Broadcast state a client machine holds a copy of |
| The player is further than conversation range | `player distance _civ` | Read once on open, so it is stale the moment they walk |
| The player has already asked a local for intel this tick | `DUWS_civ_intel_asked` on the player | Broadcast state, and a dialog left open across a tick boundary reads the value it opened with |

The deduction, the spend and the range test all stay server-side, exactly as
[`cp_economy.md`](cp_economy.md) describes for the client-side CP pre-filters.

Range is no longer greyed at all: the action that opens the menu is itself gated to the 3 m the
rows work at, so a row cannot be reached from further away than it functions. What greying is left
is defensive — a dialog already open when a flag lands still has its rows live, and the flag only
ever arrives over the wire.

### State lives on the civilian

| Variable | Locality | Purpose |
|---|---|---|
| `DUWS_civ_stopped` | broadcast | Set when call over is answered. The menu action's condition gates on it, so nothing before it exists as an entry point |
| `DUWS_civ_closed` | broadcast | Claimed when any player picks a conversational row, whatever the roll then answers |
| `DUWS_civ_arrested` | broadcast | One hands-up attempt per civilian, claimed the same way |
| `DUWS_civ_panicked` | broadcast | Set by the panic sweep, cleared after a flat 60 s. Suppresses the call-over |
| `isSurrendered` | broadcast | Held at gunpoint. Gates Search and Release, and makes the panic sweep skip them |
| `DUWS_civ_pending` | server only | `[caller, row, amount]`, written when a roll returns `bribe`, cleared when the prompt is answered |

Everything but `DUWS_civ_pending` is broadcast because it is read off the server: the dialog is
built on the client that opens it and has to know at open time which rows are dead, and the
`addAction` conditions are evaluated on every machine that carries them. A boolean pushed when it
changes beats a request-and-wait handshake in front of every open, which would either delay the
menu or pop rows grey after the player is already looking at them — the same trade as
`DUWS_intel_searched`
([`intel_system.md`](intel_system.md#the-throttle-is-per-player-and-the-attempt-is-what-it-spends)).

`DUWS_civ_stopped` is written server-side, in the call-over's own server function rather than in
the client action body that triggers it: a client that owns the flag can open the menu on a local
it never actually stopped.

`DUWS_civ_pending` is the opposite case and must not be broadcast. The Accept button sends only
*I accept* — the server reads which row and how much from its own record, so a client cannot claim
a bribe it was never offered or name its own price. It records the caller too, so in co-op a second
player cannot answer someone else's prompt.

All of it lives on the unit, so it dies with the civilian and needs no registry.

## What an accepted request pays

**Intel** hands off to `fnc_intel_payout`, the single point where intel becomes something for every
source in the mission —
[`intel_system.md`](intel_system.md#one-writer-per-reveal-flag-one-function-for-payout) owns that
contract, including which payout kinds exist. Nothing about the payout is decided here; the menu is
a faucet like the body search, and what a faucet pays is not the faucet's business. The one thing
this row must pass is an origin — the asking player's position — because the town bucket ranks by
distance.

Intel is the one row with a cap on top of the one-conversation rule: **one ask per player per
30-minute economy tick**, spent on the attempt whatever the local answers, and greyed in the menu
once spent. It rides the same clock and the same sweep as the body search
([`intel_system.md`](intel_system.md#the-throttle-is-per-player-and-the-attempt-is-what-it-spends))
rather than starting a timer of its own. Spending it on the attempt is what stops a player working
a hostile town local by local until one of them says yes — the reaction curve prices that walk in
people, and this prices it in time.

**Recruit** reaches `fnc_recruitSuccessServer`, which clears captive and broadcasts it itself.

**Aid and toolkit are one choice, not two.** A civilian answers one request and then walks, which
is what removes the old dominance without inventing a number: same price, same odds, and the only
difference left is which item the player needs. Aid drops a medikit *and three first aid kits* — a
medikit is unusable without the medic trait, so a squad without one got nothing it could spend out
of the only favour that person does.

Both items carry the same 60 s despawn. The item is handed over to be picked up, not left as a
supply dump: a persistent one would let a single friendly town furnish a squad's repairs for the
rest of the campaign.

### Arrest

The arrest row orders hands up and nothing else. It rolls no reaction and takes no bribe — a town's
opinion does not change whether a person raises their hands. It is still one of the exchanges a
civilian only has one of, so someone already talked to is spent.

**One attempt per civilian, spent on the attempt.** A dialog row is redrawn on every open, so
`DUWS_civ_arrested` is what stops the player holding the row until the 90 % surrender lands, which
would make both the reputation hit and the 10 % runner free. Same rule and same reason as the body
search (`server/misc/fnc_intel_search.sqf:8-12`).

**The town is charged −1 whether or not they comply**, because it saw the weapon raised either way.
The notification names the figure; a town already at the `-20` floor absorbs less than was asked,
and the town marker carries the standing that actually resulted.

**Two scroll actions follow a surrender, and both stay off the dialog.** They work on a civilian
standing still with their hands up, and the menu — which hides on `isSurrendered` — would have to
close, wait out the animation and reopen to offer either.

| Action | Ends in |
|---|---|
| Search | the loot table below, then a 50 % reprisal roll (`fnc_civ_search_armed`) that arms the civilian and turns them on whoever searched them |
| Release | `isSurrendered` cleared, the surrender pose ended on every machine, `PATH` re-enabled and `fnc_civ_resume` drawing a fresh walking circuit |

Release exists because `PATH` is disabled from the arrest onwards and the panic sweep refuses to
touch anyone surrendered: without it, a detainee nobody frisks — or one the reprisal roll spares —
keeps their hands up until the town is recycled. It returns no reputation. The town saw the weapon
raised, and letting the player undo that by being polite afterwards would make the arrest free.

Release also tests `side group _target == civilian`, because the reprisal moves an armed civilian
into a resistance group without clearing `isSurrendered` — otherwise the player could pacify
someone shooting at them. The reprisal roll makes the reciprocal check: it aborts if the civilian
was released during the five seconds it sleeps before firing.

### What a search turns up

One roll, half of which is nothing (`fnc_civ_search_action.sqf:31-51`):

| Band | Outcome |
|---:|---|
| 37.5 % | 1–5 `Item_Money_roll` on the ground |
| 12.5 % | exactly one item from Files / Wallet_traitor / FlashDisk / SmartPhone / MobilePhone |
| 50 % | nothing |

Three quarters of what is found is cash, so a frisk is a gamble on pocket change rather than a way
to farm intel. Phones share the pool with the documents because both exist only to be turned in at
the HQ terminal, which prices a phone above a file — a branch of their own was two names for one
outcome. The intel drop is capped at one item: three documents off one person is three searches'
worth of CP for a single frisk.

Civilians carry no coins of their own. This table is the whole of what a person is worth in cash,
so the coins in a town are a function of how many people the player is willing to hold at gunpoint.

### What a bribe costs

Per row (`fnc_civ_rowPrice`, `src/duws/server/server_fnc_init.sqf:257-266`), and **not** scaled by
reputation — the curve already carries that signal by deciding whether money is asked for at all,
so a reputation term in the amount would count it twice.

| Row | Bribe |
|---|---:|
| Intel | 3 |
| Recruit | 2 |
| Aid | 2 |
| Toolkit | 2 |
| Arrest | — |

**These are placeholders chosen to make the framework testable, not balanced figures.** They are
anchored on the black market, which is the price scale the player already reads — goggles at 1,
pistol and optic at 5 — so intel sits between the two. An unrecognised row returns a negative
price, and callers treat that as a reject: rows only ever come off the wire, so that is the
fail-closed edge for a client sending one the menu never offered.

## Open questions

- Balancing the bribe figures. What is not measured is the coin supply they meet: the HQ crate
  hands out 20 once and never refills, enemy infantry drop **0.267 coins each** (80 % carry loot,
  `floor random 3` items, one class in three) — so a thirty-enemy zone assault yields about eight
  coins — and a civilian search averages **1.1**, paid only after an arrest that costs the town a
  point of reputation. Whether that pays for a campaign of talking to towns is the first thing to
  watch.
