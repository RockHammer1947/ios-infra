#!/usr/bin/env bash
# Scaffold a new multiplatform app from the shared template, then regenerate
# the workspace. Usage: scripts/new-app.sh MyApp
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "Usage: scripts/new-app.sh <AppName>" >&2
  exit 1
fi

echo "==> Scaffolding app '$NAME'"
mise exec -- tuist scaffold app --name "$NAME"

echo "==> Regenerating workspace"
mise exec -- tuist generate --no-open

cat <<EOF

Created apps/$NAME.
Next steps:
  1. Add a CI job: copy the daodejing-reader job in .github/workflows/ci.yml,
     change scheme to "$NAME".
  2. (Optional) Register its bundle id in App Store Connect — see
     docs/app-store-setup.md.
EOF
