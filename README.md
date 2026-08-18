# dotfiles

Config managment via [chezmoi](https://www.chezmoi.io/).

## Installation

### macOS

1. Install Homebrew:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install chezmoi and apply:

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply dstotijn
```

### Linux (Debian-based)

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply dstotijn
```

The Linux install script handles apt packages, tool installers, and setting fish as the default shell.

## Chezmoi Conventions

- Files prefixed with `dot_` map to dotfiles (e.g., `dot_gitconfig` → `~/.gitconfig`)
- Files under `dot_config/` map to `~/.config/`
- `.tmpl` suffix means the file is a Go template rendered by chezmoi
- `run_onchange_` scripts execute when their template-hashed content changes
- `.chezmoiignore` excludes files from being applied to the target directory
- `.chezmoiremove` lists targets chezmoi should delete, for retiring a file that was once managed
- Dot-prefixed entries in the source root (e.g. `.gitignore`, `.AGENTS.local.md`) are never applied as targets; chezmoi reserves that namespace for itself

## Common Commands

```bash
chezmoi apply              # Apply changes to home directory
chezmoi diff               # Preview what would change
chezmoi edit <file>        # Edit a managed file (opens source in $EDITOR)
chezmoi add <file>         # Add a new file to be managed
chezmoi cd                 # Open shell in source directory
```

## Key Components

| Component | Source Path | Purpose |
|-----------|------------|---------|
| Brewfile | `Brewfile` | Homebrew packages, casks, and taps |
| Fish shell | `dot_config/fish/config.fish.tmpl` | Shell config, abbreviations, tool integrations (OS-conditional) |
| Neovim | `dot_config/nvim/` | AstroNvim v4+ with Lazy.nvim, Catppuccin Mocha theme |
| AeroSpace | `dot_config/aerospace/aerospace.toml` | Tiling window manager with semantic workspaces |
| Ghostty | `dot_config/ghostty/config`, `private_dot_terminfo/` | Terminal config; installs `xterm-ghostty` terminfo for Linux SSH hosts |
| Git | `dot_gitconfig.tmpl` | SSH signing, neovim editor (templated home dir paths) |
| Starship | `dot_config/starship.toml` | Minimal prompt configuration |
| Mise | `dot_config/mise/config.toml` | Runtime/tool version manager (Go, Node, Python, npm packages) |
| Tmux | `dot_config/tmux/tmux.conf` | Terminal multiplexer with vim keybindings and smart-splits |
| AI agent instructions | `dot_config/AGENTS.md.tmpl` | Shared global instructions, symlinked into Claude Code, Codex, and opencode |

## AI Agent Instructions

`dot_config/AGENTS.md.tmpl` renders to `~/.config/AGENTS.md`, which four harnesses read through symlinks:

| Target | Source path |
|--------|-------------|
| `~/.claude/CLAUDE.md` | `dot_claude/symlink_CLAUDE.md.tmpl` |
| `~/.codex/AGENTS.md` | `dot_codex/symlink_AGENTS.md.tmpl` |
| `~/.config/opencode/AGENTS.md` | `dot_config/opencode/symlink_AGENTS.md.tmpl` |
| `~/.pi/agent/AGENTS.md` | `dot_pi/agent/symlink_AGENTS.md.tmpl` |

### Machine-local instructions

`.AGENTS.local.md` in the source root holds instructions for the current machine only. It is gitignored, so it never leaves the machine, and chezmoi never applies it as a target because dot-prefixed source entries are ignored. `dot_config/AGENTS.md.tmpl` appends its contents when the file exists:

```
{{- if stat (joinPath .chezmoi.sourceDir ".AGENTS.local.md") }}

{{ include ".AGENTS.local.md" | trim }}
{{- end }}
```

Run `chezmoi apply` after editing it, since the rendered file is not a symlink. Notes:

- The `stat` guard means a machine without the file renders the shared instructions byte-identical to before, so a fresh clone needs no setup.
- `include` inserts the file literally, so `{{ }}` in local notes is not interpreted as template syntax.
- Content lands in the shared file rather than a per-harness file because Codex reads exactly one global instruction file (`~/.codex/AGENTS.override.md` if present, otherwise `~/.codex/AGENTS.md`) and has no import syntax. Claude Code alone could instead use `~/.claude/rules/`.

## Run Scripts (Execution Order)

1. `run_onchange_00_homebrew-install.sh.tmpl` — (macOS) Runs `brew bundle`, sets fish as default shell
2. `run_onchange_00_linux-install.sh.tmpl` — (Linux) Installs apt packages, CLI tools, mise, Go tools, mcfly; sets fish as default shell
3. `run_onchange_01_fisher.fish.tmpl` — Installs/updates Fisher plugins when fish_plugins changes
4. `run_onchange_02_tpm.sh.tmpl` — Installs TPM and tmux plugins when tmux.conf changes

These are Go templates that embed a hash of their dependency file to trigger re-execution on change.

## Neovim Config Structure

Based on AstroNvim v4 template. Most plugin configs under `dot_config/nvim/lua/plugins/` are disabled with `if true then return {} end` guards — only `mason.lua` and the base setup are active. LSP servers: gopls, pylsp, pyright. Formatters: biome, buf.

## Fish Shell Integrations

The fish config (`dot_config/fish/config.fish.tmpl`) initializes tools in order: Homebrew (macOS only) → 1Password CLI (macOS only) → mise → starship → zoxide → mcfly. Git abbreviations are defined there (gp, gd, gco, gst, etc.).
