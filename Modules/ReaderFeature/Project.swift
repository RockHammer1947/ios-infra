import ProjectDescription
import ProjectDescriptionHelpers

// Business/UI layer: screens, navigation, reading state.
let project = Project.module(
    name: "ReaderFeature",
    dependencies: [
        .project(target: "DesignSystem", path: "../DesignSystem"),
        .project(target: "DaodejingContent", path: "../DaodejingContent"),
        .project(target: "Purchases", path: "../Purchases"),
        .project(target: "Library", path: "../Library"),
        .project(target: "Audio", path: "../Audio"),
    ]
)
