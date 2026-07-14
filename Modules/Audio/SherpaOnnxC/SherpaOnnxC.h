// Exposes the sherpa-onnx C API to Swift inside the Audio framework
// (framework targets cannot use bridging headers). The real header is
// vendored by scripts/fetch-sherpa-onnx.sh and found via HEADER_SEARCH_PATHS.
#include "sherpa-onnx/c-api/c-api.h"
