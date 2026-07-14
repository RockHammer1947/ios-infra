// sherpa-onnx/csrc/matcha-tts-lexicon.cc
//
// espeak-FREE STUB (Daodejing build). See piper-phonemize-lexicon.cc. The
// Matcha (espeak) frontend is never used by this app.

#include "sherpa-onnx/csrc/matcha-tts-lexicon.h"

#include "sherpa-onnx/csrc/macros.h"

namespace sherpa_onnx {

class MatchaTtsLexicon::Impl {};

MatchaTtsLexicon::~MatchaTtsLexicon() = default;

MatchaTtsLexicon::MatchaTtsLexicon(const std::string &, const std::string &,
                                   const std::string &, bool, bool) {
  SHERPA_ONNX_LOGE("This build has no espeak-ng; MatchaTtsLexicon unsupported.");
  SHERPA_ONNX_EXIT(-1);
}

std::vector<TokenIDs> MatchaTtsLexicon::ConvertTextToTokenIds(
    const std::string &, const std::string &) const {
  SHERPA_ONNX_LOGE("This build has no espeak-ng; MatchaTtsLexicon unsupported.");
  SHERPA_ONNX_EXIT(-1);
}

}  // namespace sherpa_onnx
