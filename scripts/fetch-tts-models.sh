#!/usr/bin/env bash
# Stages the bundled MeloTTS voice models into the git-ignored
# apps/DaodejingReader/BundledTTS/ folder reference. The app ships the models
# in its bundle (no runtime download), so this must run before building —
# bootstrap.sh and the fastlane generate_project lane both call it.
#
# Two models, one per content language (both 44.1kHz MeloTTS / VITS):
#   melo-zh  <- vits-melo-tts-zh_en (bilingual; used for 中文 · 1 voice)
#   melo-en  <- vits-melo-tts-en    (English · 5 accent voices)
#
# fp32 is intentional: int8 quantization was measured 2.3x slower than
# real-time on A14 (ConvInteger fallback), and fp16 doesn't convert cleanly.
# See docs/kokoro-tts-integration-plan.md history + memory notes.
#
# Mirror for users behind restricted networks:
#   SHERPA_ONNX_MIRROR=https://ghproxy.com/https://github.com ./scripts/fetch-tts-models.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="melo-fp32-1"
DEST="apps/DaodejingReader/BundledTTS"
STAMP="$DEST/.version"

ZH_ARCHIVE="vits-melo-tts-zh_en.tar.bz2"
ZH_SHA256="e58351ed7149f290a54534538badd4077cdbe6fddc964b24d0bee870415d1514"
EN_ARCHIVE="vits-melo-tts-en.tar.bz2"
EN_SHA256="f87bc5752ea3ec34273a2cc0c5086854c18b6b89dfd0534b5248e86a14cedb5d"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$VERSION" ]; then
  echo "TTS models $VERSION already staged"
  exit 0
fi

BASE="${SHERPA_ONNX_MIRROR:-https://github.com}/k2-fsa/sherpa-onnx/releases/download/tts-models"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() { # name sha256
  echo "==> Downloading $1"
  curl -fL --retry 3 -o "$TMP/$1" "$BASE/$1"
  echo "$2  $TMP/$1" | shasum -a 256 -c -
  tar xjf "$TMP/$1" -C "$TMP"
}

fetch "$ZH_ARCHIVE" "$ZH_SHA256"
fetch "$EN_ARCHIVE" "$EN_SHA256"

echo "==> Staging into $DEST"
rm -rf "$DEST"
mkdir -p "$DEST/melo-zh" "$DEST/melo-en"

# 中文 (bilingual model): weights + lexicon + jieba dict + normalization FSTs.
ZH_SRC="$TMP/vits-melo-tts-zh_en"
cp "$ZH_SRC/model.onnx" "$ZH_SRC/lexicon.txt" "$ZH_SRC/tokens.txt" "$DEST/melo-zh/"
cp -R "$ZH_SRC/dict" "$DEST/melo-zh/"
cp "$ZH_SRC/phone.fst" "$ZH_SRC/date.fst" "$ZH_SRC/number.fst" "$ZH_SRC/new_heteronym.fst" "$DEST/melo-zh/"

# English: weights + lexicon (no dict/FSTs needed).
EN_SRC="$TMP/vits-melo-tts-en"
cp "$EN_SRC/model.onnx" "$EN_SRC/lexicon.txt" "$EN_SRC/tokens.txt" "$DEST/melo-en/"

echo "$VERSION" > "$STAMP"
echo "==> Done: $(du -sh "$DEST" | cut -f1) staged"
