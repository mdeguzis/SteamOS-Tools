#!/usr/bin/env bash
# dev-setup.sh -- Set up a local development environment using uv
#
# Usage:
#   ./dev-setup.sh

set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install uv if not present
if ! command -v uv &>/dev/null; then
    echo "==> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Syncing virtual environment and dev dependencies..."
cd "$PACKAGE_DIR"
uv sync --group dev

echo ""
echo "==> Done!"
echo ""
echo "==> Option A -- activate the venv:"
echo "    source .venv/bin/activate"
echo "    steamos-tools --help"
echo ""
echo "==> Option B -- run without activating (uv):"
echo "    uv run steamos-tools --help"
echo "    uv run pytest tests/ -v"
