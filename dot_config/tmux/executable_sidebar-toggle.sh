#!/bin/bash
# Toggle the sidebar for the whole server. Bound to prefix + b.
set -u

dir=$(dirname "$0")

if [ "$(tmux show -gv @sidebar-enabled 2>/dev/null)" = off ]; then
  tmux set-option -g @sidebar-enabled on
  "$dir/sidebar-sweep.sh"
  tmux display-message "sidebar on"
else
  tmux set-option -g @sidebar-enabled off
  tmux list-panes -a -F '#{pane_id} #{@sidebar-pane}' 2>/dev/null |
    awk '$2 == 1 { print $1 }' |
    while read -r p; do tmux kill-pane -t "$p" 2>/dev/null; done
  tmux display-message "sidebar off"
fi
exit 0
