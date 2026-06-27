import ProjectDescription

public extension Project {
    /// Factory for a multiplatform (iOS + macOS) application project, complete
    /// with unit-test and UI-test targets and a shared, coverage-enabled scheme.
    ///
    /// A new app's `Project.swift` is then ~10 lines:
    /// ```swift
    /// let project = Project.app(name: "MyApp", bundleIdSuffix: "myapp", dependencies: [...])
    /// ```
    static func app(
        name: String,
        bundleIdSuffix: String,
        dependencies: [TargetDependency] = []
    ) -> Project {
        let bundleId = "\(Constants.organizationIdentifier).\(bundleIdSuffix)"

        return Project(
            name: name,
            organizationName: Constants.organizationName,
            settings: .base,
            targets: [
                .target(
                    name: name,
                    destinations: Constants.destinations,
                    product: .app,
                    bundleId: bundleId,
                    deploymentTargets: Constants.deploymentTargets,
                    infoPlist: .extendingDefault(with: [
                        "CFBundleDisplayName": "$(PRODUCT_NAME)",
                        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                        "UILaunchScreen": [:],
                        "CFBundleDevelopmentRegion": "zh-Hans",
                    ]),
                    sources: ["Sources/**"],
                    resources: ["Resources/**"],
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
                .target(
                    name: "\(name)UITests",
                    destinations: Constants.destinations,
                    product: .uiTests,
                    bundleId: "\(bundleId).uitests",
                    deploymentTargets: Constants.deploymentTargets,
                    infoPlist: .default,
                    sources: ["UITests/**"],
                    dependencies: [.target(name: name)]
                ),
            ],
            schemes: [
                .scheme(
                    name: name,
                    shared: true,
                    buildAction: .buildAction(targets: [.target(name)]),
                    testAction: .targets(
                        [
                            .testableTarget(target: .target("\(name)Tests")),
                            .testableTarget(target: .target("\(name)UITests")),
                        ],
                        options: .options(coverage: true, codeCoverageTargets: [.target(name)])
                    ),
                    runAction: .runAction(executable: .target(name))
                ),
            ]
        )
    }
}
