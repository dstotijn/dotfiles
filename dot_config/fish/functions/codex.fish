function codex --description "Run Codex with agent Git signing"
  set -l context_args
  if test "$HERDR_ENV" = 1
    # The shared daemon does not inherit the launching pane's environment.
    set context_args (python3 -c '
import json
import os
import sys

for name, value in os.environ.items():
    if name.startswith("HERDR_"):
        argument = "shell_environment_policy.set." + name + "=" + json.dumps(value)
        sys.stdout.write("-c\0" + argument + "\0")
' | string split0)
    or return 1
  end

  __run_coding_agent "$HOME/.local/share/mise/installs/aqua-openai-codex/latest/bin/codex" $context_args $argv
end
