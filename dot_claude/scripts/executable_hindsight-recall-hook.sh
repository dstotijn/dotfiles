#!/usr/bin/env bash
# Tells a fresh session which memory banks apply here and, on issue work, to
# recall before reading much code.
#
# Emits a directive, not recall results: memory is fallible, and results injected
# into the system prompt would read as authoritative and outrank the repo. This
# makes no Hindsight calls of its own.
#
# Output is plain text, not JSON. Both Claude Code and Codex take a SessionStart
# hook's plain stdout as added context, and the two disagree on JSON shape
# (Claude wants a flat additionalContext, Codex wants it nested under
# hookSpecificOutput); emitting both at once is rejected as invalid by Claude.
#
# Registered on SessionStart in ~/.claude/settings.json and ~/.codex/hooks.json.
# Both use the same event names and payload field names.
#
# Never exits non-zero and never writes anything but the directive to stdout.

GLOBAL_BANK=global  # keep in sync with the banks in AGENTS.md

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

# A repository opts into a project bank through its local Git config, which no
# worktree commits: git config hindsight.bank <bank>. Without one, only the
# global bank applies, and the skill decides when it is worth a recall.
bank=$(git -C "$cwd" config --get hindsight.bank 2>/dev/null)
[ -n "$bank" ] || exit 0

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# Issue branches start with the tracker ID, for example abc-123-fix-login.
id=$(printf '%s' "$branch" | grep -oiE '^[a-z][a-z0-9]{1,9}-[0-9]+' | tr '[:lower:]' '[:upper:]')

if [ -z "$id" ]; then
  cat <<TXT
Engineering memory: this repository's Hindsight bank is $bank; cross-project
knowledge is in $GLOBAL_BANK. Recall from them only when a task may depend on past
decisions, workarounds, or failures.
TXT
  exit 0
fi

cat <<TXT
Engineering memory: this session is on $id (branch $branch). This repository's
Hindsight bank is $bank; cross-project knowledge is in $GLOBAL_BANK.

Before reading much code, recall prior engineering memory for it. Run both; they
answer different questions:
  hindsight -o json memory recall $bank "$id prior work, decisions, and blockers" --tags issue:$id --max-tokens 2048
  hindsight -o json memory recall $bank "<subsystem> known pitfalls, constraints, and confirmed fixes" --max-tokens 2048

Replace <subsystem> with the code path or component the issue actually touches; do
not run it with the placeholder. Treat results as fallible and possibly stale: the
repository, the issue tracker, and the live system outrank memory, so verify before
acting on a recalled claim. If Hindsight is unavailable, continue without memory
and say so once; do not start it.
TXT
