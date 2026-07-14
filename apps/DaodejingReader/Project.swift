import ProjectDescription
import ProjectDescriptionHelpers

// 常道 · 白话道德经 — composes the ReaderFeature on the shared infra.
let project = Project.app(
    name: "DaodejingReader",
    bundleIdSuffix: "daodejing",
    displayName: "常道",
    launchBackgroundColorName: "LaunchBackground",
    dependencies: [
        .project(target: "AppCore", path: "../../Modules/AppCore"),
        .project(target: "DesignSystem", path: "../../Modules/DesignSystem"),
        .project(target: "DaodejingContent", path: "../../Modules/DaodejingContent"),
        .project(target: "Purchases", path: "../../Modules/Purchases"),
        .project(target: "Library", path: "../../Modules/Library"),
        .project(target: "Audio", path: "../../Modules/Audio"),
        .project(target: "ReaderFeature", path: "../../Modules/ReaderFeature"),
    ],
    additionalResources: [
        // MeloTTS voice models (git-ignored; staged by scripts/fetch-tts-models.sh).
        // A folder reference keeps melo-zh/ and melo-en/ intact in the bundle —
        // both contain a model.onnx, so flattening would collide.
        .folderReference(path: "BundledTTS"),
    ],
    storeKitConfigurationPath: .relativeToRoot("apps/DaodejingReader/StoreKit/Configuration.storekit")
)
