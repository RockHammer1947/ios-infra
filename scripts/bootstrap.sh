#!/usr/bin/env bash
# Bootstrap a fresh checkout: install the pinned toolchain, Ruby gems, and
# generate the Xcode workspace. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Ensuring mise is installed"
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Installing pinned tools (Tuist, SwiftLint, SwiftFormat)"
mise install

echo "==> Installing Ruby gems (fastlane)"
if command -v bundle >/dev/null 2>&1; then
  bundle install
else
  echo "    bundler not found — install Ruby/bundler, then run 'bundle install'"
fi

echo "==> Resolving Swift packages and generating the workspace"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "==> Done. Open iOSInfra.xcworkspace in Xcode."
