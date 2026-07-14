#!/usr/bin/env bash
# Vendors sherpa-onnx for iOS into the git-ignored Modules/Audio/Vendor/
# directory. Tuist validates xcframework paths at generate time, so this must
# run before `tuist generate` (bootstrap.sh and the fastlane generate_project
# lane both call it).
#
# ⚠️ We do NOT ship the upstream prebuilt sherpa-onnx: it statically bundles
# espeak-ng (GPLv3), incompatible with closed-source App Store distribution.
# Instead we take onnxruntime.xcframework (MIT) from the official tarball and
# BUILD an espeak-free sherpa-onnx.xcframework from source — see
# scripts/sherpa-onnx-espeak-free/. MeloTTS (lexicon-based) needs no espeak.
#
# Mirror for users behind restricted networks:
#   SHERPA_ONNX_MIRROR=https://ghproxy.com/https://github.com ./scripts/fetch-sherpa-onnx.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="1.13.3"
NOESPEAK_VERSION="1.13.3-noespeak"   # stamp written by the espeak-free build
SHA256="2f30ff72a2f381ca39b56e62aa87b1cbdc38f19f9e49bbd92c7cc112e3a44f6a"
DEST="Modules/Audio/Vendor/sherpa-onnx"
STAMP="$DEST/.version"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$NOESPEAK_VERSION" ]; then
  echo "espeak-free sherpa-onnx already vendored"
  exit 0
fi

BASE="${SHERPA_ONNX_MIRROR:-https://github.com}/k2-fsa/sherpa-onnx/releases/download/v$VERSION"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading sherpa-onnx v$VERSION iOS artifacts (for onnxruntime, ~42MB)"
curl -fL --retry 3 -o "$TMP/ios.tar.bz2" "$BASE/sherpa-onnx-v$VERSION-ios.tar.bz2"
echo "$SHA256  $TMP/ios.tar.bz2" | shasum -a 256 -c -
tar xjf "$TMP/ios.tar.bz2" -C "$TMP"

echo "==> Placing onnxruntime.xcframework (MIT) into $DEST"
mkdir -p "$DEST"
rm -rf "$DEST/onnxruntime.xcframework"
# The onnxruntime xcframework sits behind a version-dir symlink — dereference.
cp -RL "$TMP/build-ios/ios-onnxruntime/onnxruntime.xcframework" "$DEST/"

# Build the espeak-free sherpa-onnx.xcframework + install headers + set stamp.
# (This is the ~20-min from-source build; it caches via the version stamp.)
echo "==> Building espeak-free sherpa-onnx (GPL-free, App Store compliant)"
./scripts/sherpa-onnx-espeak-free/build.sh

echo "==> Done: $(du -sh "$DEST" | cut -f1) vendored (espeak-free)"
