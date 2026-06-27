import ProjectDescription

public extension Project {
    /// Factory for a shared, reusable feature/core module with its own test
    /// target and scheme. Modules are static frameworks by default to avoid
    /// dynamic-linking overhead while staying multiplatform.
    ///
    /// ```swift
    /// let project = Project.module(name: "AppCore")
    /// ```
    static func module(
        name: String,
        product: Product = .staticFramework,
        dependencies: [TargetDependency] = []
    ) -> Project {
        let bundleId = "\(Constants.organizationIdentifier).\(name.lowercased())"

        return Project(
            name: name,
            organizationName: Constants.organizationName,
            settings: .base,
            targets: [
                .target(
                    name: name,
                    destinations: Constants.destinations,
                    product: product,
                    bundleId: bundleId,
                    deploymentTargets: Constants.deploymentTargets,
                    sources: ["Sources/**"],
                    dependencies: dependencies
                ),
                .target(
                    name: "\(name)Tests",
                    destinations: Constants.destinations,
                    product: .unitTests,
                    bundleId: "\(bundleId).tests",
                    deploymentTargets: Constants.deploymentTargets,
                    infoPlist: .default,
                    sources: ["Tests/**"],
                    dependencies: [.target(name: name)]
                ),
            ],
            schemes: [
                .scheme(
                    name: name,
                    shared: true,
                    buildAction: .buildAction(targets: [.target(name)]),
                    testAction: .targets(
                        [.testableTarget(target: .target("\(name)Tests"))],
                        options: .options(coverage: true, codeCoverageTargets: [.target(name)])
                    )
                ),
            ]
        )
    }
}
