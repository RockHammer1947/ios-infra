import ProjectDescription

// The workspace globs in every app and module automatically — adding a new
// app under `apps/` or a module under `Modules/` requires no edit here.
let workspace = Workspace(
    name: "iOSInfra",
    projects: [
        "apps/**",
        "Modules/**",
    ]
)
