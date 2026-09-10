function __run_coding_agent --description "Run a coding agent with its Git signing profile"
  set -l executable $argv[1]
  set -l arguments $argv[2..]
  set -l profile "$HOME/.config/git/agent.gitconfig"

  if not test -r "$profile"
    echo "Agent Git signing profile is unavailable: $profile" >&2
    return 1
  end

  set -lx GIT_CONFIG_COUNT 1
  set -lx GIT_CONFIG_KEY_0 include.path
  set -lx GIT_CONFIG_VALUE_0 "$profile"

  set -l signing_profile (command git config --get --bool agent.signingProfile)
  if test "$signing_profile" != true
    echo "Agent Git signing profile failed its preflight check" >&2
    return 1
  end

  set -l signing_key (command git config --path --get user.signingKey)
  if not test -r "$signing_key"
    echo "Agent Git signing key is unavailable: $signing_key" >&2
    return 1
  end

  set -l signing_program (command git config --path --get gpg.ssh.program)
  if not test -x "$signing_program"
    echo "Agent Git signing program is unavailable: $signing_program" >&2
    return 1
  end

  command $executable $arguments
end
