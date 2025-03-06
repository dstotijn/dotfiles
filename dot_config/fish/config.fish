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
end

source "$(brew --prefix)/share/google-cloud-sdk/path.fish.inc"

if status is-interactive
  mise activate fish | source
else
  mise activate fish --shims | source
end
