---
name: claude-peer-transport
description: >
  Drive an interactive, read-only Claude Code peer in a dedicated Herdr tab for
  the peer-consult workflow. Use whenever an agent invokes peer-consult with
  Claude as the other harness, including Codex or OMP and same-session follow-ups.
---

# Claude peer transport

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
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label claude-peer --no-focus
```

Record `.result.tab.tab_id` and `.result.root_pane.pane_id` from the response.
Never derive IDs from examples or sidebar order. Choose an unused live agent
name such as `claude-peer-<short-suffix>`.

Start Claude with only file-reading, searching, and web-reading tools. Plan mode
alone is not a write boundary, especially when a shell wrapper adds permission
bypass. The explicit tool allowlist omits shell execution and editing, and the
strict empty MCP configuration, explicit MCP denial, and disabled Chrome
integration remove external mutation tools:

```sh
herdr agent start <unique-peer-name> --kind claude --pane <returned-pane-id> -- --permission-mode plan --tools Read,Glob,Grep,WebSearch,WebFetch --disallowedTools 'mcp__*' --strict-mcp-config --mcp-config '{"mcpServers":{}}' --no-chrome
```

If startup fails, inspect the recorded pane with `pane read`; the agent name
may not exist yet. Do not launch a duplicate or relax permissions to bypass a
startup error. Resolve the observed error before submitting the brief.

Keep these restrictions on every launch. This peer can inspect code but cannot
run shell commands or tests; the driver performs runtime checks. Tell the peer
that it advises only: no file changes, external mutations, delegation, or
further peer launches. Provide the complete task-specific brief and your current
position; inherited instructions and skills need not be pasted.

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
