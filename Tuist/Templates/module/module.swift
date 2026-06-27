import ProjectDescription

let nameAttribute: Template.Attribute = .required("name")

// `tuist scaffold module --name Networking` generates a shared module under
// Modules/Networking/. The workspace glob picks it up automatically.
let template = Template(
    description: "A new shared, reusable module wired into the workspace",
    attributes: [nameAttribute],
    items: [
        .file(path: "Modules/\(nameAttribute)/Project.swift", templatePath: "Project.stencil"),
        .file(path: "Modules/\(nameAttribute)/Sources/\(nameAttribute).swift", templatePath: "Source.stencil"),
        .file(path: "Modules/\(nameAttribute)/Tests/\(nameAttribute)Tests.swift", templatePath: "Tests.stencil"),
    ]
)
