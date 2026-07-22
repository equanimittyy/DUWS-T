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

The unit tests use [`SQFvm/runtime`](https://github.com/SQFvm/runtime). `get_sqfvm.sh`
fetches the pinned **1.3.2 Linux** build into the repo-root `tools/` (git-ignored, per-environment
like `tools/PBO Manager/`): it links against an older glibc so it runs in the devcontainer,
where the current official build needs glibc 2.38+. Because 1.3.2 predates the modern `#`
selector the mission uses, we do **not** use its parser for the syntax check (it
false-positives) — the python balancer is used instead.

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
