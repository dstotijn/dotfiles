#!/usr/bin/env bash
# Reminds a fresh session to recall engineering memory for the issue it is on.
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

BANK=engineering  # keep in sync with the bank in AGENTS.md

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

# Issue work is identified by a tracker ID in the branch name. Anything else
# (main, a dotfiles branch, a scratch dir) is not issue work: stay silent.
id=$(printf '%s' "$branch" | grep -oiE '[a-z]{2,}-[0-9]+' | head -1 | tr '[:lower:]' '[:upper:]')
[ -n "$id" ] || exit 0

# The worktree directory is named after the branch, so it is useless as a
# subsystem key. Use the repository instead (git-common-dir resolves to the main
# checkout from inside a worktree) and let the agent supply the real subsystem.
repo=$(basename "$(dirname "$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null)
[ -n "$repo" ] && [ "$repo" != "." ] || repo=$(basename "$cwd")

cat <<TXT
Engineering memory: this session is on $id (branch $branch).

Before reading much code, recall prior engineering memory for it. Run both; they
answer different questions:
  hindsight -o json memory recall $BANK "$id prior work, decisions, and blockers"
  hindsight -o json memory recall $BANK "<subsystem> known pitfalls, constraints, and confirmed fixes"

Replace <subsystem> with the code path or component the issue actually touches (this
is the $repo repo); do not run it with the placeholder. Treat results as
fallible and possibly stale: the repository, Linear, and the live system outrank
memory, so verify before acting on a recalled claim. If Hindsight is unavailable,
continue without memory and say so once; do not start it.
TXT
