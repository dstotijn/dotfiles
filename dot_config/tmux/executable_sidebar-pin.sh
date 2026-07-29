#!/bin/bash
# Re-pin every sidebar pane to its configured width. Layout changes (splits, pane
# kills, client resize) let tmux redistribute columns; this claws them back.
set -u

# A border drag fires window-layout-changed continuously; pinning through it
# would fight the drag frame by frame. sidebar-adopt.sh clears this on release.
[ "$(tmux show -gv @sidebar-dragging 2>/dev/null)" = 1 ] && exit 0

width=$(tmux show -gv @sidebar-width 2>/dev/null)
[ -n "$width" ] || width=26

if [ -n "${1:-}" ]; then
  panes=$(tmux list-panes -s -t "$1" -F '#{window_id} #{pane_id} #{@sidebar-pane} #{pane_width}' 2>/dev/null)
else
  panes=$(tmux list-panes -a -F '#{window_id} #{pane_id} #{@sidebar-pane} #{pane_width}' 2>/dev/null)
fi

seen=""
printf '%s\n' "$panes" | while read -r win pane sb cur; do
  [ "$sb" = 1 ] || continue
  # Defensive: if a race ever leaves a window with more than one sidebar, keep the
  # first and reap the rest.
  case " $seen " in
    *" $win "*) tmux kill-pane -t "$pane" 2>/dev/null; continue ;;
  esac
  seen="$seen $win"
  # A window whose only remaining pane is the sidebar is a dead end: the real
  # pane exited. Close it so the window goes away as it normally would.
  if [ "$(tmux display -p -t "$win" '#{window_panes}' 2>/dev/null)" = 1 ]; then
    tmux kill-pane -t "$pane" 2>/dev/null
    continue
  fi
  [ "$cur" = "$width" ] && continue
  tmux resize-pane -t "$pane" -x "$width" 2>/dev/null
done

tmux wait-for -S sidebar-refresh 2>/dev/null
exit 0
