import ProjectDescription

let nameAttribute: Template.Attribute = .required("name")

// `tuist scaffold app --name MyApp` generates a fully-wired multiplatform app
// under apps/MyApp/. The workspace glob picks it up automatically.
let template = Template(
    description: "A new multiplatform (iOS + macOS) app wired into the workspace",
    attributes: [nameAttribute],
    items: [
        .file(path: "apps/\(nameAttribute)/Project.swift", templatePath: "Project.stencil"),
        .file(path: "apps/\(nameAttribute)/Sources/\(nameAttribute)App.swift", templatePath: "App.stencil"),
        .file(path: "apps/\(nameAttribute)/Sources/RootView.swift", templatePath: "RootView.stencil"),
        .file(path: "apps/\(nameAttribute)/Tests/\(nameAttribute)Tests.swift", templatePath: "Tests.stencil"),
        .file(path: "apps/\(nameAttribute)/UITests/\(nameAttribute)UITests.swift", templatePath: "UITests.stencil"),
        .file(path: "apps/\(nameAttribute)/Resources/Assets.xcassets/Contents.json", templatePath: "Assets.stencil"),
    ]
)
