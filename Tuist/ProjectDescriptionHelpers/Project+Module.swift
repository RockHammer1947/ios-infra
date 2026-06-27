import ProjectDescription

public extension Project {
    /// Factory for a shared, reusable feature/core module with its own test
    /// target and scheme. Modules are dynamic frameworks: Tuist auto-embeds them
    /// in the consuming app and sets module search paths, which avoids the
    /// static-framework "no such module" race under Xcode's explicit modules.
    ///
    /// ```swift
    /// let project = Project.module(name: "AppCore")
    /// ```
    static func module(
        name: String,
        product: Product = .framework,
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
