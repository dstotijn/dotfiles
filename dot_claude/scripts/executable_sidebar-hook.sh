#!/usr/bin/env bash
# Feeds the tmux sidebar with what this session is doing. Registered on several
# hook events in settings.json; the event name in the payload decides what to show.
#
# Codex uses the same event names and the same payload field names, so this script
# works unchanged from ~/.codex/hooks.json.
#
# Never exits non-zero: a failing UserPromptSubmit hook blocks the prompt.

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
eval "$(printf '%s' "$input" | jq -r '
  @sh "ev=\(.hook_event_name // "")",
  @sh "prompt=\(.prompt // "")",
  @sh "last=\(.last_assistant_message // "")",
  @sh "tp=\(.transcript_path // "")"' 2>/dev/null)"

# Record where this session's transcript lives, so the sidebar can pull Claude
# Code's recap from it. The recap is written to the transcript as a system entry
# rather than exposed to a hook, and only generated opportunistically after a
# turn, so a hook cannot reliably read it at the moment it fires.
if [ -n "${tp:-}" ]; then
  tmux set-option -w -t "$TMUX_PANE" @sidebar-src "$tp" 2>/dev/null
fi

desc() { "$HOME/.config/tmux/sidebar-desc.sh" "$1"; }

case ${ev:-} in
  SessionStart)     desc "" ;;
  UserPromptSubmit) desc "▸ ${prompt:-}" ;;
  Stop)             desc "✓ ${last%%$'\n'*}" ;;
  Notification)     desc "⏸ needs you" ;;
esac

exit 0
