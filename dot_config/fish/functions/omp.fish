function omp --description "Run OMP with agent Git signing"
  set -lx BUN_INSTALL_GLOBAL_DIR "$HOME/.local/share/omp-bun/install/global"
  set -lx BUN_INSTALL_BIN "$HOME/.local/share/omp-bun/bin"
  __run_coding_agent omp $argv
  set -l agent_status $status

  if test $agent_status -eq 0; and test "$argv[1]" = update
    set -l completion_file "$HOME/.config/fish/completions/omp.fish"
    set -l temp_file (mktemp "$completion_file.XXXXXX")
    if command omp completions fish > "$temp_file"
      command mv "$temp_file" "$completion_file"
    else
      command rm -f "$temp_file"
    end
  end

  return $agent_status
end
