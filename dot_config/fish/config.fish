if status is-interactive
  abbr -a -- cz chezmoi
  abbr -a -- gpf 'git push --force-with-lease'
  abbr -a -- gst 'git status'
  abbr -a -- gcb 'git checkout -b'
  abbr -a -- gd 'git diff'
  abbr -a -- gpsup 'git push --set-upstream origin $(git branch --show-current)'
  abbr -a -- gup 'git pull --rebase'
  abbr -a -- gco 'git checkout'
  abbr -a -- gp 'git push'
  abbr -a -- gac 'git add -A && git commit'

  abbr -a oc 'set -gx OPENROUTER_API_KEY (op read "op://Private/ymlfds7jrnj3opetd3k7bqei6i/credential"); opencode'
end

fish_add_path ~/.local/bin

/opt/homebrew/bin/brew shellenv | source
op completion fish | source

if status is-interactive
  mise activate fish | source
else
  mise activate fish --shims | source
end

starship init fish | source
zoxide init fish | source
mcfly init fish | source
