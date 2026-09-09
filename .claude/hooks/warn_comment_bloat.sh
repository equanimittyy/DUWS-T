#!/bin/sh
# PreToolUse(Bash) nudge: flag newly-added SQF comment bloat in a staged commit.
# Non-blocking. Judges the staged DIFF, not whole-file density, so touching a
# legacy-heavy file does not trip it; only new comment prose does. On a hit it
# emits hookSpecificOutput.additionalContext (reaches the committing agent) and
# a human-readable line on stderr; it never sets a permission decision.

input=$(cat 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$dir" ] && cd "$dir" 2>/dev/null || exit 0

MAX_RUN=4
MAX_ADDED=15

files=$(git diff --cached --name-only --diff-filter=ACM -- '*.sqf' 2>/dev/null | grep -v '/factions/')
[ -z "$files" ] && exit 0

report=""
for f in $files; do
  stats=$(git diff --cached -- "$f" | awk '
    /^\+\+\+/ { next }
    /^\+/ {
      line = substr($0, 2)
      t = line; gsub(/[ \t\r]/, "", t)
      if (t == "") { run = 0; next }
      if (line ~ /^[ \t]*\/\//) { addc++; run++; if (run > maxrun) maxrun = run }
      else { run = 0 }
      next
    }
    { run = 0 }
    END { printf "%d %d", addc + 0, maxrun + 0 }
  ')
  addc=${stats% *}; maxrun=${stats#* }
  if [ "$maxrun" -gt "$MAX_RUN" ] || [ "$addc" -gt "$MAX_ADDED" ]; then
    report="${report}  ${f}: +${addc} comment lines, longest new run ${maxrun}
"
  fi
done

[ -z "$report" ] && exit 0

msg="Comment-bloat nudge: this commit adds heavy new comments to:
${report}CLAUDE.md says comments explain WHY, never WHAT (less is more). Before committing, sweep these files and cut lines that restate the code, narrate a branch, or set the scene; keep only a why the code cannot carry."

printf '%s\n' "$msg" >&2
MSG="$msg" python3 -c 'import json,os,sys; sys.stdout.write(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))' 2>/dev/null
exit 0
