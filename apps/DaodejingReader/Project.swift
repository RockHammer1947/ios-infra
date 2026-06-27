import ProjectDescription
import ProjectDescriptionHelpers

// The entire app definition — build settings, platforms, test targets and
// scheme all come from `Project.app`. Business logic lives in Sources/ and
// shared code in the linked modules.
let project = Project.app(
    name: "DaodejingReader",
    bundleIdSuffix: "daodejing",
    dependencies: [
        .project(target: "AppCore", path: "../../Modules/AppCore"),
        .project(target: "DesignSystem", path: "../../Modules/DesignSystem"),
    ]
)
