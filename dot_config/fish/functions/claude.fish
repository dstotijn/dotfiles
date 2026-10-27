function claude --description "Run Claude Code with permission bypass and agent Git signing"
  # Claude Code drops OSC 8 links, such as the issue link in its status line,
  # unless it recognizes the terminal, and it does not recognize Herdr. Herdr
  # opens them on Ctrl+click.
  if test "$HERDR_ENV" = 1
    set -fx FORCE_HYPERLINK 1
  end
  __run_coding_agent claude --dangerously-skip-permissions $argv
end
