import ProjectDescription
import ProjectDescriptionHelpers

// Reusable spoken-audio layer: an on-device neural voice (MeloTTS via
// sherpa-onnx) reading the bundled per-language models.
//
// The sherpa-onnx + onnxruntime static xcframeworks are vendored (git-ignored)
// by scripts/fetch-sherpa-onnx.sh; run it once before `tuist generate`. They
// only exist for iOS, so they're conditioned out of the macOS destination and
// all engine code is wrapped in `#if os(iOS)`.
let project = Project.module(
    name: "Audio",
    dependencies: [
        .xcframework(
            path: "Vendor/sherpa-onnx/sherpa-onnx.xcframework",
            status: .required,
            condition: .when([.ios])
        ),
        .xcframework(
            path: "Vendor/sherpa-onnx/onnxruntime.xcframework",
            status: .required,
            condition: .when([.ios])
        ),
    ],
    targetSettings: [
        // Modulemap shim exposing the sherpa-onnx C API to Swift (framework
        // targets cannot use bridging headers).
        "SWIFT_INCLUDE_PATHS": "$(SRCROOT)/SherpaOnnxC",
        // Resolves the shim's #include "sherpa-onnx/c-api/c-api.h".
        "HEADER_SEARCH_PATHS": "$(SRCROOT)/Vendor/sherpa-onnx/include",
        // sherpa-onnx + onnxruntime are static C++ archives; the dynamic
        // Audio framework must link the C++ runtime.
        "OTHER_LDFLAGS": "$(inherited) -lc++",
    ]
)
