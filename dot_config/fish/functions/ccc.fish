function ccc --description "Run Claude Code with permission bypass"
    set -l git_common_dir (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if test -n "$git_common_dir"
        set -lx CLAUDE_CODE_TASK_LIST_ID (string replace -a '/' '-' (basename (dirname $git_common_dir))-(git branch --show-current 2>/dev/null))
    end
    claude --dangerously-skip-permissions $argv
end
