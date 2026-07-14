#!/usr/bin/env bash
# Bootstrap a fresh checkout: install the pinned toolchain, Ruby gems, and
# generate the Xcode workspace. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

# mise reads GITHUB_TOKEN, not GITHUB_PAT_TOKEN. Bridge from launchctl if set.
if [ -z "${GITHUB_TOKEN:-${MISE_GITHUB_TOKEN:-}}" ]; then
  if pat="$(launchctl getenv GITHUB_PAT_TOKEN 2>/dev/null)" && [ -n "$pat" ]; then
    export GITHUB_TOKEN="$pat"
  fi
fi

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

echo "==> Vendoring sherpa-onnx prebuilt frameworks"
./scripts/fetch-sherpa-onnx.sh

echo "==> Staging bundled TTS voice models"
./scripts/fetch-tts-models.sh

echo "==> Resolving Swift packages and generating the workspace"
mise exec -- tuist install
mise exec -- tuist generate --no-open

echo "==> Done. Open iOSInfra.xcworkspace in Xcode."
