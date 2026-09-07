---
name: claude-peer-transport
description: >
  Run Claude Code as Codex's asynchronous, read-only peer for the peer-consult
  workflow. Use whenever Codex invokes $peer-consult and Claude is the other
  agent, especially when the user wants to watch Claude work in a tmux pane,
  continue the same Claude session for follow-up rounds, and detect completion
  without scraping terminal output.
---

# Claude peer transport

Use this skill only as the transport for `$peer-consult`. Follow `$peer-consult`
for the brief, discussion, stopping rule, and final synthesis.

The runner drives Claude Code through `acpx`, a client for the Agent Client
Protocol, rather than through `claude -p` directly. Sessions, completion
signalling, and permission enforcement are protocol features, so this skill no
longer parses Claude's own event schema. `acpx` must be on `PATH`; it is pinned
in mise.

## Run a round

Resolve `scripts/claude-peer` relative to this `SKILL.md`, then start Claude from
the repository it must inspect. Pass the brief through a quoted heredoc so the
shell cannot expand its contents.

```bash
bash <skill-dir>/scripts/claude-peer start --cwd "$PWD" <<'CLAUDE_PEER_BRIEF'
<complete peer-consult brief>
CLAUDE_PEER_BRIEF
```

The command returns JSON with `job_id`, `session`, `mode`, and `pane_id`.
Inside tmux, `mode` is `tmux` and Claude streams into a visible pane. Outside
tmux, it runs headlessly and records the same artifacts. The acpx session name is
derived from the job ID rather than scraped from the stream, so a round stays
addressable even if it dies early.

Poll in bounded 30-second intervals so you can keep the user informed during a
long run:

```bash
bash <skill-dir>/scripts/claude-peer wait <job-id> 30
```

Codex does not deliver an independent completion notification when a yielded
shell process exits. If the shell call returns a session or process handle
before `wait` prints JSON, resume that same call until it exits. Do not detach
`wait`, leave it orphaned, or start concurrent waits for the same round.

When `wait` returns `running`, call it again. Treat `succeeded` as complete.
Treat `failed` or `lost` as a failed peer round and report the returned paths
or error. Read the peer's answer only after completion:

```bash
bash <skill-dir>/scripts/claude-peer result <job-id>
```

Do not scrape the tmux pane. The completion contract is the ACP stop reason
(`end_turn`) plus a non-empty answer. Note that `exit_code` 5 on an otherwise
succeeded round means the peer reached for an edit and was denied; the advice is
still usable, and it is worth mentioning to the user.

The pane shows text arriving in chunks as Claude writes, with tool calls listed
by kind and title. Thinking is dimmed and is deliberately excluded from `result`.

## Run several peers at once

Jobs are fully independent: separate state directories, separate acpx sessions,
separate results. Starting several is safe, but poll each job independently and
never run overlapping waits for one job.

The runner places each job where it stays readable. It splits a sibling pane
while both halves would keep at least 80 columns, and opens a separate tmux
window once they would not. So the first peer usually lands beside you and the
rest land in their own windows. Tell the user which windows to look at instead
of assuming everything is visible at once.

## Continue the same session

When another round adds value under `$peer-consult`, resume the existing job:

```bash
bash <skill-dir>/scripts/claude-peer follow-up <job-id> <<'CLAUDE_PEER_FOLLOW_UP'
<pushback, question, or request for verification>
CLAUDE_PEER_FOLLOW_UP
```

Then poll with bounded `wait` calls and read `result` again. `follow-up` prompts
the same named acpx session, which keeps the conversation. Never start a fresh
job to simulate continuity.

## Boundaries

- Let the runner enforce read-only access. Two layers do it: acpx denies every
  tool class that is not explicitly allowed, and Claude runs in plan mode with a
  per-job settings file that denies the editing tools and any MCP tool, and
  sandboxes the working tree against writes. Writes fail at the OS level, not at
  a prompt.
- The settings file reaches Claude through `CLAUDE_CODE_EXECUTABLE`, because the
  ACP adapter takes no settings flag of its own. Do not switch this to
  `CLAUDE_CONFIG_DIR`: that loses the credentials and the adapter fails with
  `AUTH_REQUIRED`.
- The deny policy does not depend on there being no TTY, which matters because
  the peer runs in a tmux pane. Do not replace it with
  `--non-interactive-permissions` alone, and do not pass `--approve-all`.
- Let tmux close the pane after Claude finishes. Read completed output through
  `result`; the raw ACP stream remains available at the path returned by `wait`.
- Do not substitute a Codex subagent. Native Codex subagents are useful, but
  they are not a cross-model Claude consultation.
- Stop conferring when `$peer-consult` says the discussion is done.
