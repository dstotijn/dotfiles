#!/bin/bash
# Give every window in a session a sidebar. Runs at config load, so sourcing
# tmux.conf retrofits windows that already exist, and on client-attached, to
# catch windows created while detached.
set -u

dir=$(dirname "$0")
session=${1:-}

[ "$(tmux show -gv @sidebar-enabled 2>/dev/null)" = off ] && exit 0

if [ -n "$session" ]; then
  windows=$(tmux list-windows -t "$session" -F '#{window_id}' 2>/dev/null)
else
  windows=$(tmux list-windows -a -F '#{window_id}' 2>/dev/null)
fi

for w in $windows; do
  "$dir/sidebar-attach.sh" "$w"
done

"$dir/sidebar-pin.sh" "${session:-}"
exit 0
