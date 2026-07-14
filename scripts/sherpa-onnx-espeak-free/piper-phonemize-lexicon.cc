// sherpa-onnx/csrc/piper-phonemize-lexicon.cc
//
// espeak-FREE STUB (Daodejing build). Upstream pulls piper-phonemize →
// espeak-ng (GPLv3), incompatible with closed-source App Store distribution.
// This app uses only MeloTTS (MeloTtsLexicon), which never constructs
// PiperPhonemizeLexicon (that frontend is chosen only when a model ships
// espeak-ng-data). These stubs keep the symbols so the factory links.

#include "sherpa-onnx/csrc/piper-phonemize-lexicon.h"

#include "sherpa-onnx/csrc/macros.h"

namespace sherpa_onnx {

namespace {
[[noreturn]] void Unsupported() {
  SHERPA_ONNX_LOGE(
      "This build has no espeak-ng/piper-phonemize. Piper/Kokoro/espeak-Matcha "
      "are unsupported; use a lexicon model (e.g. MeloTTS).");
  SHERPA_ONNX_EXIT(-1);
}
}  // namespace

PiperPhonemizeLexicon::PiperPhonemizeLexicon(
    const std::string &, const std::string &,
    const OfflineTtsVitsModelMetaData &) {
  Unsupported();
}

PiperPhonemizeLexicon::PiperPhonemizeLexicon(
    const std::string &, const std::string &,
    const OfflineTtsMatchaModelMetaData &) {
  Unsupported();
}

PiperPhonemizeLexicon::PiperPhonemizeLexicon(
    const std::string &, const std::string &,
    const OfflineTtsKokoroModelMetaData &) {
  Unsupported();
}

PiperPhonemizeLexicon::PiperPhonemizeLexicon(
    const std::string &, const std::string &,
    const OfflineTtsKittenModelMetaData &) {
  Unsupported();
}

std::vector<TokenIDs> PiperPhonemizeLexicon::ConvertTextToTokenIds(
    const std::string &, const std::string &) const {
  Unsupported();
}

std::vector<TokenIDs> PiperPhonemizeLexicon::ConvertTextToTokenIdsVits(
    const std::string &, const std::string &) const {
  Unsupported();
}

std::vector<TokenIDs> PiperPhonemizeLexicon::ConvertTextToTokenIdsMatcha(
    const std::string &, const std::string &) const {
  Unsupported();
}

}  // namespace sherpa_onnx
