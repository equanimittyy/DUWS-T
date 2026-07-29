# Test suite

Automated checks for the mission source, under `tests/` (outside `src/` so `repack.cmd`
never sweeps them into the `.pbo`). Run everything with:

```sh
bash tests/run.sh            # lint needs only python3; unit tests need sqf-vm
bash tests/run.sh --no-unit  # lint only, where sqf-vm is unavailable
```

## Layout

```text
tests/
  run.sh              run the whole suite
  get_sqfvm.sh        fetch the SQF VM used by the unit tests
  lint/               static analysis (python only, no Arma, no VM)
    check_syntax.py     bracket / string / comment balance
    check_paths.py      execVM & #include paths resolve to real files
    syntax_baseline.txt, paths_baseline.txt   known pre-existing issues to tolerate
  unit/               unit tests, run in the SQF VM
    run.sh, harness.sqf, cases.sqf, functions.txt
  lib/extract_fn.py   pulls a function's source out for a unit test

(the sqf-vm binary itself lives at repo-root tools/sqfvm — git-ignored, per-environment)
```

## What each check catches

| Check | Needs | Catches |
|---|---|---|
| `lint/check_syntax.py` | python3 | Unbalanced `()`/`[]`/`{}`, unterminated strings or comments |
| `lint/check_paths.py` | python3 | `execVM`/`preprocessFile`/`#include` paths that don't resolve to a real file (case-insensitively) |
| `unit/` | sqf-vm | Logic regressions in pure helper functions |

## Why static analysis plus only a thin unit layer

SQF has no compiler and cannot run outside Arma, which bounds what is testable:

- **The lint checks are static** (pure python, run in the devcontainer/CI).
  `check_paths.py` is the highest-value check here — it is exactly what flags a
  mis-rewritten path from a folder move or rename. A path can be *valid SQF and still
  wrong*; only a resolver, not a syntax parser, catches that.
- **The unit tests execute only pure functions.** ~95% of the mission reads
  `CfgVehicles`, calls `BIS_fnc_*`, or spawns units, none of which exist in the VM, so
  the covered surface is deliberately small (see `unit/functions.txt`).
- **Neither layer tests runtime behavior** — faction generation, zone spawning, save
  state. That still needs an in-game playthrough (`repack.cmd` → launch). These checks
  are a fast pre-filter, not a replacement for the smoke test.

## sqf-vm

