function claude --description "Run Claude Code with permission bypass and agent Git signing"
  __run_coding_agent claude --dangerously-skip-permissions $argv
end
