# CLAUDE.md

## What this project is

DUWS_T (*Dynamic Universal War System — Tactic*) is a single-player / co-op dynamic
campaign mission for Arma 3, shipped on the Altis map. It procedurally generates a
persistent war: the player captures zones, runs side missions, and calls in support
while an AI opposition reacts. It descends from Tomata's DUWS_X (originally Kibot's
DUWS), rebuilt here with reworked side missions, a revised support/economy system,
and automatic faction detection (with ALIVE support) — so it runs mod-free yet adapts
to most faction mods on the Workshop.

"Done well" means the mission stays tactically demanding (one bad move costs the
player dearly), keeps working in single-player and LAN co-op with no required mods,
and stays portable to other maps. Player-facing page:
https://steamcommunity.com/sharedfiles/filedetails/?id=3685431219

## Principles

- **No hard mod dependency.** The mission must run stand-alone. Anything that would
  force a mod, or break the faction auto-detection / ALIVE support, is the wrong call.
- **The unpacked source is the source of truth.** Edit the mission under `src/`
  and repack; never hand-edit the packed `.pbo`. Workflow: [`README.md`](README.md).
- **Mind the engine's traps.** Arma-specific behaviours that aren't visible in the SQF
  (e.g. what may be stored in the mission namespace) are collected in
  [`docs/info/arma_engine_gotchas.md`](docs/info/arma_engine_gotchas.md); check it before chasing a
  strange engine error.

## Always-loaded working rules

Voice, working method, commit style, and comment/doc style live in `docs/claude/`
and load every session:

@docs/claude/BEHAVIOUR.md
@docs/claude/CODE_COMMENTS.md
@docs/claude/DOCUMENTATION.md

## Optional: caveman plugin + statusline context bar

Two conveniences, both wired in **Claude Code user config, not this repo** — so they are per-machine and are *not* committed here. Do not look for them in the repo tree. This section is the whole recipe: a future session on any repo, any machine (Linux or macOS) can reconstruct both from what is below.

**Everything hangs off one path — the Claude config dir — which you must resolve, never hardcode.** It is `$CLAUDE_CONFIG_DIR` when that env var is set, else `$HOME/.claude`. Every path below uses that form so it is correct on any machine:

```bash
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"   # the config dir on THIS machine
```

Both steps are **idempotent — verify before you recreate.** Check `"$CFG/settings.json"` for an existing `caveman@caveman` entry and a `statusLine` command; only add what is missing. `settings.json` may already hold unrelated keys — **merge** these keys in, do not overwrite the file.

### Caveman plugin (compressed-communication skills + badge)

The `caveman` plugin supplies the `/caveman*` skills, the `cavecrew-*` agents, the SessionStart hook that sets the mode, and the badge script the context bar delegates to. Source of truth is the public GitHub repo `JuliusBrussee/caveman` — machine-independent, no local copy needed to bootstrap. Register the marketplace and enable the plugin by merging into `"$CFG/settings.json"`:

```json
{
  "extraKnownMarketplaces": {
    "caveman": { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } }
  },
  "enabledPlugins": { "caveman@caveman": true }
}
```

Equivalent interactive path: `/plugin` → add marketplace `JuliusBrussee/caveman` → enable `caveman`. On enable, Claude Code clones it under `$CFG/plugins/marketplaces/caveman/` and caches a versioned copy under `$CFG/plugins/cache/caveman/…`; the badge script (`caveman-statusline.sh`) ships inside that clone. Activate a level per session with `/caveman lite|full|ultra`; turn off with `stop caveman`.

### Statusline context bar

A custom statusline that renders the caveman badge, then a context-window fill bar (`█` used / `░` free) plus percent and token count. Wire it by merging this into `"$CFG/settings.json"` — the command uses the same `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` fallback so it resolves the script on any machine (the shell expands it at render time), rather than pinning one box's absolute path:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-faimh.sh\""
  }
}
```

Then write the script to `"$CFG/statusline-faimh.sh"` (below). Claude Code pipes session JSON on stdin each render; the script reads `transcript_path` and `model.id`, sums the last `usage` snapshot across all four token buckets (input + output + cache-read + cache-creation — cache tokens still occupy the window), divides by the model's context limit, and draws a 10-cell bar. Cell count rounds to nearest (the `+ LIMIT/2` term); any non-zero usage shows at least one cell; 0% hides the bar entirely. The script self-locates the config dir and discovers the badge script by name, so it carries no machine-specific paths:

```bash
#!/bin/bash
# Renders the caveman badge, then a context-window usage bar.
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
INPUT=$(cat)

# 1. Caveman badge — delegate to the plugin's badge script. Discover its path
#    rather than pinning a version hash, so a plugin update doesn't break it.
CAVE_SCRIPT=$(find "$CFG/plugins" -name caveman-statusline.sh 2>/dev/null | head -1)
[ -n "$CAVE_SCRIPT" ] && [ -f "$CAVE_SCRIPT" ] && bash "$CAVE_SCRIPT" </dev/null

# 2. Context-window bar.
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
MODEL_ID=$(printf '%s' "$INPUT"  | jq -r '.model.id // empty'        2>/dev/null)

# 1M-window models (tagged, or 4.x Opus/Sonnet) vs the 200k default.
case "$MODEL_ID" in
  *1m*|*1M*|*opus-4*|*sonnet-4*) LIMIT=1000000 ;;
  *)                             LIMIT=200000  ;;
esac

# Refuse a symlinked transcript: a local attacker could point it at a secret
# and have its bytes (ANSI escapes included) rendered to the terminal.
USED=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ ! -L "$TRANSCRIPT" ]; then
  USED=$(jq -c 'select(.message.usage != null) | .message.usage' "$TRANSCRIPT" 2>/dev/null \
    | tail -1 \
    | jq -r '(.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null)
fi
[ -z "$USED" ] && USED=0

PCT=$(( USED * 100 / LIMIT ))
[ "$PCT" -gt 100 ] && PCT=100
[ "$PCT" -le 0 ] && exit 0   # 0% → no bar

WIDTH=10
FILLED=$(( (USED * WIDTH + LIMIT / 2) / LIMIT ))   # +LIMIT/2 = round, not floor
[ "$FILLED" -gt "$WIDTH" ] && FILLED="$WIDTH"
[ "$FILLED" -lt 1 ] && FILLED=1                     # non-zero usage always ≥1 cell
EMPTY=$(( WIDTH - FILLED ))

COLOR=172   # 256-colour orange, matches the caveman badge
BAR=""
i=0; while [ "$i" -lt "$FILLED" ]; do BAR="${BAR}█"; i=$((i+1)); done
i=0; while [ "$i" -lt "$EMPTY"  ]; do BAR="${BAR}░"; i=$((i+1)); done

if [ "$USED" -ge 1000 ]; then TOK="$(( USED / 1000 ))k tok"; else TOK="${USED} tok"; fi
printf ' \033[38;5;%sm%s %d%% %s\033[0m' "$COLOR" "$BAR" "$PCT" "$TOK"
```

Portability notes:
- **No `chmod` needed** — `settings.json` invokes it via `bash`, so the file need not be executable.
- **`jq` is the only external dependency.** Install if absent: `apt install jq` (Debian/Ubuntu), `brew install jq` (macOS), `apk add jq` (Alpine). Without it the script fails safe — token parse yields 0, the bar hides, nothing errors.
- **Everything else is POSIX** (`bash`, `find`, `printf`, `tr`, `head`, `tail`), present on any Linux or macOS box.
