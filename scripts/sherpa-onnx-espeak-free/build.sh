#!/usr/bin/env bash
# Builds an ESPEAK-FREE sherpa-onnx iOS xcframework from source.
#
# WHY: the upstream prebuilt sherpa-onnx statically bundles espeak-ng (GPLv3),
# which is incompatible with closed-source App Store distribution. This app
# only uses MeloTTS (a lexicon-based VITS model) which needs NO espeak, so we
# stub out the three espeak-dependent frontends (Piper / Kokoro / espeak-Matcha)
# and drop espeak-ng + piper-phonemize + libucd from the build.
#
# Output: Modules/Audio/Vendor/sherpa-onnx/{sherpa-onnx.xcframework,include}
# with a `.version` stamp of "$VERSION". Verified: 0 espeak symbols, MeloTTS
# C-API intact, c-api.h unchanged.
#
# Reuses the app's already-vendored onnxruntime.xcframework (MIT) so no network
# is needed for that dependency.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root
REPO="$PWD"
HERE="scripts/sherpa-onnx-espeak-free"

SHERPA_TAG="v1.13.3"
VERSION="1.13.3-noespeak"
DEST="Modules/Audio/Vendor/sherpa-onnx"
STAMP="$DEST/.version"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$VERSION" ]; then
  echo "espeak-free sherpa-onnx $VERSION already vendored"
  exit 0
fi

command -v cmake >/dev/null || { echo "cmake required (brew install cmake)"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "==> Cloning sherpa-onnx $SHERPA_TAG"
git clone --depth 1 --branch "$SHERPA_TAG" https://github.com/k2-fsa/sherpa-onnx.git "$WORK/src"
cd "$WORK/src"

echo "==> Applying espeak-free patch"
cp "$REPO/$HERE/piper-phonemize-lexicon.cc"  sherpa-onnx/csrc/
cp "$REPO/$HERE/matcha-tts-lexicon.cc"       sherpa-onnx/csrc/
cp "$REPO/$HERE/kokoro-multi-lang-lexicon.cc" sherpa-onnx/csrc/
git apply "$REPO/$HERE/cmake-and-buildscript.patch"

echo "==> Staging onnxruntime from the repo's vendored copy"
mkdir -p build-ios/ios-onnxruntime/1.26.0
cp -R "$REPO/$DEST/onnxruntime.xcframework" build-ios/ios-onnxruntime/1.26.0/
( cd build-ios/ios-onnxruntime && ln -sf 1.26.0/onnxruntime.xcframework . )

echo "==> Building iOS xcframework (device + simulator; ~20 min)"
export CMAKE_POLICY_VERSION_MINIMUM=3.5      # cmake 4 dropped <3.5 policy compat
export SHERPA_ONNX_ONNXRUNTIME_VERSION=1.26.0
bash build-ios.sh

echo "==> Verifying espeak is gone"
LIB="build-ios/sherpa-onnx.xcframework/ios-arm64/libsherpa-onnx.a"
n=$(nm "$LIB" 2>/dev/null | grep -cE ' [Tt] _espeak' || true)
[ "$n" = "0" ] || { echo "FAIL: $n espeak symbols still present"; exit 1; }
nm "$LIB" 2>/dev/null | grep -q "_SherpaOnnxOfflineTtsGenerateWithConfig" \
  || { echo "FAIL: TTS C-API missing"; exit 1; }

echo "==> Installing into $DEST"
rm -rf "$REPO/$DEST/sherpa-onnx.xcframework"
cp -R build-ios/sherpa-onnx.xcframework "$REPO/$DEST/"
mkdir -p "$REPO/$DEST/include/sherpa-onnx/c-api"
cp build-ios/install/include/sherpa-onnx/c-api/c-api.h "$REPO/$DEST/include/sherpa-onnx/c-api/"
echo "$VERSION" > "$REPO/$STAMP"
echo "==> Done: espeak-free sherpa-onnx $VERSION vendored (0 espeak symbols)"
