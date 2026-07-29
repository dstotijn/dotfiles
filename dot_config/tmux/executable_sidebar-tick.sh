#!/bin/bash
# One ticker per tmux server. Signals the refresh channel on a slow timer, for the
# things that change with no tmux event attached: window titles (Claude Code
# animates a spinner into its OSC 2 title) and recaps appended to a transcript.
#
# A single process per server rather than one per sidebar, and only the sidebar in
# the visible window actually redraws, so this stays close to free.
#
# Takes the socket path explicitly rather than trusting $TMUX: this is spawned
# detached from a hook, and inheriting the wrong server means silently ticking
# somebody else's session.
set -u

sock=${1:-}
t() {
  if [ -n "$sock" ]; then tmux -S "$sock" "$@"; else tmux "$@"; fi
}

key=$(printf '%s' "$sock" | tr -dc 'A-Za-z0-9')
pidf="${TMPDIR:-/tmp}/tmux-sidebar-tick-${key}.pid"
if [ -r "$pidf" ] && kill -0 "$(cat "$pidf" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi
echo $$ > "$pidf"
trap 'rm -f "$pidf"' EXIT

while :; do
  tick=$(t show -gv @sidebar-tick 2>/dev/null) || exit 0
  [ -n "$tick" ] || tick=2
  sleep "$tick"
  # No attached client means nothing is on screen to keep fresh.
  [ -n "$(t list-clients -F 1 2>/dev/null)" ] || continue
  t wait-for -S sidebar-refresh 2>/dev/null || exit 0
done
