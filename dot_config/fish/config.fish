if status is-interactive
    # Commands to run in interactive sessions can go here
end

source "$(brew --prefix)/share/google-cloud-sdk/path.fish.inc"

if status is-interactive
  mise activate fish | source
else
  mise activate fish --shims | source
end
