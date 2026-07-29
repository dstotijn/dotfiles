#!/bin/bash
# Turns a click in a sidebar pane into a window switch, using the row -> window
# map that sidebar.sh writes on each draw (mouse_y is the 0-based row inside the
# pane). Deliberately does not select the clicked pane: the sidebar must never
# hold focus, or automatic-rename starts naming windows after it.
set -u

pane=${1:?pane id}
row=${2:?mouse row}
map="${TMPDIR:-/tmp}/tmux-sidebar-${pane}.map"
[ -r "$map" ] || exit 0

idx=$(awk -v r="$row" '$1 == r { print $2; exit }' "$map")
[ -n "$idx" ] || exit 0

# By id, not name: names change under rename-session and may contain a colon,
# which would be parsed as a window separator in the target.
session=$(tmux display -p -t "$pane" '#{session_id}')
tmux select-window -t "$session:$idx" 2>/dev/null || exit 0

# Land on that window's real pane, not its sidebar.
target=$(tmux list-panes -t "$session:$idx" -F '#{pane_id} #{@sidebar-pane}' 2>/dev/null |
  awk '$2 != 1 { print $1; exit }')
[ -n "$target" ] && tmux select-pane -t "$target" 2>/dev/null
exit 0
