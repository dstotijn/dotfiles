#!/bin/bash
# Idempotently give a window a sidebar pane on the left, then hand focus back to
# the pane that had it. Called from the session-created, after-new-window and
# window-linked hooks, so every window gets one without a wrapper command.
set -u

dir=$(dirname "$0")
win=${1:-$(tmux display -p '#{window_id}')}

[ "$(tmux show -gv @sidebar-enabled 2>/dev/null)" = off ] && exit 0

# session-created, client-attached and the config-load sweep can all fire for the
# same window within milliseconds, and each would pass the "already has one?"
# check below before any of them has created a pane. mkdir is atomic, so it
# serialises them; the loser exits and the winner's pane is then visible to it.
lock="${TMPDIR:-/tmp}/tmux-sidebar-lock-$(printf '%s' "$win" | tr -dc 'A-Za-z0-9')"
if ! mkdir "$lock" 2>/dev/null; then
  # Don't let a hard-killed run block this window forever.
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    rmdir "$lock" 2>/dev/null
  fi
  exit 0
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

tmux list-panes -t "$win" -F '#{@sidebar-pane}' 2>/dev/null | grep -q 1 && exit 0

width=$(tmux show -gv @sidebar-width 2>/dev/null)
[ -n "$width" ] || width=26

active=$(tmux display -p -t "$win" '#{pane_id}')
pane=$(tmux split-window -h -b -l "$width" -t "$win" -P -F '#{pane_id}' -d "$dir/sidebar.sh") || exit 0
tmux set-option -p -t "$pane" @sidebar-pane 1
tmux select-pane -t "$active"

"$dir/sidebar-tick.sh" "$(tmux display -p '#{socket_path}' 2>/dev/null)" </dev/null >/dev/null 2>&1 &
tmux wait-for -S sidebar-refresh 2>/dev/null
exit 0
