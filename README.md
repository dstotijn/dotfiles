# dotfiles

Config managment via [chezmoi](https://www.chezmoi.io/).

## Installation

On a fresh macOS installation:

1. Install Homebrew:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install chezmoi and apply this source directory:

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply dstotijn
```

## Chezmoi Conventions

- Files prefixed with `dot_` map to dotfiles (e.g., `dot_gitconfig` → `~/.gitconfig`)
- Files under `dot_config/` map to `~/.config/`
- `.tmpl` suffix means the file is a Go template rendered by chezmoi
- `run_onchange_` scripts execute when their template-hashed content changes
- `.chezmoiignore` excludes files from being applied to the target directory

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
| Fish shell | `dot_config/fish/config.fish` | Shell config, abbreviations, tool integrations |
| Neovim | `dot_config/nvim/` | AstroNvim v4+ with Lazy.nvim, Kanagawa theme |
| AeroSpace | `dot_config/aerospace/aerospace.toml` | Tiling window manager with semantic workspaces |
| Ghostty | `dot_config/ghostty/config` | Terminal emulator (Everblush theme, JetBrains Mono) |
| Git | `dot_gitconfig` | SSH signing, neovim editor |
| Starship | `dot_config/starship.toml` | Minimal prompt configuration |
| Mise | `dot_config/mise/config.toml` | Runtime version manager (Node, Python, uv, pre-commit) |

## Run Scripts (Execution Order)

1. `run_onchange_00_homebrew-install.sh.tmpl` — Runs `brew bundle` when Brewfile changes
2. `run_onchange_01_fisher.fish.tmpl` — Installs/updates Fisher plugins when fish_plugins changes

These are Go templates that embed a hash of their dependency file to trigger re-execution on change.

## Neovim Config Structure

Based on AstroNvim v4 template. Most plugin configs under `dot_config/nvim/lua/plugins/` are disabled with `if true then return {} end` guards — only `mason.lua` and the base setup are active. LSP servers: gopls, pylsp, pyright. Formatters: biome, buf.

## Fish Shell Integrations

The fish config (`dot_config/fish/config.fish`) initializes several tools in order: Homebrew → 1Password SSH agent → mise → starship → zoxide → mcfly. Git abbreviations are defined there (gp, gd, gco, gst, etc.).
