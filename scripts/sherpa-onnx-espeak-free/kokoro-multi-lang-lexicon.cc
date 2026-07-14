// sherpa-onnx/csrc/kokoro-multi-lang-lexicon.cc
//
// espeak-FREE STUB (Daodejing build). See piper-phonemize-lexicon.cc. Kokoro
// is never used by this app.

#include "sherpa-onnx/csrc/kokoro-multi-lang-lexicon.h"

#include "sherpa-onnx/csrc/macros.h"

namespace sherpa_onnx {

class KokoroMultiLangLexicon::Impl {};

KokoroMultiLangLexicon::~KokoroMultiLangLexicon() = default;

KokoroMultiLangLexicon::KokoroMultiLangLexicon(
    const std::string &, const std::string &, const std::string &,
    const OfflineTtsKokoroModelMetaData &, bool) {
  SHERPA_ONNX_LOGE("This build has no espeak-ng; Kokoro is unsupported.");
  SHERPA_ONNX_EXIT(-1);
}

std::vector<TokenIDs> KokoroMultiLangLexicon::ConvertTextToTokenIds(
    const std::string &, const std::string &) const {
  SHERPA_ONNX_LOGE("This build has no espeak-ng; Kokoro is unsupported.");
  SHERPA_ONNX_EXIT(-1);
}

}  // namespace sherpa_onnx
