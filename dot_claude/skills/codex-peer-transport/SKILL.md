---
name: codex-peer-transport
description: >
  Run Codex as Claude Code's asynchronous, read-only peer for the peer-consult
  workflow. Use whenever Claude Code invokes $peer-consult and Codex is the other
  agent, especially when the user wants to watch Codex work in a tmux pane,
  continue the same Codex session for follow-up rounds, and detect completion
  without scraping terminal output.
---

# Codex peer transport

Use this skill only as the transport for `$peer-consult`. Follow `$peer-consult`
for the brief, discussion, stopping rule, and final synthesis.

The runner drives Codex through `acpx`, a client for the Agent Client Protocol,
rather than through `codex exec` directly. Sessions, completion signalling, and
permission enforcement are protocol features, so this skill no longer parses
Codex's own event schema. `acpx` must be on `PATH`; it is pinned in mise.

## Run a round

Resolve `scripts/codex-peer` relative to this `SKILL.md`, then start Codex from
the repository it must inspect. Pass the brief through a quoted heredoc so the
shell cannot expand its contents.

```bash
bash <skill-dir>/scripts/codex-peer start --cwd "$PWD" <<'CODEX_PEER_BRIEF'
<complete peer-consult brief>
CODEX_PEER_BRIEF
```

The command returns JSON with `job_id`, `session`, `mode`, and `pane_id`.
Inside tmux, `mode` is `tmux` and Codex streams into a visible pane. Outside
tmux, it runs headlessly and records the same artifacts. Unlike the old
transport, `session` is known immediately: the acpx session name is derived from
the job ID rather than scraped from the stream, so a round is addressable even
if it dies early.

Then wait exactly once, as a **backgrounded** Bash call:

```bash
bash <skill-dir>/scripts/codex-peer wait <job-id>
```

`wait` blocks until the round reaches a terminal state and then exits, so
backgrounding it gets you a single completion notification and costs no turns
while Codex works. A round takes minutes, so do not poll:

- Do not call `wait` in the foreground. Foreground Bash calls are killed at 120s
  and silently orphaned into a background task, which wastes the turn and leaves
  a dangling notification.
- Do not pass a timeout. The default already outlasts any real round.
- Do not loop. One `wait` per round is the whole contract.

Do something useful while it runs, or tell the user you are waiting. When the
notification arrives, treat `succeeded` as complete, and `failed` or `lost` as a
failed peer round to report with the returned paths or error. Read the peer's
answer only after completion:

```bash
bash <skill-dir>/scripts/codex-peer result <job-id>
```

Do not scrape the tmux pane. The completion contract is the ACP stop reason
(`end_turn`) plus a non-empty answer. Note that `exit_code` 5 on an otherwise
succeeded round means the peer reached for an edit and was denied; the advice is
still usable, and it is worth mentioning to the user.

The pane shows text arriving in chunks as Codex writes, with tool calls listed
by kind and title. Reasoning is dimmed and is deliberately excluded from
`result`.

## Run several peers at once

Jobs are fully independent: separate state directories, separate acpx sessions,
separate results. Starting several is safe, and each one needs its own
backgrounded `wait`.

The runner places each job where it stays readable. It splits a sibling pane
while both halves would keep at least 80 columns, and opens a separate tmux
window once they would not. So the first peer usually lands beside you and the
rest land in their own windows. Tell the user which windows to look at instead
of assuming everything is visible at once.

## Continue the same session

When another round adds value under `$peer-consult`, resume the existing job:

```bash
bash <skill-dir>/scripts/codex-peer follow-up <job-id> <<'CODEX_PEER_FOLLOW_UP'
<pushback, question, or request for verification>
CODEX_PEER_FOLLOW_UP
```

Then background one `wait` and read the `result` again. `follow-up` prompts the
same named acpx session, which keeps the conversation. Never start a fresh job to
simulate continuity.

## Boundaries

- Let the runner enforce read-only access. Two layers do it: acpx denies every
  tool class that is not explicitly allowed, and Codex's own sandbox is pinned to
  `read-only` with approvals off, which overrides a permissive
  `~/.codex/config.toml`. The peer can read files and run read-only shell
  commands; writes fail at the OS level.
- The deny policy does not depend on there being no TTY, which matters because
  the peer runs in a tmux pane. Do not replace it with
  `--non-interactive-permissions` alone, and do not pass `--approve-all`.
- Let tmux close the pane after Codex finishes. Read completed output through
  `result`; the raw ACP stream remains available at the path returned by `wait`.
- Do not substitute the `codex:rescue` subagent or the `codex` MCP tool. Both are
  useful, but neither gives the user a live pane nor pins the discussion to one
  addressable session across rounds.
- Stop conferring when `$peer-consult` says the discussion is done.
