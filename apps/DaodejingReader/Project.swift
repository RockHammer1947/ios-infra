import ProjectDescription
import ProjectDescriptionHelpers

// 常道 · 白话道德经 — composes the ReaderFeature on the shared infra.
let project = Project.app(
    name: "DaodejingReader",
    bundleIdSuffix: "daodejing",
    displayName: "常道",
    dependencies: [
        .project(target: "AppCore", path: "../../Modules/AppCore"),
        .project(target: "DesignSystem", path: "../../Modules/DesignSystem"),
        .project(target: "DaodejingContent", path: "../../Modules/DaodejingContent"),
        .project(target: "ReaderFeature", path: "../../Modules/ReaderFeature"),
    ]
)
