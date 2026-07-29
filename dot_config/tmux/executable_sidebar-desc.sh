#!/bin/bash
# Set the calling window's sidebar description. The whole contract for anything
# that wants to show something in the sidebar:
#
#   ~/.config/tmux/sidebar-desc.sh "reviewing PR #412"
#
# $TMUX_PANE is inherited by subprocesses, including agent hooks, so a caller
# never has to work out which window it is in. No-ops outside tmux.
set -u

[ -n "${TMUX_PANE:-}" ] || exit 0

text=$(printf '%s' "${1-}" | tr '\n\t' '  ' | sed 's/  */ /g; s/^ *//; s/ *$//')
text=${text:0:200}

if [ -n "$text" ]; then
  tmux set-option -w -t "$TMUX_PANE" @sidebar-desc "$text" 2>/dev/null
else
  tmux set-option -uw -t "$TMUX_PANE" @sidebar-desc 2>/dev/null
fi

tmux wait-for -S sidebar-refresh 2>/dev/null
exit 0
