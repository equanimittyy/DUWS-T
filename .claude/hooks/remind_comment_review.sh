#!/bin/sh
# PreToolUse(Bash) gate on git commit: denies once -- listing the comment lines the commit
# adds -- then allows an identical retry, so each distinct batch of added comments gets one
# forced review (a prompt to look, not a verdict; a script cannot grade a comment). Keyed on
# HEAD + a hash of the flagged lines: a re-run of the same set passes, but a changed or fresh
# batch at the same HEAD re-triggers, so trimming during the sweep costs one more prompt and a
# different commit cannot ride a spent marker through. Comment syntax is per file type, not
# guessed from text, so a Markdown heading, CSS colour, or shell parameter expansion is not
# mistaken for a comment; unknown extensions are skipped.

input=$(cat 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
# Loose match on purpose: `git -C <dir> commit` and friends must gate too. A false match (a
# command that merely mentions git ... commit) costs one diff check that finds no comments.
case "$cmd" in
  *git*commit*) ;;
  *) exit 0 ;;
esac

stylefor() {
  case "$1" in
    *.c|*.h|*.cpp|*.hpp|*.cc|*.cxx|*.hh|*.cs|*.java|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|\
*.go|*.rs|*.swift|*.kt|*.kts|*.php|*.scala|*.dart|*.sqf|*.glsl|*.hlsl|*.proto|\
*.scss|*.less|*.sass) echo slash ;;
    *.css) echo block ;;
    *.py|*.rb|*.sh|*.bash|*.zsh|*.ksh|*.pl|*.pm|*.r|*.yaml|*.yml|*.toml|*.tf|*.tfvars|\
*.nim|*.ex|*.exs|*.cr|*.jl|*.conf|*.cfg|*.env|*.ps1|*.psm1) echo hash ;;
    Makefile|makefile|GNUmakefile|*.mk|Dockerfile|*.dockerfile|.gitignore|.dockerignore|\
.gitattributes) echo hash ;;
    *.sql|*.lua|*.hs|*.elm|*.adb|*.ads) echo dash ;;
    *.html|*.htm|*.xhtml|*.xml|*.svg|*.vue|*.svelte|*.md|*.markdown) echo html ;;
    *.lisp|*.cl|*.clj|*.cljs|*.cljc|*.el|*.scm|*.rkt|*.asm|*.s) echo semi ;;
    *.ini) echo semihash ;;
    *) echo "" ;;
  esac
}

AWK_PROG='
  /^\+\+\+/ { next }
  /^---/    { next }
  /^@@ / {
    p = index($0, "+"); s = substr($0, p + 1)
    split(s, a, /[ ,]/); ln = a[1] + 0; next
  }
  /^-/ { next }
  /^\+/ {
    added = substr($0, 2)
    c = 0
    if (style ~ /slash/) {
      if (added ~ /^[ \t]*\/\//)      c = 1
      else if (added ~ /^[ \t]*\/\*/) c = 1
      else if (added ~ /^[ \t]*\*/)   c = 1
      else { b = added; gsub(/:\/\//, "", b); if (b ~ /\/\//) c = 1 }
    }
    if (!c && style ~ /block/) {
      if (added ~ /^[ \t]*\/\*/)    c = 1
      else if (added ~ /^[ \t]*\*/) c = 1
      else if (added ~ /\/\*/)      c = 1
    }
    if (!c && style ~ /hash/) {
      if (added ~ /^[ \t]*#!/) c = 0
      else if (added ~ /^[ \t]*#/) c = 1
      else if (added ~ /[ \t]#/ && added !~ /#[{(]/ && added !~ /\$\{/) c = 1
    }
    if (!c && style ~ /dash/) {
      if (added ~ /^[ \t]*--/)              c = 1
      else if (added ~ /[ \t]--[ \t]/)      c = 1
    }
    if (!c && style ~ /html/) {
      if (added ~ /<!--/) c = 1
    }
    if (!c && style ~ /semi/) {
      if (added ~ /^[ \t]*;/)      c = 1
      else if (added ~ /[ \t];/)   c = 1
    }
    if (c) printf "  %s:%d  %s\n", file, ln, added
    ln++
  }
'

lines=$(git diff --cached --name-only --diff-filter=d 2>/dev/null | while IFS= read -r f; do
  style=$(stylefor "$f")
  [ -z "$style" ] && continue
  git diff --cached --unified=0 --no-color -- "$f" 2>/dev/null \
    | awk -v style="$style" -v file="$f" "$AWK_PROG"
done)

[ -z "$lines" ] && exit 0

gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null)
head=$(git rev-parse HEAD 2>/dev/null)
marker="$gitdir/comment_review_denied_head"
key="$head:$(printf '%s' "$lines" | cksum | awk '{print $1}')"

if [ -n "$head" ] && [ "$(cat "$marker" 2>/dev/null)" = "$key" ]; then
  exit 0
fi

printf '%s' "$key" > "$marker" 2>/dev/null

reason="Comment-review gate: this commit ADDS the comment lines below. Default is NO comment -- most of these should be deleted, not kept. A line survives only if it carries a why the code cannot show (a load-bearing invariant, rejected alternative, security/concurrency rationale, non-obvious encoding, or a bug's failure mode) AND a clearer name or smaller function could not replace it. Cut everything that restates code, narrates a branch, or recounts history, then re-run the commit. Changing which comments you add re-triggers this once; an identical re-run passes.

$lines"

REASON="$reason" python3 -c 'import json,os,sys; sys.stdout.write(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":os.environ["REASON"]}}))' 2>/dev/null
exit 0
