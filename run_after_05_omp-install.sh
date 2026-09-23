#!/bin/bash

set -euo pipefail

omp_bin_dir="$HOME/.local/share/omp-bun/bin"
export BUN_INSTALL_GLOBAL_DIR="$HOME/.local/share/omp-bun/install/global"
export BUN_INSTALL_BIN="$omp_bin_dir"

if [ ! -x "$omp_bin_dir/omp" ]; then
  mise exec -- bun install -g @oh-my-pi/pi-coding-agent
fi

completion_file="$HOME/.config/fish/completions/omp.fish"
mkdir -p "$(dirname "$completion_file")"
temp_file="$(mktemp "${completion_file}.XXXXXX")"
trap 'rm -f "$temp_file"' EXIT
mise exec -- "$omp_bin_dir/omp" completions fish > "$temp_file"
if ! cmp -s "$temp_file" "$completion_file"; then
  mv "$temp_file" "$completion_file"
fi
