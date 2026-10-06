---
name: codex-peer-transport
description: >
  Drive an interactive, read-only Codex peer in a dedicated Herdr tab for the
  peer-consult workflow. Use whenever an agent invokes peer-consult with Codex
  as the other harness, including same-session follow-up rounds.
---

# Codex peer transport

Use this skill only as the transport for `peer-consult`. Follow `peer-consult`
for the brief, discussion, stopping rule, and final synthesis. Load the `herdr`
skill before issuing control commands; its live CLI discovery and safety rules
apply. Peer consultation uses a dedicated tab, not Herdr's usual sibling-pane
layout.

## Start the peer

Verify `HERDR_ENV=1`. Outside Herdr, report that the requested transport is
unavailable and stop; do not fall back to tmux, acpx, a headless command, or a
native subagent.

Create one background tab in the caller's workspace and current working
directory. Keep the user's focus unchanged:

```sh
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label codex-peer --no-focus
```

Record `.result.tab.tab_id` and `.result.root_pane.pane_id` from the response.
Never derive IDs from examples or sidebar order. Choose an unused live agent
name such as `codex-peer-<short-suffix>`.

The read-only shell sandbox does not constrain MCP tools. List the configured
MCP server names without exposing their settings:

```sh
codex mcp list --json | jq -r '.[].name'
```

If discovery fails, stop rather than launching with unknown tool access. For
every listed name, append `-c 'mcp_servers.<name>.enabled=false'` to the native
arguments below. An empty `mcp_servers={}` override does not clear inherited
servers. With no configured servers, no extra arguments are needed.

```sh
herdr agent start <unique-peer-name> --kind codex --pane <returned-pane-id> -- --sandbox read-only --ask-for-approval never --no-alt-screen <MCP-disable-args>
```

If startup fails, inspect the recorded pane with `pane read`; the agent name
may not exist yet. Do not launch a duplicate or relax permissions to bypass a
startup error. Resolve the observed error before submitting the brief.

Do not weaken the sandbox or enable approvals. Tell the peer that it advises
only: no file changes, external mutations, delegation, or further peer launches.
Provide the complete task-specific brief and your current position; inherited
instructions and skills need not be pasted.

## Confer in the same session

Submit the brief as one literal argument through the agent surface, not raw
pane input. Quote it without shell expansion:

```sh
herdr agent prompt <unique-peer-name> '<complete brief>' --wait --timeout 120000
herdr agent read <unique-peer-name> --source recent-unwrapped --lines 120
```

The wait observes activity followed by a settled state; it is not proof that a
usable answer exists. Read and evaluate the actual response. If the shell tool
supports asynchronous completion, background the waiting call once and keep
working; otherwise retain and resume the same process handle until it exits.
Do not start overlapping waits or repeatedly poll.

After a timeout, stalled prompt, or blocked state, inspect `agent get` and
`agent read` before acting. A failed wait does not prove submission failed. If
still working, use `agent wait` to finish the existing round rather than
resubmitting. Never answer an approval or question UI on the user's behalf.

Send follow-ups with `agent prompt` to the same live agent name and pane. Keep
that tab open across rounds; a newly launched peer is not session continuity.
If a larger read cannot recover the answer, ask for a concise restatement in
the same session. Do not ask the read-only peer to write an output file.

## Finish

Report the peer's contribution and your own decision under `peer-consult`.
Then close only the tab you created, using its recorded ID:

```sh
herdr tab close <returned-tab-id>
```

Do not close another agent's tab or leave a peer running after the consultation
is finished. For multiple explicitly requested peers, give each its own tab,
unique agent name, and conversation.
