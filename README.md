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
