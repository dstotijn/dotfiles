function gw --description "Switch to a git worktree using fzf"
    set -l dir (git worktree list | awk '{print $1}' | fzf)
    and cd $dir
end
