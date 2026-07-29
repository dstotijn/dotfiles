#!/bin/bash
# Called when a border drag finishes. If the drag moved the current window's
# sidebar, adopt that as the width for every sidebar in the session, so one drag
# resizes them all instead of being snapped back by sidebar-pin.sh.
set -u

session=${1:-$(tmux display -p '#{session_id}')}

tmux set-option -gu @sidebar-dragging 2>/dev/null

cur=$(tmux list-panes -t "$session" -F '#{@sidebar-pane} #{pane_width}' 2>/dev/null |
  awk '$1==1 {print $2; exit}')

# A drag to a degenerate width is more likely a slip than an intent, so keep the
# stored width and let the pin below undo it.
if [ -n "$cur" ] && [ "$cur" -ge 12 ] 2>/dev/null && [ "$cur" -le 60 ]; then
  tmux set-option -g @sidebar-width "$cur"
fi

exec "$(dirname "$0")/sidebar-pin.sh" "$session"
