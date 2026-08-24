---
name: handoff
description: Create a concise handoff for another agent or later session. Use only when the user explicitly invokes `$handoff` or `/handoff`, optionally followed by `to worklog`; never invoke it automatically.
---

# Handoff

Compact the current conversation so a fresh agent can continue the work. Point
to existing artifacts instead of copying them.

## Destination

- If the arguments start with `to worklog`, require a Git repository and write
  to `<repo-root>/tmp/WORKLOG.md`. Stop if no repository root can be resolved.
- Otherwise, write a uniquely named Markdown file in the operating system's
  temporary directory. Do not accept arbitrary output destinations.

Treat any remaining arguments as the next session's focus. Infer the focus from
the conversation when none is given.

## Capture

Inside a Git repository, use fresh read-only checks to confirm the repository
root, worktree path, branch, uncommitted changes, and relevant recent commits.
Use the conversation for goals and decisions, but the repository for its current
state. Do not run tests or validation; report checks already completed and call
out important missing or stale validation.

Always include `Current state` and `Next steps`. Add `Decisions`, `Validation`,
`Relevant artifacts`, and `Suggested skills` only when useful. Suggest a skill
only when invoking it would materially help.

Reference existing specs, plans, ADRs, issues, commits, diffs, and files by path,
URL, or identifier. Distinguish facts from hypotheses. Redact credentials,
tokens, private keys, and secret values. Keep names, identifiers, and local paths
when they are needed to continue the work.

## Worklog

Read the existing worklog before editing it and preserve every entry. If it is
missing, create it with `# Work log`; if it lacks that title, add it without
discarding content.

Add every new handoff directly below the title as
`## YYYY-MM-DD HH:mm — <short topic>` in local time. Keep newest entries first,
including repeated handoffs for the same task. Do not commit the worklog unless
the user explicitly asks.

Report the output path and summarize the handoff in one sentence.
