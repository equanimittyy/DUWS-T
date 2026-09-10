#!/bin/sh
# PreToolUse(Bash) reminder, fired on every git commit: sweep comments first.
# Non-blocking. Emits hookSpecificOutput.additionalContext (reaches the committing
# agent) and a human-readable line on stderr; it never sets a permission decision.

input=$(cat 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

msg="Comment-review reminder: CLAUDE.md defaults to NO comment -- one earns its line only by carrying a why the code cannot show (never what it does or how it got here). Less is more: one line where you can, two if you must, three to four only for a critical edge case. Before committing, sweep each touched file and drop any comment that restates the code, narrates a branch, or recounts history; keep only a why."

printf '%s\n' "$msg" >&2
MSG="$msg" python3 -c 'import json,os,sys; sys.stdout.write(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))' 2>/dev/null
exit 0
