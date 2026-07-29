#!/bin/sh
# Clear the terminal's OSC 9;4 progress state.
#
# allow-passthrough is set to on, so tmux drops passthrough sequences from
# invisible panes. That scopes the progress bar to the active window, but it
# also means a pane can never clear a bar it set once you switch away: its
# reset is dropped too. Writing straight to the client tty needs no
# passthrough, so this runs whenever the active window or pane changes.

tty=$(tmux display-message -p '#{client_tty}' 2>/dev/null) || exit 0

case $tty in
	/dev/*) printf '\033]9;4;0;\007' >"$tty" 2>/dev/null ;;
esac