The unit tests use [`https://github.com/SQFvm/runtime`](https://github.com/SQFvm/runtime). `get_sqfvm.sh`
fetches the pinned **1.3.2 Linux** build into the repo-root `tools/` (git-ignored, per-environment
like `tools/PBO Manager/`): it links against an older glibc so it runs in the devcontainer,
where the current official build needs glibc 2.38+. Because 1.3.2 predates the modern `#`
selector the mission uses, we do **not** use its parser for the syntax check (it
false-positives) — the python balancer is used instead. It also returns an empty array for
`array select [start]` with the count omitted, so pass the count explicitly in code you
intend to exercise here.

The unit tests avoid drift by **extracting the function under test from real source at run
time** (`lib/extract_fn.py`) rather than copying it, so they always exercise current code.

## Baselines (regression-gating)

The lint checks gate on *new* problems, tolerating pre-existing ones listed in:

- `lint/paths_baseline.txt` — 6 already-dead script references (e.g. `player_markers.sqf`).
- `lint/syntax_baseline.txt` — 2 vendored VCOM files with a benign trailing `/*` block.

Remove an entry once the underlying issue is fixed; a genuinely new failure is never masked.

## Adding checks

- **Lint:** nothing to do — both checks walk `src/` automatically.
- **Unit:** add `path/from/src::FunctionName` to `unit/functions.txt` and assertions to
  `unit/cases.sqf`. Only genuinely pure helpers (no config / `BIS_fnc_` / spawning) can run
  in the VM.

## Testing join-in-progress

**A second player joining a LAN host is a real JIP client**, and that is the simplest way to
exercise the queue: build the state, have them connect, look at what they receive. The host is
not one — it is server and client in a single process and never joins anything.

Two things that setup cannot give you. You cannot test alone, because quitting as host ends the
mission rather than leaving it running to rejoin. And a host masks every locality fault that only
appears once server and client are separate machines, which is why a listen server proves nothing
about dedicated-server support
([`server_client_authority.md`](server_client_authority.md#dedicated-server-compatibility)) —
worth caring about here because much of what was keyed targets `[0,-2] select isDedicated` from
server-side code.

Both are solved by a local dedicated server plus one client:

1. `repack.cmd` → `DUWS_T.altis.pbo` at the repo root. Copy it into the dedicated server's
   `mpmissions/`.
2. Start Arma 3 Dedicated Server (a separate Steam tool) and select the mission.
3. Connect a normal client to `127.0.0.1`. **This first client is the game master**: pre-play
   configuration is authored on a client, so nothing generates until someone runs the campaign
   menu. Wait for `[DUWS][INFO][SRV][ZONES]` to stop before treating the campaign as built.

**A reconnecting player is a JIP client too**, which is what makes this testable by one person: the
mission keeps running on the dedicated server while you are gone, so disconnect and rejoin, and
the queue replays to you exactly as it would to a stranger. Build the state a check needs, rejoin,
then look. Two clients are only needed where one player must act while another watches.

Each machine writes its own `.rpt` — the server's and the client's are separate files, and the
`SRV` / `CLI` machine tag in each line says which half emitted it. `enableDebugConsole = 1`, so
the console is available for inspecting state directly; `duws_log_level = 4` there raises the
level to DEBUG from that point on (there is no lobby parameter for it despite `INIT.sqf` looking
for one, so the default is 3).

The checklist of what to verify is in
[`../../KNOWN_ISSUES.md`](../../KNOWN_ISSUES.md#jip-queue-keyed-not-yet-exercised).

## Runtime logging: reading the `.rpt`

Neither lint nor the unit layer can see a running mission. Arma writes one `.rpt` per launch
(`%LOCALAPPDATA%\Arma 3\` on Windows; a dedicated server writes its own), and
`src/duws/shared/functions/fnc_log_init.sqf` gives that log a structure worth grepping.

`fnc_log` emits a fixed shape, `[DUWS][<level>][<machine>][<tag>] <message>`:

| Field | Values |
|---|---|
| level | `ERROR` `WARN` `INFO` `DEBUG`, gated by `duws_log_level` (default 3 = INFO; set it to 4 before init for DEBUG) |
| machine | `SRV` dedicated, `HOST` server-and-player, `CLI` player, `HC` headless — a hosted session interleaves two of these in one file |
| tag | one of the fixed set below |

Nothing in `src/duws/` calls `diag_log` directly; a raw call is a bug, because it lands in the
`.rpt` outside this shape and every grep below misses it. `DUWS` is the outer prefix `fnc_log`
emits, so it must never be used as a tag — `[DUWS][INFO][SRV][DUWS]` breaks tag filtering.

| Tag | Covers |
|---|---|
| `BOOT` | server/client init, HQ placement and construction, setup handshake |
| `SETUP` | the per-global setup snapshot at the callsign screen |
| `REGISTRY` | the compiled-empty self-check in `server_fnc_init.sqf` |
| `FACTION` | BLUFOR/OPFOR resolution, custom and autodetected factions |
| `ZONES` | generation, registration, capture and loss |
| `MISSION` | side-mission start, reward, cleanup, slot release, dynamic missions |
| `WARCOM` | OPFOR assault targeting, QRF, reinforcement |
| `ECON` | every CP / AP / reputation mutation, with the reason that caused it |
| `SUPPORT` | FOB, MHQ, repair and recycle stations, killhouse |
| `CIV` | civilian presence, recruitment, reputation events |
| `WBK` | the WBK survivor system |
| `GEAR` | arsenal scans, loadout collection, disguise |
| `INTRO` | the opening helicopter sequence |
| `HALO` | AI HALO insertion |
| `MARKERS` | the vendored unit-marker pack |

Useful greps: `\[DUWS\]\[ERROR\]` for failures only, `\[DUWS\]\[[A-Z]*\]\[HOST\]` to separate
the host's two halves, `\[DUWS\]\[.*\]\[ZONES\]` to follow campaign generation end to end,
`\[DUWS\]\[INFO\]` alone to read a whole campaign as a timeline.

### Hot paths are DEBUG, and the guard goes at the call site

`fnc_log` checks the level *after* its arguments are built, so `format` has already run and
allocated by the time a `DEBUG` line is discarded. Anything on a per-unit, per-frame or
per-trigger path must therefore test the level itself:

```sqf
if (duws_log_level >= 4) then {
    ["DEBUG", "CIV", format ["spawn lock acquired for %1", _locIndex]] call fnc_log;
};
```

The civilian handlers, the QuickChange arsenal scan and the disguise monitor are written this
way because they fire for the whole session; their guard failures stay `ERROR` and ungated.

### Why the wait wrapper exists

An unbounded `waitUntil {cond}` whose condition never comes true produces **no output at
all** — the campaign stops and the only evidence is a later log line that never appears.
`fnc_waitLogged` takes a tag, a label, a condition and a timeout; it warns every 10 s naming
the condition it is still blocked on, and returns `false` at the timeout rather than hanging.

It never aborts its caller: a slow-but-working wait on a loaded host must not kill a campaign
in progress, so the call site decides. Boot preconditions wrap it in
`while {!([...] call fnc_waitLogged)} do {}`, which re-waits forever — loud, but it will never
let the server proceed without an HQ position or a faction table.

`fnc_waitLogged` sleeps, so it is scheduled-only: callers must be inside `spawn`/`execVM`,
never `call`.

### The registry self-check

`preprocessFile` on a path that does not resolve returns `""`, which compiles to an empty `{}`
and then no-ops at every call site with no error anywhere. The end of `server_fnc_init.sqf`
scans every `fnc_*` in the mission namespace for that empty-body signature and logs
`[DUWS][ERROR][…][REGISTRY] … compiled EMPTY`. A mistyped or moved script path is otherwise
invisible until some later stage silently never happens.
