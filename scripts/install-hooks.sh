#!/usr/bin/env bash
# Install local git hooks + commit template (tag-line commits).
# See docs/GIT.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git config core.hooksPath .githooks
git config commit.template .gitmessage
chmod +x .githooks/commit-msg

echo "Git hooks installed (tag-line commits)."
echo "  core.hooksPath=.githooks"
echo "  commit.template=.gitmessage"
