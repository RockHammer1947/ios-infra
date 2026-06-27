import ProjectDescription
import ProjectDescriptionHelpers

// Read-only content layer: 道德经 models + bundled chapters.json repository.
let project = Project.module(
    name: "DaodejingContent",
    resources: ["Resources/**"]
)
