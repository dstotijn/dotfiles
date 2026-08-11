# Repository Guidelines

## Project Structure & Module Organization

This repository is the chezmoi source for personal dotfiles. Root files such as `Brewfile`,
`vscode-extensions.txt`, and `run_onchange_*` scripts manage packages and setup tasks. Files under
`dot_config/` map to `~/.config/`; `dot_claude/`, `dot_codex/`, and `dot_pi/` contain agent-tool
configuration. Neovim Lua lives in `dot_config/nvim/lua/`, while shell and tmux configuration
lives under `dot_config/fish/` and `dot_config/tmux/`. There is no separate application source or
test directory.

Follow chezmoi naming rules: `dot_` becomes `.`, `private_` sets private permissions,
`executable_` sets the executable bit, and `.tmpl` marks a Go template. Keep machine-only
instructions in gitignored `.AGENTS.local.md`.

## Build, Test, and Development Commands

- `chezmoi diff` previews changes against the home directory.
- `chezmoi apply --dry-run --verbose` checks a full apply without writing files.
- `chezmoi apply` applies reviewed changes locally; inspect the diff first.
- `chezmoi execute-template < FILE.tmpl | bash -n` validates a rendered Bash template. Use
  `fish -n` for rendered Fish files.
- `stylua --check dot_config/nvim/lua` checks Neovim Lua formatting.

## Coding Style & Naming Conventions

Preserve the style of the file you edit. Shell scripts use two-space indentation, quoted
expansions, and lowercase local variable names. Use portable `sh` only for scripts with an `sh`
shebang; otherwise follow the declared Bash or Fish dialect. Lua formatting follows
`dot_config/nvim/dot_stylua.toml`: two spaces, 120 columns, and preferred double quotes. Keep
OS-specific behavior inside explicit chezmoi template conditions.
