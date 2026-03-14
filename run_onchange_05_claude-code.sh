#!/bin/bash

set -euo pipefail

# Install Claude Code via official installer
if ! command -v claude &>/dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi
