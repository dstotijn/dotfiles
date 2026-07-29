#!/bin/bash
# Renders the session's windows as a vertical list in a narrow pane. tmux has no
# vertical status line (status-position is top or bottom only), so a pane is the
# only way to get a sidebar.
#
# Blocks on the sidebar-refresh wait-for channel between draws, so it costs
# nothing until something changes. sidebar-tick.sh signals that channel on a slow
# timer for the things that arrive without a tmux event: window titles (Claude
# Code animates a spinner into its OSC 2 title) and recaps written to a
# transcript. Only the visible sidebar draws, so N windows do not mean N renders.
set -u

pane=${TMUX_PANE:?must run inside tmux}

e=$(printf '\033')
fg_sess="${e}[38;2;137;180;250;1m"
# Catppuccin Mocha. Four steps down the ramp, so the eye can rank them: the active
# title is text, an inactive title is subtext0, a description is overlay1 and the
# rules and inactive markers are surface0.
fg_rule="${e}[38;2;49;50;68m"      # surface0  #313244
fg_name="${e}[38;2;205;214;244;1m" # text      #cdd6f4
fg_dim="${e}[38;2;166;173;200m"    # subtext0  #a6adc8
fg_desc="${e}[38;2;127;132;156m"   # overlay1  #7f849c
fg_mark="${e}[38;2;203;166;247m"   # mauve     #cba6f7
rst="${e}[0m"

# Target the session by id, not name: ids survive rename-session, names do not, and
# a name captured once here would break every lookup the moment the session is
# renamed. The display name is re-read on each draw instead.
sid=$(tmux display -p -t "$pane" '#{session_id}')
map="${TMPDIR:-/tmp}/tmux-sidebar-${pane}.map"
cache="${TMPDIR:-/tmp}/tmux-sidebar-cache-${sid#$}"
mkdir -p "$cache" 2>/dev/null

trap 'rm -f "$map" "$map.tmp"' EXIT

# One field per line, so a window name containing the separator cannot corrupt
# the parse. Names come from pane titles, which are arbitrary text.
fmt=$(printf '%s\n' '#{window_id}' '#{window_index}' '#{window_active}' \
  '#{window_name}' '#{@sidebar-desc}' '#{@sidebar-src}')

# Claude Code writes its "recap" to the session transcript as a system entry
# rather than exposing it to a hook, and generates it opportunistically after a
# turn (skipped near rate limits, while a draft is pending, and so on). So pull
# it on redraw instead of having a hook push it, gated on mtime because the
# transcript can be large. Codex transcripts have no such entry and fall through
# to whatever its hooks pushed into @sidebar-desc.
recap_for() {
  local wid=$1 src=$2 m cm txt
  [ -n "$src" ] && [ -r "$src" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  m=$(stat -f %m "$src" 2>/dev/null) || return 0
  cm=$(cat "$cache/$wid.m" 2>/dev/null)
  if [ "$m" = "$cm" ]; then
    cat "$cache/$wid.d" 2>/dev/null
    return 0
  fi
  txt=$(tail -n 3000 "$src" 2>/dev/null |
    jq -r 'select(.type=="system" and .subtype=="away_summary") | .content' 2>/dev/null |
    tail -1)
  printf '%s' "$m" > "$cache/$wid.m.tmp" 2>/dev/null && mv "$cache/$wid.m.tmp" "$cache/$wid.m"
  printf '%s' "$txt" > "$cache/$wid.d.tmp" 2>/dev/null && mv "$cache/$wid.d.tmp" "$cache/$wid.d"
  printf '%s' "$txt"
}

prev=""
first=1
render() {
  # Only the sidebar in the visible window has anything to draw, except for the
  # very first pass: a pane that starts hidden would otherwise sit blank until the
  # window is visited, which is exactly what you see after reloading the config.
  if [ "$first" = 1 ]; then
    first=0
  elif [ "$(tmux display -p -t "$pane" '#{window_active}')" != 1 ]; then
    return 0
  fi

  local width height recap maxdesc session out wid idx active name desc src text line n i
  local -a lines=() owner=()
  width=$(tmux display -p -t "$pane" '#{pane_width}')
  height=$(tmux display -p -t "$pane" '#{pane_height}')
  [ "$width" -gt 8 ] 2>/dev/null || return 0
  recap=$(tmux show -gv @sidebar-recap 2>/dev/null)
  session=$(tmux display -p -t "$pane" '#{session_name}')
  maxdesc=$(tmux show -gv @sidebar-desc-lines 2>/dev/null)
  [ -n "$maxdesc" ] || maxdesc=2

  # owner[] carries the window index each rendered row belongs to, or "" for rows
  # that should ignore clicks. It is built in lockstep with lines[] so the click
  # map cannot drift from what is actually on screen.
  lines+=("${fg_sess} ${session}${rst}") ; owner+=("")
  lines+=("${fg_rule} $(printf '%*s' $((width - 2)) '' | tr ' ' '─')${rst}") ; owner+=("")
  lines+=("") ; owner+=("")

  while IFS= read -r wid && IFS= read -r idx && IFS= read -r active &&
        IFS= read -r name && IFS= read -r desc && IFS= read -r src; do
    if [ ${#name} -gt $((width - 4)) ]; then
      name="${name:0:$((width - 5))}…"
    fi
    if [ "$active" = 1 ]; then
      lines+=("${fg_mark}▎${fg_name}${idx} ${name}${rst}")
    else
      lines+=("${fg_rule}▎${fg_dim}${idx} ${name}${rst}")
    fi
    owner+=("$idx")

    text=$desc
    if [ "$recap" != off ]; then
      local r
      r=$(recap_for "${wid#@}" "$src")
      [ -n "$r" ] && text=$r
    fi

    if [ -n "$text" ]; then
      # Cap each description, or one long recap crowds every other window out.
      n=0
      while IFS= read -r line; do
        n=$((n + 1))
        if [ "$n" -gt "$maxdesc" ]; then
          lines[${#lines[@]} - 1]="${lines[${#lines[@]} - 1]}…"
          break
        fi
        lines+=("${fg_desc}  ${line}${rst}")
        owner+=("$idx")
      done < <(printf '%s\n' "$text" | fold -s -w $((width - 4)))
    fi

    # The trailing blank ignores clicks: dead space should do nothing rather than
    # switch to whichever window happens to be adjacent.
    lines+=("") ; owner+=("")
  done < <(tmux list-windows -t "$sid" -F "$fmt")

  # Clip to the pane. Writing the last row would scroll the pane and push the
  # header off the top, so stop one short.
  n=${#lines[@]}
  [ "$n" -gt $((height - 1)) ] && n=$((height - 1))

  out=""
  : > "$map.tmp"
  i=0
  while [ "$i" -lt "$n" ]; do
    out+="${lines[$i]}\n"
    [ -n "${owner[$i]}" ] && printf '%s %s\n' "$i" "${owner[$i]}" >> "$map.tmp"
    i=$((i + 1))
  done

  mv "$map.tmp" "$map" 2>/dev/null

  # Claim this pane's title as the window's current name. If the sidebar ever
  # becomes the active pane, automatic-rename-format "#{pane_title}" would
  # otherwise rename the window after the sidebar; this makes that a no-op.
  printf "${e}]2;%s${e}\\\\" "$(tmux display -p -t "$pane" '#{window_name}')"

  [ "$out" = "$prev" ] && return 0
  prev=$out
  printf "${e}[H${e}[2J%b" "$out"
}

printf "${e}[?25l"
while :; do
  render
  tmux wait-for sidebar-refresh 2>/dev/null || sleep 5
done
